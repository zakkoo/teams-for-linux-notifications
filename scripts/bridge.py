#!/usr/bin/env python3
"""Stdlib-only MQTT broker (3.1.1 + 5, QoS 0/1) that only serves Teams for Linux.
Mirrors Teams' topics into one JSON state line on stdout per change:
  {"connected": bool, "inCall": bool, "meetingStarted": bool, "error": str,
   "events": [{"id","subject","start","end","joinUrl","location"}]}   # start/end ISO-8601 UTC
usage: bridge.py [--port 1883] [--prefix teams] [--poll-minutes 5]"""
import argparse, json, re, socket, sys, threading, time
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

state = {"connected": False, "inCall": False, "meetingStarted": False, "error": "", "events": []}
lock = threading.Lock()
client = None
PREFIX = "teams"


def emit(**changes):
    with lock:
        if all(state.get(k) == v for k, v in changes.items()):
            return
        state.update(changes)
        print(json.dumps(state), flush=True)


def log(msg):
    print(f"{time.strftime('%F %T')} {msg}", file=sys.stderr, flush=True)


# --- MQTT framing
def varint(n):
    out = b""
    while True:
        b, n = n % 128, n // 128
        out += bytes([b | 0x80]) if n else bytes([b])
        if not n:
            return out


def rdvar(buf, i):
    n, mult = 0, 1
    while True:
        n += (buf[i] & 127) * mult; mult *= 128; i += 1
        if not buf[i - 1] & 128:
            return n, i


def mkstr(s):
    b = s.encode(); return len(b).to_bytes(2, "big") + b


def rdstr(buf, i):
    n = int.from_bytes(buf[i:i + 2], "big"); return buf[i + 2:i + 2 + n].decode(), i + 2 + n


def read_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf


def read_packet(sock):
    h = read_exact(sock, 1)
    if not h:
        return None
    rem, mult = 0, 1
    while True:
        b = read_exact(sock, 1)
        if b is None:
            return None
        rem += (b[0] & 127) * mult; mult *= 128
        if not b[0] & 128:
            break
    return h[0] >> 4, h[0] & 15, (read_exact(sock, rem) if rem else b"")


class Client:
    def __init__(self, sock):
        self.sock, self.v5, self.subs, self.lock = sock, False, set(), threading.Lock()

    def send(self, type_flags, body):
        with self.lock:
            self.sock.sendall(bytes([type_flags]) + varint(len(body)) + body)

    def publish(self, topic, payload):
        self.send(0x30, mkstr(topic) + (b"\x00" if self.v5 else b"") + payload)

    def serve(self):
        while (pk := read_packet(self.sock)) is not None:
            t, fl, body = pk
            if t == 1:  # CONNECT
                _, i = rdstr(body, 0)
                self.v5 = body[i] >= 5
                i += 4  # level, flags, keepalive
                if self.v5:
                    n, i = rdvar(body, i); i += n
                cid, _ = rdstr(body, i)
                log(f"connected: {cid} (mqtt{'5' if self.v5 else '3.1.1'})")
                self.send(0x20, b"\x00\x00\x00" if self.v5 else b"\x00\x00")
            elif t == 8:  # SUBSCRIBE
                pid, i = body[:2], 2
                if self.v5:
                    n, i = rdvar(body, i); i += n
                codes = b""
                while i < len(body):
                    topic, i = rdstr(body, i); i += 1
                    self.subs.add(topic); codes += b"\x00"
                self.send(0x90, pid + (b"\x00" if self.v5 else b"") + codes)
                global PREFIX
                for topic in self.subs:  # follow whatever prefix Teams actually uses
                    if topic.endswith("/command"):
                        PREFIX = topic[:-len("/command")]
                emit(connected=True, error="")
                request_calendar()
            elif t == 3:  # PUBLISH
                qos = (fl >> 1) & 3
                topic, i = rdstr(body, 0)
                if qos:
                    self.send(0x40, body[i:i + 2]); i += 2
                if self.v5:
                    n, i = rdvar(body, i); i += n
                on_message(topic, body[i:])
            elif t == 12:  # PINGREQ
                self.send(0xD0, b"")
            elif t == 14:  # DISCONNECT
                break


