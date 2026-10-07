"""Shared bits: config loading, firing alert.sh, and 'fire once when an event is due'."""
import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def load_env():
    """Read ROOT/config.env (KEY=VALUE lines) into os.environ without overriding what's set."""
    try:
        for line in open(os.path.join(ROOT, "config.env")):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
    except FileNotFoundError:
        pass


def alert(title, body="", url=""):
    subprocess.run([os.path.join(HERE, "alert.sh"), title, body, url], check=False)


def _state_file():
    return os.environ.get("MEETING_ALERT_STATE") or os.path.join(
        os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "meeting-alert-fired.json")


def alert_due(events, lead_min=None):
    """events: iterable of (id, start_utc_datetime, subject, url).
    Fires once per id when start-lead <= now < start+5min."""
    lead_min = int(os.environ.get("LEAD_MINUTES", 2) if lead_min is None else lead_min)
    try:
        fired = set(json.load(open(_state_file())))
    except Exception:
        fired = set()
    now = datetime.now(timezone.utc)
    for eid, start, subject, url in events:
        if eid in fired or start is None:
            continue
        if start - timedelta(minutes=lead_min) <= now < start + timedelta(minutes=5):
            mins = max(0, int((start - now).total_seconds() // 60))
            alert("Meeting now" if mins == 0 else f"Meeting in {mins} min", subject, url)
            fired.add(eid)
    # ponytail: set grows until reboot (runtime dir is wiped); prune by date if it ever matters
    json.dump(sorted(fired), open(_state_file(), "w"))


def parse_graph_events(data):
    """Microsoft Graph calendarView JSON (or anything wrapping its 'value' list) -> due tuples."""
    while isinstance(data, dict):
        data = data.get("value") or data.get("data") or []
    out = []
    for e in data or []:
        if e.get("isCancelled") or e.get("isAllDay"):
            continue
        st = e.get("start") or {}
        raw = (st.get("dateTime") or "")[:19]
        try:
            tz = ZoneInfo(st.get("timeZone") or "UTC")
        except Exception:
            tz = timezone.utc  # ponytail: Windows tz names unsupported; Graph returns UTC unless asked otherwise
        try:
            start = datetime.fromisoformat(raw).replace(tzinfo=tz).astimezone(timezone.utc)
        except ValueError:
            continue
        url = (e.get("onlineMeeting") or {}).get("joinUrl") or e.get("webLink") or ""
        out.append((e.get("id") or raw, start, e.get("subject") or "(no subject)", url))
    return out


if __name__ == "__main__":
    # `python3 due.py graph < graph.json`  — used by bash sources
    load_env()
    if sys.argv[1:] == ["graph"]:
        alert_due(parse_graph_events(json.load(sys.stdin)))
    else:
        sys.exit("usage: due.py graph < calendarView.json")
