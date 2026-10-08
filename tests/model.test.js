// node --test tests/   — the meeting logic (bar label, reminders, popup sections) against the spec scenarios.
const { test } = require("node:test")
const assert = require("node:assert/strict")
const fs = require("fs"), path = require("path")

const src = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(".pragma library", "")
const M = {}
new Function("exports", src + "\n" + ["normalize", "pulseAdoptee", "eventState", "labelState", "toastDue", "dismissUntil", "snoozeMinutes", "dueReminders", "splitDay", "fmtTime"]
  .map((n) => `exports.${n}=${n};`).join(""))(M)

const now = Date.UTC(2026, 9, 7, 9, 0, 0)
const ev = (id, startMin, lenMin = 30, extra = {}) => ({
  id, subject: id, joinUrl: "", location: "",
  start: new Date(now + startMin * 60000).toISOString(), end: new Date(now + (startMin + lenMin) * 60000).toISOString(),
  ...extra,
})
// One context for every entry point; a scenario passes only what it is about.
const defined = (o) => Object.fromEntries(Object.entries(o).filter(([, v]) => v !== undefined))
const ctx = (events, o = {}) => ({ events, nowMs: now, horizonMin: 15, leadMin: 15, dismissed: {}, remindAt: {}, inCall: false, inCallEventId: "", meetingStarted: false, pulseAtMs: 0, hidePast: false, ...defined(o) })
const S = (events, o = {}) => M.labelState(ctx(events, { inCall: o.inCall, meetingStarted: o.started, pulseAtMs: o.pulseAt, horizonMin: o.horizon, dismissed: o.dismissed }))

// --- normalize / eventState

test("normalize parses once, drops unparsable starts, sorts by start", () => {
  const list = M.normalize([ev("B", 10), { id: "bad", start: "nope", end: "nope" }, ev("A", 5, 30, { end: "garbage" })])
  assert.deepEqual(list.map((x) => x.event.id), ["A", "B"])
  assert.equal(list[0].endMs, list[0].startMs, "unparsable end counts as ending at start")
  assert.deepEqual(M.normalize(null), [])
})

test("eventState judges one meeting alone", () => {
  const c = { nowMs: now, horizonMin: 15, adoptedId: null }
  const st = (e) => M.eventState(M.normalize([e])[0], c)
  assert.deepEqual(st(ev("running", -1)), { kind: "now", minutes: 0 })
  assert.deepEqual(st(ev("soon", 12)), { kind: "upcoming", minutes: 12 })
  assert.equal(st(ev("far", 16)).kind, "none")
  assert.equal(st(ev("ended", -60)).kind, "none")
  assert.equal(M.eventState(M.normalize([ev("adopted", 3)])[0], { ...c, adoptedId: "adopted" }).kind, "now")
})

test("a pulse adopts only the earliest unfinished event within five minutes", () => {
  const list = M.normalize([ev("later", 4), ev("first", 2), ev("far", 8), ev("ended", -40, 30)])
  assert.equal(M.pulseAdoptee(list, { nowMs: now, meetingStarted: true }), "first")
  assert.equal(M.pulseAdoptee(list, { nowMs: now, meetingStarted: false }), null)
  assert.equal(M.pulseAdoptee(M.normalize([ev("far", 8)]), { nowMs: now, meetingStarted: true }), null)
})

// --- labelState

test("empty and malformed input hide the widget", () => {
  assert.equal(S([]).kind, "none")
  assert.equal(S(null).kind, "none")
  assert.equal(S([{ id: "x", subject: "x", start: "not a date", end: "nope" }]).kind, "none")
})

test("upcoming within horizon shows title and countdown", () => {
  const s = S([ev("Standup", 12)])
  assert.deepEqual([s.kind, s.title, s.suffix, s.minutes], ["upcoming", "Standup", "in 12m", 12])
  assert.equal(s.text, "Standup in 12m")
})

test("countdown rounds up so 'in 1m' never shows 0", () => {
  assert.equal(S([ev("X", 0.5)]).suffix, "in 1m")
  assert.equal(S([ev("X", 11.1)]).suffix, "in 12m")
})

test("horizon boundary is inclusive", () => {
  assert.equal(S([ev("Edge", 15)]).kind, "upcoming")
  assert.equal(S([ev("Out", 15.1)]).kind, "none")
  assert.equal(S([ev("Out", 40)], { horizon: 60 }).suffix, "in 40m")
})

test("earliest upcoming wins regardless of input order", () => {
  assert.equal(S([ev("B", 10), ev("A", 5)]).event.id, "A")
  assert.equal(S([ev("A", 5), ev("B", 10)]).event.id, "A")
})

