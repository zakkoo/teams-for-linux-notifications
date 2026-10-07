"""The stdlib MQTT bridge: framing, both protocol levels, topic handling, state lines."""
import json, socket, subprocess, sys, unittest
from datetime import datetime, timedelta, timezone

from _bridge_helpers import ROOT, FakeTeams, load_script


class Framing(unittest.TestCase):
    def setUp(self):
        self.b = load_script("bridge")

    def test_varint_roundtrip(self):
        for n in (0, 1, 127, 128, 16383, 16384, 2097151, 2097152):
            enc = self.b.varint(n)
            self.assertEqual(self.b.rdvar(enc, 0), (n, len(enc)), n)

    def test_mkstr_rdstr_roundtrip_unicode(self):
        s = "teams/Zürich ✓"
        self.assertEqual(self.b.rdstr(self.b.mkstr(s) + b"tail", 0), (s, 2 + len(s.encode())))

    def test_read_packet_on_closed_socket_is_none(self):
        a, b = socket.socketpair()
        a.close()
        self.assertIsNone(self.b.read_packet(b))

    def test_read_packet_multibyte_remaining_length(self):
        a, b = socket.socketpair()
        payload = b"x" * 300
        a.sendall(bytes([0x30]) + self.b.varint(len(payload)) + payload)
        self.assertEqual(self.b.read_packet(b), (3, 0, payload))


class Protocol(unittest.TestCase):
    """Run every scenario against MQTT 3.1.1 and MQTT 5."""

    def setUp(self):
        self.b = load_script("bridge")
        self.lines = []
        self.b.print = lambda line, **kw: self.lines.append(line)  # capture the real emit's stdout, dedupe included

    def last(self):
        return json.loads(self.lines[-1])

    def both(test):
        def run(self):
            for v5 in (False, True):
                with self.subTest(mqtt5=v5):
                    self.lines.clear()
                    self.b.state.update(connected=False, inCall=False, meetingStarted=False, error="", events=[])
                    self.b.PREFIX = "teams"
                    test(self, FakeTeams(self.b, v5))
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
    """A real TCP client against the real server loop: sequential clients, connected flips on drop."""

    def test_second_client_after_first_drops(self):
        b = load_script("bridge")
        lines = []
        b.emit = lambda **c: (b.state.update(c), lines.append(dict(b.state)))
        srv = socket.create_server(("127.0.0.1", 0)); port = srv.getsockname()[1]

        def serve_two():
            for _ in range(2):
                sock, _ = srv.accept()
                b.client = b.Client(sock)
                try:
                    b.client.serve()
                except OSError:
                    pass
                finally:
                    sock.close(); b.client = None
                    b.emit(connected=False, inCall=False, meetingStarted=False)

        import threading
        th = threading.Thread(target=serve_two, daemon=True); th.start()
        for _ in range(2):
            c = socket.create_connection(("127.0.0.1", port)); c.settimeout(3)
            c.sendall(bytes([0x10]) + b.varint(len(body := b.mkstr("MQTT") + b"\x04\x02\x00\x3c" + b.mkstr("t"))) + body)
            self.assertEqual(b.read_packet(c)[0], 2)
            sub = b"\x00\x01" + b.mkstr("teams/command") + b"\x00"
            c.sendall(bytes([0x82]) + b.varint(len(sub)) + sub)
            self.assertEqual(b.read_packet(c)[0], 9)
            self.assertEqual(b.read_packet(c)[0], 3)
            self.assertTrue(lines[-1]["connected"])
            c.close()  # drop without DISCONNECT
            th.join(0.5) if False else None
            import time; time.sleep(0.2)
            self.assertFalse(lines[-1]["connected"])
        th.join(3)
        srv.close()


if __name__ == "__main__":
    unittest.main()