# --- Teams topics
def parse_graph_events(data):
    """Microsoft Graph calendarView JSON -> [{id, subject, start, end, joinUrl}], start/end ISO UTC."""
    while isinstance(data, dict):
        data = data.get("value") or data.get("data") or []
    out = []
    for e in data or []:
        if e.get("isCancelled") or e.get("isAllDay"):
            continue
        times = []
        for key in ("start", "end"):
            st = e.get(key) or {}
            try:
                tz = ZoneInfo(st.get("timeZone") or "UTC")
            except Exception:
                tz = timezone.utc  # ponytail: Windows tz names unsupported; Graph returns UTC unless asked otherwise
            try:
                times.append(datetime.fromisoformat((st.get("dateTime") or "")[:19]).replace(tzinfo=tz).astimezone(timezone.utc))
            except ValueError:
                times.append(None)
        start, end = times
        if start is None:
            continue
        end = end or start + timedelta(hours=1)
        m = re.search(r"https://teams\.microsoft\.com/\S+", e.get("bodyPreview") or "")
        url = (e.get("onlineMeeting") or {}).get("joinUrl") or (m and m.group(0)) or ""  # no webLink: that is Outlook, not a call
        location = ((e.get("location") or {}).get("displayName") or "").strip()
        out.append({"id": e.get("id") or start.isoformat(), "subject": e.get("subject") or "(no subject)",
                    "start": start.isoformat(), "end": end.isoformat(), "joinUrl": url, "location": location})
    return sorted(out, key=lambda x: x["start"])


def on_message(topic, payload):
    text = payload.decode(errors="replace")
    if not topic.startswith(PREFIX + "/"):
        return
    sub = topic[len(PREFIX) + 1:]
    if sub == "connected":
        emit(connected=text == "true")
    elif sub == "in-call":
        emit(inCall=text == "true")
    elif sub == "meeting-started":
        emit(meetingStarted=text == "true")
    elif sub == "calendar":
        try:
            events = parse_graph_events(json.loads(text))
        except ValueError as e:
            emit(error=f"bad calendar payload: {e}"); return
        log(f"calendar: {len(events)} events")
        emit(events=events, error="")


def request_calendar():
    if client and f"{PREFIX}/command" in client.subs:
        # Local midnight, not UTC: "today" must mean the user's day, or evening meetings slide across days.
        s = datetime.now().astimezone().replace(hour=0, minute=0, second=0, microsecond=0)
        cmd = {"action": "get-calendar", "startDate": s.isoformat(), "endDate": (s + timedelta(days=1)).isoformat()}
        try:
            client.publish(f"{PREFIX}/command", json.dumps(cmd).encode())
        except OSError:
            pass


def ticker(poll_minutes):
    while True:
        time.sleep(poll_minutes * 60)
        request_calendar()


def main():
    global client, PREFIX
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=1883)
    ap.add_argument("--prefix", default="teams")
    ap.add_argument("--poll-minutes", type=float, default=5)
    a = ap.parse_args()
    PREFIX = a.prefix
    try:
        srv = socket.create_server(("127.0.0.1", a.port))
    except OSError as e:
        emit(error=f"cannot listen on 127.0.0.1:{a.port}: {e.strerror}")
        sys.exit(1)
    print(json.dumps(state), flush=True)
    threading.Thread(target=ticker, args=(a.poll_minutes,), daemon=True).start()
    while True:
        sock, _ = srv.accept()
        client = Client(sock)
        try:
            client.serve()
        except OSError as e:
            log(f"client dropped: {e}")
        finally:
            sock.close()
            client = None
            emit(connected=False, inCall=False, meetingStarted=False)


if __name__ == "__main__":
    main()
