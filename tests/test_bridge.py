"""The stdlib MQTT bridge: framing, both protocol levels, topic handling, state lines, client drops."""
import json, socket, subprocess, sys, threading, time, unittest
from datetime import datetime, timedelta

from _bridge_helpers import ROOT, FakeTeams, load_script


class Framing(unittest.TestCase):
    def setUp(self):
        self.b = load_script("bridge")

    def test_varint_roundtrip(self):
        for n in (0, 1, 127, 128, 16383, 16384, 2097151, 2097152):
            enc = self.b.varint(n)
            self.assertEqual(self.b.rdvar(enc, 0), (n, len(enc)), n)

    def test_varint_longer_than_four_bytes_is_rejected(self):
        with self.assertRaises(ValueError):
            self.b.rdvar(b"\x80\x80\x80\x80\x01", 0)

    def test_mkstr_rdstr_roundtrip_unicode(self):
        s = "teams/Zürich ✓"
        self.assertEqual(self.b.rdstr(self.b.mkstr(s) + b"tail", 0), (s, 2 + len(s.encode())))

    def test_rdstr_truncated_raises(self):
        with self.assertRaises(ValueError):
            self.b.rdstr(b"\x00\x10abc", 0)

    def test_read_packet_on_closed_socket_is_none(self):
        a, b = socket.socketpair()
        a.close()
        self.assertIsNone(self.b.read_packet(b))

    def test_read_packet_multibyte_remaining_length(self):
        a, b = socket.socketpair()
        payload = b"x" * 300
        a.sendall(bytes([0x30]) + self.b.varint(len(payload)) + payload)
        self.assertEqual(self.b.read_packet(b), (3, 0, payload))

    def test_read_packet_remaining_length_beyond_four_bytes_is_none(self):
        a, b = socket.socketpair()
        a.sendall(bytes([0x30]) + b"\x80\x80\x80\x80\x01")
        self.assertIsNone(self.b.read_packet(b))