test("started and not joined is sticky 'now' in urgent kind", () => {
  const s = S([ev("Standup", -1)])
  assert.deepEqual([s.kind, s.title, s.suffix, s.text], ["now", "Standup", "now", "Standup · now"])
  assert.equal(S([ev("Standup", -29)]).kind, "now", "still running at the last minute")
  assert.equal(S([ev("Old", -60)]).kind, "none", "ended")
})

test("running meeting beats an upcoming one", () => {
  assert.equal(S([ev("Running", -5, 60), ev("Next", 3)]).event.id, "Running")
})

test("overlapping running meetings: the earlier started one is shown", () => {
  assert.equal(S([ev("Second", -2, 60), ev("First", -10, 60)]).event.id, "First")
})

test("in a call keeps the widget, non-urgent", () => {
  const s = S([ev("Standup", -1)], { inCall: true })
  assert.deepEqual([s.kind, s.title, s.suffix, s.text], ["incall", "Standup", "in call", "Standup · in call"])
  assert.equal(S([ev("Soon", 3)], { inCall: true }).title, "Soon", "joined a few minutes early still matches")
  assert.equal(S([ev("Far", 40)], { inCall: true }).text, "In a call", "no matching meeting")
  assert.equal(S([], { inCall: true }).text, "In a call")
})

test("meeting-started pulse adopts a nearby event", () => {
  assert.equal(S([ev("Early", 3)], { started: true }).kind, "now")
  assert.equal(S([ev("Early", 3)], { started: true }).suffix, "now")
  assert.equal(S([ev("Late", -4)], { started: true }).kind, "now")
  assert.equal(S([ev("TooFar", 6)], { started: true, pulseAt: now }).text, "Meeting started", "beyond 5 minutes is not adopted")
})

test("unmatched pulse shows a generic label for ten minutes", () => {
  assert.deepEqual(S([], { started: true, pulseAt: now }).kind, "started")
  assert.equal(S([], { started: true, pulseAt: now - 10 * 60000 }).kind, "started")
  assert.equal(S([ev("Far", 12)], { started: true, pulseAt: now - 11 * 60000 }).text, "Far in 12m", "expired pulse falls through")
  assert.equal(S([], { started: true, pulseAt: 0 }).kind, "none", "no timestamp means no label")
})

test("dismissed meetings are skipped entirely", () => {
  assert.equal(S([ev("Standup", -1)], { dismissed: { Standup: true } }).kind, "none")
  assert.equal(S([ev("A", -1), ev("B", 5)], { dismissed: { A: true } }).event.id, "B")
})

// --- reminders

test("toast is due at lead time, at start, but not long after", () => {
  assert.equal(M.toastDue(S([ev("X", 2)]), now, 2), true)
  assert.equal(M.toastDue(S([ev("X", 3)]), now, 2), false)
  assert.equal(M.toastDue(S([ev("X", -1)]), now, 0), true)
  assert.equal(M.toastDue(S([ev("X", -30, 60)]), now, 0), true, "a running, unjoined meeting stays due until acted on")
  assert.equal(M.toastDue(S([]), now, 2), false)
  assert.equal(M.toastDue(S([], { started: true, pulseAt: now }), now, 2), false, "no event, nothing to announce")
})

test("a snooze holds the reminder back until its deadline", () => {
  const up = S([ev("X", 8)])
  assert.equal(M.toastDue(up, now, 15, now + 60000), false, "snoozed")
  assert.equal(M.toastDue(up, now, 15, now), true, "deadline reached")
  assert.equal(M.toastDue(up, now, 15, undefined), true, "never snoozed")
  assert.equal(M.toastDue(S([ev("X", -1)]), now, 0, now - 1), true, "snooze elapsed, meeting started")
  assert.equal(M.toastDue(S([ev("X", -1)]), now, 0, Infinity), false, "joined from the card: never again")
})

test("dismiss before the start only holds the card until the start; after it, it skips the meeting", () => {
  const up = S([ev("X", 8)])
  assert.equal(M.dismissUntil(up), Date.parse(up.event.start))
  assert.equal(M.toastDue(up, now, 15, M.dismissUntil(up)), false, "early card silenced")
  assert.equal(M.toastDue(S([ev("X", 0)]), now, 15, Date.parse(up.event.start) - 8 * 60000), true, "start still announces itself")
  assert.equal(M.dismissUntil(S([ev("X", -1)])), null, "started: skip for good")
})

