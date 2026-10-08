.pragma library
// Pure label logic, no Qt. Mirrored by tests/model-check.js (node).

var NOW_MATCH_MS = 5 * 60 * 1000      // meeting-started pulse adopts an event starting within +-5 min
var PULSE_TTL_MS = 10 * 60 * 1000     // unmatched pulse shown at most this long

// events: [{id, subject, start, end, joinUrl}] with ISO strings; returns
// {kind: "none"|"upcoming"|"now"|"started", event, text, minutes}
function labelState(events, nowMs, inCall, meetingStarted, pulseAtMs, horizonMin, dismissed) {
  var list = (events || []).map(function (e) {
    return { e: e, start: Date.parse(e.start), end: Date.parse(e.end) }
  }).filter(function (x) { return !isNaN(x.start) && !(dismissed && dismissed[x.e.id]) })
  list.sort(function (a, b) { return a.start - b.start })

  var i
  if (inCall) {  // stay visible, just not urgent: the meeting you are in, or a plain "in a call"
    for (i = 0; i < list.length; i++) {
      if (list[i].start - NOW_MATCH_MS <= nowMs && nowMs < list[i].end)
        return { kind: "incall", event: list[i].e, title: list[i].e.subject, suffix: "in call", text: list[i].e.subject + " \u00b7 in call", minutes: 0 }
    }
    return { kind: "incall", event: null, title: "In a call", suffix: "", text: "In a call", minutes: 0 }
  }
  for (i = 0; i < list.length; i++) {
    if (list[i].start <= nowMs && nowMs < list[i].end)
      return { kind: "now", event: list[i].e, title: list[i].e.subject, suffix: "now", text: list[i].e.subject + " · now", minutes: 0 }
  }
  if (meetingStarted) {
    for (i = 0; i < list.length; i++) {
      if (Math.abs(list[i].start - nowMs) <= NOW_MATCH_MS && nowMs < list[i].end)
        return { kind: "now", event: list[i].e, title: list[i].e.subject, suffix: "now", text: list[i].e.subject + " · now", minutes: 0 }
    }
    if (pulseAtMs && nowMs - pulseAtMs <= PULSE_TTL_MS)
      return { kind: "started", event: null, title: "Meeting started", suffix: "", text: "Meeting started", minutes: 0 }
  }
  for (i = 0; i < list.length; i++) {
    var dt = list[i].start - nowMs
    if (dt > 0 && dt <= horizonMin * 60 * 1000) {
      var m = Math.ceil(dt / 60000)
      return { kind: "upcoming", event: list[i].e, title: list[i].e.subject, suffix: "in " + m + "m", text: list[i].e.subject + " in " + m + "m", minutes: m }
    }
  }
  return { kind: "none", event: null, title: "", suffix: "", text: "" }
}

// The reminder is due when the state is "now" or the event starts within
// leadMin, but never for a meeting already running for a while: a shell
// restart must not re-announce the meeting you are sitting in. remindAt (ms,
// optional) holds the card back until then: a snooze deadline, or Infinity
// once the user joined from the card.
function toastDue(state, nowMs, leadMin, remindAt) {
  if (!state.event) return false
  var start = Date.parse(state.event.start)
  if (nowMs - start > NOW_MATCH_MS) return false
  if (remindAt && nowMs < remindAt) return false
  if (state.kind === "now") return true
  return state.kind === "upcoming" && start - nowMs <= leadMin * 60000
}

// Half the shown countdown, so a snooze always ends before the meeting starts.
// 0 means "do not offer": the meeting started or at most one minute is left.
function snoozeMinutes(state) {
  return state.kind === "upcoming" && state.minutes > 1 ? Math.floor(state.minutes / 2) : 0
}

var MAX_REMINDERS = 3

// Every meeting that deserves a reminder card right now, judged on its own
// with the same rules as the bar label, soonest start first and capped at
// MAX_REMINDERS so a later meeting waits until a slot frees up. remindAt maps
// event id to a hold-back time (see toastDue). Returns [{event, kind, minutes}].
function dueReminders(events, nowMs, inCall, meetingStarted, pulseAtMs, horizonMin, dismissed, leadMin, remindAt) {
  var out = []
  var list = (events || []).slice().sort(function (a, b) { return Date.parse(a.start) - Date.parse(b.start) })
  for (var i = 0; i < list.length && out.length < MAX_REMINDERS; i++) {
    var s = labelState([list[i]], nowMs, inCall, meetingStarted, pulseAtMs, horizonMin, dismissed)
    if (s.event && toastDue(s, nowMs, leadMin, (remindAt || {})[s.event.id])) out.push({ event: s.event, kind: s.kind, minutes: s.minutes })
  }
  return out
}

// Popup order: what is still to come first, nearest at the top; finished
// meetings after that, most recently ended first, or left out entirely.
function popupOrder(events, nowMs, hidePast) {
  var list = (events || []).filter(function (e) { return !isNaN(Date.parse(e.start)) })
  var past = function (e) { return Date.parse(e.end) <= nowMs }
  if (hidePast) list = list.filter(function (e) { return !past(e) })
  list.sort(function (a, b) {
    if (past(a) !== past(b)) return past(a) ? 1 : -1
    var d = Date.parse(a.start) - Date.parse(b.start)
    return past(a) ? -d : d
  })
  return list
}

function fmtTime(iso) {
  var d = new Date(iso)
  return isNaN(d) ? "" : (d.getHours() < 10 ? "0" : "") + d.getHours() + ":" + (d.getMinutes() < 10 ? "0" : "") + d.getMinutes()
}
