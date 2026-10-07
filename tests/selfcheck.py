#!/usr/bin/env python3
"""python3 tests/selfcheck.py — fails loudly if the bridge, its calendar parsing, or the Teams config helper break."""
import importlib.machinery, importlib.util, io, json, os, socket, subprocess, sys, tempfile, threading
from datetime import datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(name):
    spec = importlib.util.spec_from_loader(name, importlib.machinery.SourceFileLoader(name, os.path.join(ROOT, "scripts", name + ".py")))
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); return mod


# --- bridge: calendar parsing
bridge = load("bridge")
now = datetime.now(timezone.utc).replace(microsecond=0)
g = bridge.parse_graph_events({"value": [
    {"id": "1", "subject": "G", "start": {"dateTime": "2026-10-07T09:00:00.0000000", "timeZone": "UTC"},
     "end": {"dateTime": "2026-10-07T09:30:00.0000000", "timeZone": "UTC"}, "onlineMeeting": {"joinUrl": "https://j"}},
    {"id": "room", "subject": "Onsite", "start": {"dateTime": "2026-10-07T13:00:00", "timeZone": "UTC"}, "end": {"dateTime": "2026-10-07T14:00:00", "timeZone": "UTC"},
     "webLink": "https://outlook.office365.com/calendar/item/x", "location": {"displayName": "Room 4.12"}},
    {"id": "2", "isAllDay": True, "start": {}},
    {"id": "3", "isCancelled": True, "start": {"dateTime": "2026-10-07T10:00:00", "timeZone": "UTC"}}]})
assert g == [{"id": "1", "subject": "G", "start": "2026-10-07T09:00:00+00:00", "end": "2026-10-07T09:30:00+00:00", "joinUrl": "https://j", "location": ""},
             {"id": "room", "subject": "Onsite", "start": "2026-10-07T13:00:00+00:00", "end": "2026-10-07T14:00:00+00:00", "joinUrl": "", "location": "Room 4.12"}], g

# --- bridge: protocol, both MQTT levels, state lines on stdout
lines = []
bridge.emit = lambda **c: (bridge.state.update(c), lines.append(dict(bridge.state)))
for v5 in (False, True):
    lines.clear(); bridge.state.update(connected=False, inCall=False, meetingStarted=False, events=[])
    a, b = socket.socketpair()
    c = bridge.Client(b); bridge.client = c
    t = threading.Thread(target=c.serve, daemon=True); t.start()
    def pk(tf, body): return bytes([tf]) + bridge.varint(len(body)) + body
    def rd():
        tp, fl, body = bridge.read_packet(a); return tp, body
    props = b"\x00" if v5 else b""
    a.sendall(pk(0x10, bridge.mkstr("MQTT") + bytes([5 if v5 else 4, 2]) + b"\x00\x3c" + props + bridge.mkstr("teams-for-linux")))
    assert rd() == (2, b"\x00\x00\x00" if v5 else b"\x00\x00")
    a.sendall(pk(0x82, b"\x00\x01" + props + bridge.mkstr("teams/command") + b"\x00"))
    assert rd()[0] == 9
    tp, body = rd()                                   # bridge asked for the calendar on subscribe
    topic, i = bridge.rdstr(body, 0); assert topic == "teams/command" and json.loads(body[i + len(props):])["action"] == "get-calendar"
    assert lines[-1]["connected"] is True
    a.sendall(pk(0x32, bridge.mkstr("teams/meeting-started") + b"\x00\x07" + props + b"true"))
    assert rd() == (4, b"\x00\x07")                   # PUBACK for QoS1
    cal = json.dumps({"value": [{"id": "x", "subject": "Via MQTT", "start": {"dateTime": (now + timedelta(seconds=60)).strftime("%Y-%m-%dT%H:%M:%S"), "timeZone": "UTC"}}]}).encode()
    a.sendall(pk(0x30, bridge.mkstr("teams/calendar") + props + cal))
    a.sendall(pk(0x30, bridge.mkstr("teams/in-call") + props + b"true"))
    a.sendall(pk(0xC0, b"")); assert rd() == (13, b"")
    a.sendall(pk(0xE0, b"")); t.join(2)
    st = lines[-1]
    assert st["meetingStarted"] and st["inCall"] and st["events"][0]["subject"] == "Via MQTT" and st["events"][0]["end"] > st["events"][0]["start"], (v5, st)

# --- teams-config helper round-trip
d = tempfile.mkdtemp(); cfg = os.path.join(d, "config.json")
helper = os.path.join(ROOT, "scripts", "teams-config.py")
def run(*args): return subprocess.run([sys.executable, helper, *args, "--config", cfg], capture_output=True, text=True, check=True).stdout.strip()
assert run("status") == "disconnected"
assert run("connect") == ""                            # fresh file: no backup
assert run("status") == "connected"
assert run("disconnect") and run("status") == "disconnected" and json.load(open(cfg)) == {}
json.dump({"mqtt": {"username": "u"}, "closeAppOnCross": True}, open(cfg, "w"))
backup = run("connect", "--port", "1999")
assert os.path.exists(backup) and json.load(open(cfg))["mqtt"]["brokerUrl"] == "mqtt://127.0.0.1:1999"
assert run("status", "--port", "1999") == "connected" and run("status") == "disconnected"
run("disconnect", "--port", "1999")
assert json.load(open(cfg)) == {"mqtt": {"username": "u"}, "closeAppOnCross": True}, json.load(open(cfg))
print("selfcheck ok")
