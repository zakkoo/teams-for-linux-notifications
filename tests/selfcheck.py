#!/usr/bin/env python3
"""python3 tests/selfcheck.py — fails loudly if ICS parsing, due logic or the MQTT broker break."""
import importlib.machinery, importlib.util, json, os, socket, sys, tempfile, threading, time
from datetime import date, datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "alert"))
os.environ["MEETING_ALERT_STATE"] = tempfile.mktemp()
os.environ["MEETING_ALERT_STATE_DIR"] = tempfile.mkdtemp()
import due, ics

fired = []
due.alert = lambda t, b="", u="": fired.append((t, b, u))

# --- ics
occ = ics.parse(open(os.path.join(ROOT, "tests/sample.ics")).read(), today=date(2026, 10, 7))
by = {o[0]: o for o in occ}
assert by["single@x"][2] == "One-off, with comma" and by["single@x"][3].startswith("https://teams.microsoft.com/l/meetup-join/"), by["single@x"]
assert "standup@x@2026-10-06" in by and "standup@x@2026-10-08" in by, by.keys()        # Tue, Thu
assert "standup@x@2026-10-07" not in by, "EXDATE ignored"
assert not any(k.startswith("allday") for k in by), "all-day should be skipped"
assert by["standup@x@2026-10-08"][1] == datetime(2026, 10, 8, 7, tzinfo=timezone.utc)

# --- due
now = datetime.now(timezone.utc)
ev = [("soon", now + timedelta(seconds=90), "Soon", "u"), ("later", now + timedelta(hours=2), "Later", ""),
      ("past", now - timedelta(minutes=10), "Past", "")]
due.alert_due(ev, lead_min=2); due.alert_due(ev, lead_min=2)
assert [f[1] for f in fired] == ["Soon"], fired
g = due.parse_graph_events({"value": [{"id": "1", "subject": "G", "start": {"dateTime": "2026-10-07T09:00:00.0000000", "timeZone": "UTC"},
                                      "onlineMeeting": {"joinUrl": "https://j"}}, {"id": "2", "isAllDay": True, "start": {}}]})
assert g == [("1", datetime(2026, 10, 7, 9, tzinfo=timezone.utc), "G", "https://j")], g

# --- mqtt broker, both protocol levels
spec = importlib.util.spec_from_loader("broker", importlib.machinery.SourceFileLoader("broker", os.path.join(ROOT, "sources/02-teams-mqtt/start")))
broker = importlib.util.module_from_spec(spec); spec.loader.exec_module(broker)
broker.due = due
for v5 in (False, True):
    fired.clear(); broker.events = []
    a, b = socket.socketpair()
    c = broker.Client(b); broker.client = c
    t = threading.Thread(target=c.serve, daemon=True); t.start()
    def pk(tf, body): return bytes([tf]) + broker.varint(len(body)) + body
    def rd():
        tp, fl, body = broker.read_packet(a); return tp, body
    props = b"\x00" if v5 else b""
    a.sendall(pk(0x10, broker.mkstr("MQTT") + bytes([5 if v5 else 4, 2]) + b"\x00\x3c" + props + broker.mkstr("teams-for-linux")))
    assert rd() == (2, b"\x00\x00\x00" if v5 else b"\x00\x00")
    a.sendall(pk(0x82, b"\x00\x01" + props + broker.mkstr("teams/command") + b"\x00"))
    assert rd()[0] == 9
    tp, body = rd()                                   # broker asked for the calendar on subscribe
    topic, i = broker.rdstr(body, 0); assert topic == "teams/command" and json.loads(body[i + len(props):])["action"] == "get-calendar"
    a.sendall(pk(0x32, broker.mkstr("teams/meeting-started") + b"\x00\x07" + props + b"true"))
    assert rd() == (4, b"\x00\x07")                   # PUBACK for QoS1
    cal = json.dumps({"value": [{"id": "x", "subject": "Via MQTT", "start": {"dateTime": (now + timedelta(seconds=60)).strftime("%Y-%m-%dT%H:%M:%S"), "timeZone": "UTC"}}]}).encode()
    a.sendall(pk(0x30, broker.mkstr("teams/calendar") + props + cal))
    a.sendall(pk(0xC0, b"")); assert rd() == (13, b"")
    a.sendall(pk(0xE0, b"")); t.join(2)
    assert [f[0] for f in fired] == ["Meeting started", "Meeting now"], (v5, fired)
    os.remove(os.environ["MEETING_ALERT_STATE"])
print("selfcheck ok")
