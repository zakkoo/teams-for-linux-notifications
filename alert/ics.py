"""Tiny ICS parser: VEVENTs -> (id, start_utc, subject, url) occurrences for yesterday..tomorrow."""
import re
from datetime import date, datetime, timedelta, timezone

LOCAL = datetime.now().astimezone().tzinfo
TEAMS_URL = re.compile(r"https://teams\.microsoft\.com/l/meetup-join/\S+")
WEEKDAYS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]


def _unfold(text):
    return re.sub(r"\r?\n[ \t]", "", text).splitlines()


def _dt(value, params):
    if "VALUE=DATE" in params:
        return None  # all-day
    if value.endswith("Z"):
        return datetime.strptime(value, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
    # ponytail: any TZID (incl. Windows names) treated as local time; use zoneinfo mapping if you travel
    return datetime.strptime(value[:15], "%Y%m%dT%H%M%S").replace(tzinfo=LOCAL)


def parse(text, today=None):
    today = today or date.today()
    days = [today - timedelta(days=1), today, today + timedelta(days=1)]
    out = []
    ev = None
    for line in _unfold(text):
        if line == "BEGIN:VEVENT":
            ev = {}
        elif line == "END:VEVENT" and ev is not None:
            out += _occurrences(ev, days)
            ev = None
        elif ev is not None and ":" in line:
            head, value = line.split(":", 1)
            name, *params = head.split(";")
            ev.setdefault(name, []).append((value, params))
    return out


def _occurrences(ev, days):
    start = _dt(*ev["DTSTART"][0]) if "DTSTART" in ev else None
    if start is None:
        return []
    uid = ev.get("UID", [("?", [])])[0][0]
    subject = ev.get("SUMMARY", [("(no subject)", [])])[0][0].replace("\\,", ",")
    blob = " ".join(v for k in ("DESCRIPTION", "LOCATION", "URL", "X-MICROSOFT-SKYPETEAMSMEETINGURL") for v, _ in ev.get(k, []))
    m = TEAMS_URL.search(blob.replace("\\n", " ").replace("\\", ""))
    url = m.group(0) if m else ""
    rrule = dict(p.split("=", 1) for p in ev["RRULE"][0][0].split(";")) if "RRULE" in ev else None
    if not rrule:
        return [(uid, start.astimezone(timezone.utc), subject, url)]
    exdates = {_dt(v, p).date() for v, p in ev.get("EXDATE", []) for v in v.split(",") if _dt(v, p)}
    until = _dt(rrule["UNTIL"], []) .date() if "UNTIL" in rrule else None
    bydays = rrule.get("BYDAY", WEEKDAYS[start.weekday()]).split(",")
    occ = []
    # ponytail: DAILY/WEEKLY with INTERVAL=1 only; MONTHLY/COUNT/INTERVAL>1 fall back to "fires on matching weekday"
    for d in days:
        if d < start.date() or (until and d > until) or d in exdates:
            continue
        if rrule.get("FREQ") == "WEEKLY" and WEEKDAYS[d.weekday()] not in bydays:
            continue
        if rrule.get("FREQ") == "DAILY" and "BYDAY" in rrule and WEEKDAYS[d.weekday()] not in bydays:
            continue
        s = start.replace(year=d.year, month=d.month, day=d.day)
        occ.append((f"{uid}@{d.isoformat()}", s.astimezone(timezone.utc), subject, url))
    return occ
