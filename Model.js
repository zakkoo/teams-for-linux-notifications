.pragma library
// Pure meeting logic, no Qt. Tested by tests/model.test.js (node).
//
// Three layers, all pure:
//   normalize(events)        parse and sort once; everything else works on its output
//   eventState(item, ctx)    one meeting on its own: "now" | "upcoming" | "none"
//   labelState / dueReminders / splitDay   compose the bar label, the reminder
//                            cards and the popup sections from the two above
//
// Every entry point takes one context object; unused keys are ignored:
//   { events, nowMs, inCall, inCallEventId, meetingStarted, pulseAtMs,
//     horizonMin, leadMin, dismissed, remindAt, hidePast }
// events: [{id, subject, start, end, joinUrl, location}] with ISO strings.

var NOW_MATCH_MS = 5 * 60 * 1000      // meeting-started pulse adopts an event starting within +-5 min
var PULSE_TTL_MS = 10 * 60 * 1000     // unmatched pulse shown at most this long
var MAX_REMINDERS = 3

// [{event, startMs, endMs}] sorted by start; events without a parsable start
// are dropped, an unparsable end counts as "ends at start".
function normalize(events) {
  var list = []
  var arr = events || []
  for (var i = 0; i < arr.length; i++) {
    var e = arr[i]
    var start = Date.parse(e.start)
    if (isNaN(start)) continue
    var end = Date.parse(e.end)
    list.push({ event: e, startMs: start, endMs: isNaN(end) ? start : end })
  }
  list.sort(function (a, b) { return a.startMs - b.startMs })
  return list
}

function notDismissed(list, dismissed) {
  return list.filter(function (x) { return !(dismissed && dismissed[x.event.id]) })
}

// The one event a meeting-started pulse stands for: the earliest unfinished
// event starting within +-5 min of now. null when none (or no pulse).
function pulseAdoptee(list, ctx) {
  if (!ctx.meetingStarted) return null
  for (var i = 0; i < list.length; i++) {
    if (Math.abs(list[i].startMs - ctx.nowMs) <= NOW_MATCH_MS && ctx.nowMs < list[i].endMs) return list[i].event.id
  }
  return null
}

// One meeting judged alone. "now": running, or adopted by the pulse.
// "upcoming": starts within the horizon; minutes rounds up so it never reads 0.
function eventState(item, ctx) {
  var now = ctx.nowMs
  if (item.startMs <= now && now < item.endMs) return { kind: "now", minutes: 0 }
  if (ctx.adoptedId && item.event.id === ctx.adoptedId) return { kind: "now", minutes: 0 }
  var dt = item.startMs - now
  if (dt > 0 && dt <= (ctx.horizonMin || 0) * 60000) return { kind: "upcoming", minutes: Math.ceil(dt / 60000) }
  return { kind: "none", minutes: 0 }
}

function label(kind, event, title, suffix, minutes) {
  return { kind: kind, event: event, title: title, suffix: suffix, text: suffix ? title + " · " + suffix : title, minutes: minutes || 0 }
}

// The bar label: {kind: "none"|"upcoming"|"now"|"started"|"incall", event, title, suffix, text, minutes}
function labelState(ctx) {
  var list = notDismissed(normalize(ctx.events), ctx.dismissed)
  var i
  if (ctx.inCall) {  // stay visible, just not urgent: the meeting you are in, or a plain "in a call"
    for (i = 0; i < list.length; i++) {
      if (list[i].startMs - NOW_MATCH_MS <= ctx.nowMs && ctx.nowMs < list[i].endMs)
        return label("incall", list[i].event, list[i].event.subject, "in call")
    }
    return label("incall", null, "In a call", "")
  }
  var c = { nowMs: ctx.nowMs, horizonMin: ctx.horizonMin, adoptedId: pulseAdoptee(list, ctx) }
  for (i = 0; i < list.length; i++) {
    if (eventState(list[i], c).kind === "now") return label("now", list[i].event, list[i].event.subject, "now")
  }
  if (ctx.meetingStarted && ctx.pulseAtMs && ctx.nowMs - ctx.pulseAtMs <= PULSE_TTL_MS)
    return label("started", null, "Meeting started", "")
  for (i = 0; i < list.length; i++) {
    var s = eventState(list[i], c)
    if (s.kind === "upcoming") {
      var r = label("upcoming", list[i].event, list[i].event.subject, "in " + s.minutes + "m", s.minutes)
      r.text = list[i].event.subject + " in " + s.minutes + "m"
      return r
    }
  }
  return label("none", null, "", "")
}

// The reminder is due when the state is "now" (and stays due until the user
// acts, the call is joined or the meeting ends) or the event starts within
// leadMin. remindAt (ms, optional) holds the card back until then: a snooze
// deadline, the start time after an early dismiss, or Infinity once joined.
function toastDue(state, nowMs, leadMin, remindAt) {
  if (!state.event) return false
  if (remindAt && nowMs < remindAt) return false
  if (state.kind === "now") return true
  return state.kind === "upcoming" && Date.parse(state.event.start) - nowMs <= leadMin * 60000
}

// Dismissing a card before the start only silences the early reminder: the
// start still announces itself. Returns the hold-back time, or null when the
// meeting has started and dismiss means "skip it for good".
function dismissUntil(state) {
  return state.kind === "upcoming" ? Date.parse(state.event.start) : null
}

// Half the shown countdown, so a snooze always ends before the meeting starts.
// 0 means "do not offer": the meeting started or at most one minute is left.
function snoozeMinutes(state) {
  return state.kind === "upcoming" && state.minutes > 1 ? Math.floor(state.minutes / 2) : 0
}

// Every meeting that deserves a reminder card right now, each judged on its
// own, soonest start first and capped at MAX_REMINDERS so a later meeting
// waits until a slot frees up. Being in a call exempts only the meeting the
// call belongs to (ctx.inCallEventId). A pulse that matches no event, or a
// different event, holds nothing back. Returns [{event, kind, minutes}].
function dueReminders(ctx) {
  var out = []
  var list = notDismissed(normalize(ctx.events), ctx.dismissed)
  var c = { nowMs: ctx.nowMs, horizonMin: ctx.horizonMin, adoptedId: pulseAdoptee(list, ctx) }
  for (var i = 0; i < list.length && out.length < MAX_REMINDERS; i++) {
    var e = list[i].event
    if (ctx.inCallEventId && e.id === ctx.inCallEventId) continue
    var s = eventState(list[i], c)
    if (s.kind === "none") continue
    var state = { kind: s.kind, event: e, minutes: s.minutes }
    if (toastDue(state, ctx.nowMs, ctx.leadMin || 0, (ctx.remindAt || {})[e.id])) out.push(state)
  }
  return out
}

// Popup sections: today = still running or to come, nearest start first;
// finished = ended, most recently ended first (empty when ctx.hidePast).
function splitDay(ctx) {
  var list = normalize(ctx.events)
  var today = [], finished = []
  for (var i = 0; i < list.length; i++) (list[i].endMs <= ctx.nowMs ? finished : today).push(list[i].event)
  finished.reverse()
  return { today: today, finished: ctx.hidePast ? [] : finished, finishedCount: finished.length }
}

function fmtTime(iso) {
  var d = new Date(iso)
  return isNaN(d) ? "" : (d.getHours() < 10 ? "0" : "") + d.getHours() + ":" + (d.getMinutes() < 10 ? "0" : "") + d.getMinutes()
}