class Protocol(unittest.TestCase):
    """Run every scenario against MQTT 3.1.1 and MQTT 5, each on a fresh Broker."""

    def setUp(self):
        self.b = load_script("bridge")

    def fresh(self):
        self.lines = []
        self.broker = self.b.Broker(out=self.lines.append)  # the real emit, dedupe included
        return self.broker

    def last(self):
        return json.loads(self.lines[-1])

    def both(test):
        def run(self):
            for v5 in (False, True):
                with self.subTest(mqtt5=v5):
                    test(self, FakeTeams(self.b, self.fresh(), v5))
        return run

    @both
    def test_connack_and_subscribe_trigger_calendar_request(self, t):
        self.assertEqual(t.connect(), (2, b"\x00\x00\x00" if t.v5 else b"\x00\x00"))
        tp, body = t.subscribe("teams/command", "teams/other")
        self.assertEqual(tp, 9)
        self.assertEqual(body[-2:], b"\x00\x00", "one return code per topic")
        topic, cmd = t.read_publish()
        self.assertEqual(topic, "teams/command")
        self.assertEqual(cmd["action"], "get-calendar")
        start, end = datetime.fromisoformat(cmd["startDate"]), datetime.fromisoformat(cmd["endDate"])
        self.assertEqual((start.hour, start.minute, start.second), (0, 0, 0))
        self.assertEqual(end - start, timedelta(days=1))
        self.assertTrue(self.last()["connected"])
        t.disconnect()

    @both
    def test_connect_with_username_password_and_will(self, t):
        # Teams for Linux sets a last-will on <prefix>/connected; the CONNECT payload then carries will topic/message.
        extra = self.b.mkstr("teams/connected") + self.b.mkstr("false") + self.b.mkstr("user") + self.b.mkstr("pass")
        if t.v5:
            extra = b"\x00" + extra  # will properties
        self.assertEqual(t.connect(flags=0xC6, extra=extra)[0], 2)
        t.disconnect()

    @both
    def test_prefix_follows_subscription(self, t):
        # Older Teams builds publish under "undefined/" when topicPrefix is unset.
        t.connect()
        t.subscribe("undefined/command")
        topic, _ = t.read_publish()
        self.assertEqual(topic, "undefined/command")
        t.publish("undefined/in-call", "true")
        t.ping()
        self.assertTrue(self.last()["inCall"])
        t.disconnect()

    @both
    def test_topics_map_to_state(self, t):
        t.connect(); t.subscribe("teams/command"); t.read_publish()
        t.publish("teams/in-call", "true")
        t.publish("teams/meeting-started", "true", qos=1)
        self.assertEqual(t.read(), (4, b"\x00\x07"), "QoS 1 is acknowledged")
        t.publish("teams/connected", "true")
        t.ping()
        st = self.last()
        self.assertEqual((st["connected"], st["inCall"], st["meetingStarted"]), (True, True, True))
        t.publish("teams/meeting-started", "false")
        t.publish("teams/in-call", "false")
        t.ping()
        st = self.last()
        self.assertEqual((st["inCall"], st["meetingStarted"]), (False, False))
        t.disconnect()

    @both
    def test_unrelated_topics_and_wrong_prefix_are_ignored(self, t):
        t.connect(); t.subscribe("teams/command"); t.read_publish()
        n = len(self.lines)
        t.publish("teams/microphone", "muted")
        t.publish("homeassistant/status", "online")
        t.publish("other/in-call", "true")
        self.assertEqual(t.ping(), (13, b""))
        self.assertEqual(len(self.lines), n, "no state line for ignored topics")
        t.disconnect()

    @both
    def test_calendar_payload_becomes_sorted_events(self, t):
        t.connect(); t.subscribe("teams/command"); t.read_publish()
        cal = {"value": [
            {"id": "b", "subject": "Later", "start": {"dateTime": "2026-10-07T15:00:00", "timeZone": "UTC"}, "end": {"dateTime": "2026-10-07T16:00:00", "timeZone": "UTC"}},
            {"id": "a", "subject": "Earlier", "start": {"dateTime": "2026-10-07T09:00:00", "timeZone": "UTC"}, "end": {"dateTime": "2026-10-07T09:30:00", "timeZone": "UTC"}},
        ]}
        t.publish("teams/calendar", json.dumps(cal))
        t.ping()
        st = self.last()
        self.assertEqual([e["subject"] for e in st["events"]], ["Earlier", "Later"])
        self.assertEqual(st["error"], "")
        t.disconnect()

    @both
    def test_bad_calendar_payload_sets_error_and_keeps_events(self, t):
        t.connect(); t.subscribe("teams/command"); t.read_publish()
        t.publish("teams/calendar", json.dumps({"value": [{"id": "x", "subject": "Keep", "start": {"dateTime": "2026-10-07T09:00:00", "timeZone": "UTC"}}]}))
        t.publish("teams/calendar", "{not json")
        t.ping()
        st = self.last()
        self.assertIn("bad calendar payload", st["error"])
        self.assertEqual([e["subject"] for e in st["events"]], ["Keep"])
        t.disconnect()

    @both
    def test_disconnect_packet_ends_session(self, t):
        t.connect()
        t.disconnect()
        self.assertFalse(t.thread.is_alive())

    @both
    def test_emit_dedupes_identical_state(self, t):
        t.connect(); t.subscribe("teams/command"); t.read_publish()
        n = len(self.lines)
        t.publish("teams/connected", "true")  # already true after subscribe
        t.ping()
        self.assertEqual(len(self.lines), n)
        t.disconnect()

    @both
    def test_malformed_packet_drops_only_that_client(self, t):
        t.connect(); t.subscribe("teams/command"); t.read_publish()
        t.send(0x82, b"\x00\x02" + t.props + b"\x00\x40trunc" + b"\x00")  # SUBSCRIBE whose topic claims 64 bytes
        t.thread.join(3)
        self.assertFalse(t.thread.is_alive(), "the serving thread ends instead of crashing the process")
        self.assertFalse(self.last()["connected"])
        self.assertIsNone(self.broker.client)
        again = FakeTeams(self.b, self.broker, t.v5)  # the same broker serves the next client as if nothing happened
        again.connect(); again.subscribe("teams/command")
        self.assertEqual(again.read_publish()[1]["action"], "get-calendar")
        self.assertTrue(self.last()["connected"])
        again.disconnect()

    @both
    def test_undecodable_topic_drops_only_that_client(self, t):
        t.connect(); t.subscribe("teams/command"); t.read_publish()
        t.send(0x30, b"\x00\x02\xff\xfe" + t.props + b"x")  # PUBLISH with a topic that is not UTF-8
        t.thread.join(3)
        self.assertFalse(t.thread.is_alive())
        self.assertFalse(self.last()["connected"])


class PollThread(unittest.TestCase):
    """request_calendar runs on the ticker thread and must survive the client vanishing under it."""

    def setUp(self):
        self.b = load_script("bridge")

    def test_client_cleared_between_check_and_publish_does_not_raise(self):
        broker = self.b.Broker(out=lambda line: None)

        class Vanishing:
            subs = {"teams/command"}

            def publish(self_, topic, payload):
                broker.client = None  # the accept loop dropped it meanwhile
                raise OSError("Broken pipe")

        broker.client = Vanishing()
        broker.request_calendar()  # must not propagate
        self.assertIsNone(broker.client)
        broker.request_calendar()  # and a missing client is simply skipped

    def test_no_client_is_a_no_op(self):
        broker = self.b.Broker(out=lambda line: None)
        broker.request_calendar()


