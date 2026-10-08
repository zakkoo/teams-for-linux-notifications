// node --test tests/   — the bar label state machine, run against the spec scenarios.
const { test } = require("node:test")
const assert = require("node:assert/strict")
const fs = require("fs"), path = require("path")

const src = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(".pragma library", "")
const M = {}; new Function("exports", src + "\nexports.labelState=labelState;exports.toastDue=toastDue;exports.snoozeMinutes=snoozeMinutes;exports.popupOrder=popupOrder;exports.dueReminders=dueReminders;exports.dismissUntil=dismissUntil;exports.fmtTime=fmtTime;")(M)

const now = Date.UTC(2026, 9, 7, 9, 0, 0)
const ev = (id, startMin, lenMin = 30, extra = {}) => ({
  id, subject: id, joinUrl: "", location: "", ...extra,
  start: new Date(now + startMin * 60000).toISOString(), end: new Date(now + (startMin + lenMin) * 60000).toISOString(),
})
const S = (events, o = {}) => M.labelState(events, now, o.inCall || false, o.started || false, o.pulseAt || 0, o.horizon || 15, o.dismissed || {})

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
  assert.equal(M.labelState([ev("X", 0.5)], now, false, false, 0, 15, {}).suffix, "in 1m")
  assert.equal(M.labelState([ev("X", 11.1)], now, false, false, 0, 15, {}).suffix, "in 12m")
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
  assert.deepEqual([s.kind, s.title, s.suffix], ["now", "Standup", "now"])
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
  assert.deepEqual([s.kind, s.title, s.suffix], ["incall", "Standup", "in call"])
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

test("popup lists upcoming nearest-first, then finished most-recent-first, or hides finished", () => {
  const day = [ev("later", 120), ev("running", -10), ev("soon", 5), ev("old", -180), ev("recent", -60), { id: "bad", subject: "bad", start: "nope", end: "nope" }]
  const ids = (list) => list.map((e) => e.id)
  assert.deepEqual(ids(M.popupOrder(day, now, false)), ["running", "soon", "later", "recent", "old"])
  assert.deepEqual(ids(M.popupOrder(day, now, true)), ["running", "soon", "later"])
  assert.deepEqual(M.popupOrder(null, now, false), [])
})

test("due reminders: one card per due meeting, soonest first, capped at three", () => {
  const due = (events, o = {}) => M.dueReminders(events, now, o.inCall || false, false, 0, 60, o.dismissed || {}, o.lead ?? 15, o.remindAt || {})
  const ids = (list) => list.map((r) => r.event.id)
  const day = [ev("later", 40), ev("running", -3), ev("soon", 2), ev("next", 10), ev("old", -60, 30)]
  assert.deepEqual(ids(due(day, { lead: 60 })), ["running", "soon", "next"], "capped at three, soonest first")
  assert.deepEqual(due(day, { lead: 60 }).map((r) => r.kind), ["now", "upcoming", "upcoming"])
  assert.deepEqual(ids(due(day, { lead: 5 })), ["running", "soon"], "lead time applies per meeting")
  assert.deepEqual(ids(due(day, { lead: 60, dismissed: { running: true } })), ["soon", "next", "later"], "a freed slot admits the next meeting")
  assert.deepEqual(ids(due(day, { lead: 60, remindAt: { soon: now + 60000 } })), ["running", "next", "later"], "a snoozed meeting steps aside")
  assert.deepEqual(due(day, { inCall: true }), [], "nothing while in a call")
  assert.deepEqual(due([]), [])
})

test("fmtTime renders local HH:MM and tolerates garbage", () => {
  const d = new Date(2026, 0, 5, 9, 7)
  assert.equal(M.fmtTime(d.toISOString()), "09:07")
  assert.equal(M.fmtTime("garbage"), "")
})
