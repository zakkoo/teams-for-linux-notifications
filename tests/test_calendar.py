"""Graph calendarView JSON -> event dicts the widget renders."""
import unittest

from _bridge_helpers import load_script

parse = load_script("bridge").parse_graph_events


def ev(**kw):
    e = {"id": "1", "subject": "S", "start": {"dateTime": "2026-10-07T09:00:00.0000000", "timeZone": "UTC"},
         "end": {"dateTime": "2026-10-07T09:30:00.0000000", "timeZone": "UTC"}}
    e.update(kw)
    return e


class ParseGraphEvents(unittest.TestCase):
    def test_basic_fields(self):
        out = parse({"value": [ev(onlineMeeting={"joinUrl": "https://teams.microsoft.com/l/meetup-join/x"})]})
        self.assertEqual(out, [{"id": "1", "subject": "S", "start": "2026-10-07T09:00:00+00:00", "end": "2026-10-07T09:30:00+00:00",
                                "joinUrl": "https://teams.microsoft.com/l/meetup-join/x", "location": ""}])

    def test_accepts_wrapped_payloads(self):
        self.assertEqual(len(parse({"data": {"value": [ev()]}})), 1)
        self.assertEqual(parse({}), [])
        self.assertEqual(parse([]), [])
        self.assertEqual(parse(None), [])

    def test_skips_cancelled_and_all_day(self):
        self.assertEqual(parse({"value": [ev(isCancelled=True), ev(isAllDay=True)]}), [])

    def test_skips_unparseable_start(self):
        self.assertEqual(parse({"value": [ev(start={"dateTime": "soon", "timeZone": "UTC"})]}), [])

    def test_missing_end_defaults_to_one_hour(self):
        e = ev(); del e["end"]
        self.assertEqual(parse({"value": [e]})[0]["end"], "2026-10-07T10:00:00+00:00")

    def test_timezone_is_converted_to_utc(self):
        e = ev(start={"dateTime": "2026-10-07T11:00:00", "timeZone": "Europe/Zurich"}, end={"dateTime": "2026-10-07T12:00:00", "timeZone": "Europe/Zurich"})
        out = parse({"value": [e]})[0]
        self.assertEqual((out["start"], out["end"]), ("2026-10-07T09:00:00+00:00", "2026-10-07T10:00:00+00:00"))

    def test_unknown_timezone_falls_back_to_utc(self):
        out = parse({"value": [ev(start={"dateTime": "2026-10-07T09:00:00", "timeZone": "W. Europe Standard Time"})]})
        self.assertEqual(out[0]["start"], "2026-10-07T09:00:00+00:00")

    def test_join_url_sources(self):
        body = ev(bodyPreview="Join here: https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc thanks")
        self.assertEqual(parse({"value": [body]})[0]["joinUrl"], "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc")
        preferred = ev(onlineMeeting={"joinUrl": "https://j"}, bodyPreview="https://teams.microsoft.com/l/other")
        self.assertEqual(parse({"value": [preferred]})[0]["joinUrl"], "https://j")

    def test_outlook_web_link_is_not_a_join_url(self):
        out = parse({"value": [ev(webLink="https://outlook.office365.com/calendar/item/x", location={"displayName": " Room 4.12 "})]})[0]
        self.assertEqual((out["joinUrl"], out["location"]), ("", "Room 4.12"))

    def test_defaults_for_missing_subject_and_id(self):
        e = ev(); del e["subject"]; del e["id"]
        out = parse({"value": [e]})[0]
        self.assertEqual((out["subject"], out["id"]), ("(no subject)", "2026-10-07T09:00:00+00:00"))

    def test_sorted_by_start(self):
        a = ev(id="a", start={"dateTime": "2026-10-07T15:00:00", "timeZone": "UTC"})
        b = ev(id="b", start={"dateTime": "2026-10-07T08:00:00", "timeZone": "UTC"})
        self.assertEqual([x["id"] for x in parse({"value": [a, b]})], ["b", "a"])


if __name__ == "__main__":
    unittest.main()