test("snooze halves the countdown, floors at 1, and is not offered at the end or once started", () => {
  const snooze = (min) => M.snoozeMinutes(S([ev("X", min)], { horizon: 60 }))
  assert.deepEqual([15, 8, 4, 2, 1].map(snooze), [7, 4, 2, 1, 0])
  assert.equal(snooze(-1), 0, "now")
  assert.equal(M.snoozeMinutes(S([])), 0)
  assert.ok(snooze(15) * 60000 < 15 * 60000, "a snooze always ends before the start")
})

test("due reminders: one card per due meeting, soonest first, capped at three", () => {
  const due = (events, o = {}) => M.dueReminders(ctx(events, { horizonMin: 60, leadMin: o.lead ?? 15, dismissed: o.dismissed, remindAt: o.remindAt, inCallEventId: o.inCallId }))
  const ids = (list) => list.map((r) => r.event.id)
  const day = [ev("later", 40), ev("running", -3), ev("soon", 2), ev("next", 10), ev("old", -60, 30)]
  assert.deepEqual(ids(due(day, { lead: 60 })), ["running", "soon", "next"], "capped at three, soonest first")
  assert.deepEqual(due(day, { lead: 60 }).map((r) => r.kind), ["now", "upcoming", "upcoming"])
  assert.deepEqual(ids(due(day, { lead: 5 })), ["running", "soon"], "lead time applies per meeting")
  assert.deepEqual(ids(due(day, { lead: 60, dismissed: { running: true } })), ["soon", "next", "later"], "a freed slot admits the next meeting")
  assert.deepEqual(ids(due(day, { lead: 60, remindAt: { soon: now + 60000 } })), ["running", "next", "later"], "a snoozed meeting steps aside")
  assert.deepEqual(ids(due(day, { lead: 60, inCallId: "running" })), ["soon", "next", "later"], "in a call: only that meeting is exempt, a clash still reminds")
  assert.deepEqual(due([]), [])
})

test("an unmatched meeting-started pulse holds no card back", () => {
  const planning = [ev("Planning", 8)]
  const c = { horizonMin: 15, leadMin: 10, meetingStarted: true, pulseAtMs: now }
  assert.equal(M.labelState(ctx(planning, c)).text, "Meeting started", "the bar shows the generic label")
  const due = M.dueReminders(ctx(planning, c))
  assert.deepEqual(due.map((r) => [r.event.id, r.kind, r.minutes]), [["Planning", "upcoming", 8]], "the card still comes")
  assert.equal(M.snoozeMinutes(due[0]), 4, "with its Remind-me button")
})

test("a pulse turns only the earliest nearby meeting into 'now'", () => {
  const two = [ev("Second", 4), ev("First", 2)]
  const due = M.dueReminders(ctx(two, { meetingStarted: true, pulseAtMs: now }))
  assert.deepEqual(due.map((r) => [r.event.id, r.kind]), [["First", "now"], ["Second", "upcoming"]])
  assert.equal(M.snoozeMinutes(due[1]), 2, "the later one keeps its countdown and Remind-me")
})

// --- popup

test("popup lists upcoming nearest-first, then finished most-recent-first, or hides finished", () => {
  const day = [ev("later", 120), ev("running", -10), ev("soon", 5), ev("old", -180), ev("recent", -60), { id: "bad", subject: "bad", start: "nope", end: "nope" }]
  const ids = (list) => list.map((e) => e.id)
  const shown = M.splitDay(ctx(day))
  assert.deepEqual([ids(shown.today), ids(shown.finished), shown.finishedCount], [["running", "soon", "later"], ["recent", "old"], 2])
  const hidden = M.splitDay(ctx(day, { hidePast: true }))
  assert.deepEqual([ids(hidden.today), hidden.finished, hidden.finishedCount], [["running", "soon", "later"], [], 2], "count survives hiding, for the toggle label")
  assert.deepEqual(M.splitDay(ctx(null)), { today: [], finished: [], finishedCount: 0 })
})

test("two sections: the spec's 11:00 day", () => {
  const at = (h, m) => (h * 60 + m) - 11 * 60   // minutes relative to 11:00
  const day = [ev("09:00", at(9, 0), 30), ev("10:00", at(10, 0), 30), ev("10:50", at(10, 50), 30), ev("11:30", at(11, 30), 30), ev("14:00", at(14, 0), 30)]
  const s = M.splitDay(ctx(day))
  assert.deepEqual([s.today.map((e) => e.id), s.finished.map((e) => e.id)], [["10:50", "11:30", "14:00"], ["10:00", "09:00"]])
})

test("fmtTime renders local HH:MM and tolerates garbage", () => {
  const d = new Date(2026, 0, 5, 9, 7)
  assert.equal(M.fmtTime(d.toISOString()), "09:07")
  assert.equal(M.fmtTime("garbage"), "")
})