class Process(unittest.TestCase):
    """The real executable: startup line, argument handling, port conflict."""

    def run_bridge(self, *args, timeout=2):
        try:
            return subprocess.run([sys.executable, f"{ROOT}/scripts/bridge.py", *args], capture_output=True, text=True, timeout=timeout)
        except subprocess.TimeoutExpired as e:
            return e

    def test_prints_initial_state_then_keeps_listening(self):
        srv = socket.socket(); srv.bind(("127.0.0.1", 0)); port = srv.getsockname()[1]; srv.close()
        r = self.run_bridge("--port", str(port))
        self.assertIsInstance(r, subprocess.TimeoutExpired, "a free port means it keeps running")
        st = json.loads(r.stdout.decode().splitlines()[0])
        self.assertEqual(st, {"connected": False, "inCall": False, "meetingStarted": False, "error": "", "events": []})

    def test_port_in_use_is_reported_on_stdout_and_exits(self):
        srv = socket.create_server(("127.0.0.1", 0)); port = srv.getsockname()[1]
        try:
            r = self.run_bridge("--port", str(port))
        finally:
            srv.close()
        self.assertEqual(r.returncode, 1)
        self.assertIn(f"cannot listen on 127.0.0.1:{port}", json.loads(r.stdout.splitlines()[-1])["error"])

    def test_rejects_bad_arguments(self):
        r = self.run_bridge("--port", "abc")
        self.assertEqual(r.returncode, 2)


class EndToEndSocket(unittest.TestCase):
    """A real TCP client against the real accept loop: sequential clients, connected flips on drop, silent clients time out."""

    def setUp(self):
        self.b = load_script("bridge")
        self.lines = []
        self.broker = self.b.Broker(out=lambda line: self.lines.append(json.loads(line)))
        self.srv = socket.create_server(("127.0.0.1", 0)); self.port = self.srv.getsockname()[1]
        self.thread = threading.Thread(target=self.broker.serve_forever, args=(self.srv,), daemon=True); self.thread.start()

    def tearDown(self):
        self.srv.close()

    def raw_connect(self, keepalive=60):
        c = socket.create_connection(("127.0.0.1", self.port)); c.settimeout(3)
        body = self.b.mkstr("MQTT") + b"\x04\x02" + keepalive.to_bytes(2, "big") + self.b.mkstr("t")
        c.sendall(bytes([0x10]) + self.b.varint(len(body)) + body)
        self.assertEqual(self.b.read_packet(c)[0], 2)
        return c

    def subscribe(self, c):
        sub = b"\x00\x01" + self.b.mkstr("teams/command") + b"\x00"
        c.sendall(bytes([0x82]) + self.b.varint(len(sub)) + sub)
        self.assertEqual(self.b.read_packet(c)[0], 9)
        self.assertEqual(self.b.read_packet(c)[0], 3)

    def wait_disconnected(self, timeout):
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.lines and not self.lines[-1]["connected"]:
                return True
            time.sleep(0.05)
        return False

    def test_second_client_after_first_drops(self):
        for _ in range(2):
            c = self.raw_connect()
            self.subscribe(c)
            self.assertTrue(self.lines[-1]["connected"])
            c.close()  # drop without DISCONNECT
            self.assertTrue(self.wait_disconnected(2))

    def test_silent_client_is_dropped_after_its_keepalive_and_the_next_is_served(self):
        c = self.raw_connect(keepalive=1)
        self.subscribe(c)
        self.assertTrue(self.lines[-1]["connected"])
        self.assertTrue(self.wait_disconnected(3), "1.5 x 1 s keepalive without a ping means dead")
        c.close()
        c2 = self.raw_connect()
        self.subscribe(c2)
        self.assertTrue(self.lines[-1]["connected"], "the reconnecting Teams is served")
        c2.close()

    def test_poll_resumes_on_the_next_connection(self):
        c = self.raw_connect(); self.subscribe(c); c.close()
        self.assertTrue(self.wait_disconnected(2))
        self.broker.request_calendar()  # the ticker fires while nobody is connected: no-op, no crash
        c2 = self.raw_connect(); self.subscribe(c2)
        self.broker.request_calendar()
        self.assertEqual(self.b.read_packet(c2)[0], 3, "the poll reaches the new client")
        c2.close()


if __name__ == "__main__":
    unittest.main()
