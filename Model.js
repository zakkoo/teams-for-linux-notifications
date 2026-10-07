.pragma library
// Pure label logic, no Qt. Mirrored by tests/model-check.js (node).

var NOW_MATCH_MS = 5 * 60 * 1000      // meeting-started pulse adopts an event starting within +-5 min
var PULSE_TTL_MS = 10 * 60 * 1000     // unmatched pulse shown at most this long

// events: [{id, subject, start, end, joinUrl}] with ISO strings; returns
// {kind: "none"|"upcoming"|"now"|"started", event, text, minutes}
function labelState(events, nowMs, inCall, meetingStarted, pulseAtMs, horizonMin, dismissed) {
  if (inCall) return { kind: "none", event: null, text: "" }
  var list = (events || []).map(function (e) {
    return { e: e, start: Date.parse(e.start), end: Date.parse(e.end) }
  }).filter(function (x) { return !isNaN(x.start) && !(dismissed && dismissed[x.e.id]) })
  list.sort(function (a, b) { return a.start - b.start })

  var i
  for (i = 0; i < list.length; i++) {
    if (list[i].start <= nowMs && nowMs < list[i].end)
      return { kind: "now", event: list[i].e, text: list[i].e.subject + " · now", minutes: 0 }
  }
  if (meetingStarted) {
    for (i = 0; i < list.length; i++) {
      if (Math.abs(list[i].start - nowMs) <= NOW_MATCH_MS && nowMs < list[i].end)
        return { kind: "now", event: list[i].e, text: list[i].e.subject + " · now", minutes: 0 }
    }
    if (pulseAtMs && nowMs - pulseAtMs <= PULSE_TTL_MS)
      return { kind: "started", event: null, text: "Meeting started", minutes: 0 }
  }
  for (i = 0; i < list.length; i++) {
    var dt = list[i].start - nowMs
    if (dt > 0 && dt <= horizonMin * 60 * 1000) {
      var m = Math.ceil(dt / 60000)
      return { kind: "upcoming", event: list[i].e, text: list[i].e.subject + " in " + m + "m", minutes: m }
    }
  }
  return { kind: "none", event: null, text: "" }
}

// Toast is due when the state is "now" or the event starts within leadMin.
function toastDue(state, nowMs, leadMin) {
  if (!state.event) return false
  if (state.kind === "now") return true
  return state.kind === "upcoming" && Date.parse(state.event.start) - nowMs <= leadMin * 60000
}

function fmtTime(iso) {
  var d = new Date(iso)
  return isNaN(d) ? "" : (d.getHours() < 10 ? "0" : "") + d.getHours() + ":" + (d.getMinutes() < 10 ? "0" : "") + d.getMinutes()
}
