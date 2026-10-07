// node tests/model-check.js — asserts the label state machine against the spec scenarios.
const fs = require("fs"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(".pragma library", "")
const M = {}; new Function("exports", src + "\nexports.labelState=labelState;exports.toastDue=toastDue;")(M)

const now = Date.UTC(2026, 9, 7, 9, 0, 0)
const ev = (id, startMin, lenMin = 30) => ({ id, subject: id, start: new Date(now + startMin * 60000).toISOString(), end: new Date(now + (startMin + lenMin) * 60000).toISOString(), joinUrl: "" })
const S = (events, o = {}) => M.labelState(events, now, o.inCall || false, o.started || false, o.pulseAt || 0, o.horizon || 15, o.dismissed || {})

assert.equal(S([ev("Standup", 12)]).text, "Standup in 12m")
assert.deepEqual([S([ev("Standup", 12)]).title, S([ev("Standup", 12)]).suffix], ["Standup", "in 12m"])
assert.equal(S([ev("Later", 40)]).kind, "none")                        // outside horizon
assert.equal(S([ev("Later", 40)], { horizon: 60 }).text, "Later in 40m")
assert.equal(S([ev("B", 10), ev("A", 5)]).event.id, "A")               // earliest wins
assert.equal(S([ev("Standup", -1)]).text, "Standup · now")        // started, sticky
assert.deepEqual([S([ev("Standup", -1)], { inCall: true }).kind, S([ev("Standup", -1)], { inCall: true }).suffix], ["incall", "in call"])  // joined: stays, not urgent
assert.equal(S([], { inCall: true }).text, "In a call")
assert.equal(S([ev("Old", -60)]).kind, "none")                         // ended
assert.equal(S([ev("Early", 3)], { started: true }).kind, "now")
assert.equal(S([ev("Early", 3)], { started: true }).suffix, "now")       // pulse adopts near event
assert.equal(S([ev("Far", 12)], { started: true, pulseAt: now }).text, "Meeting started")
assert.equal(S([ev("Far", 12)], { started: true, pulseAt: now - 11 * 60000 }).text, "Far in 12m") // pulse expired
assert.equal(S([ev("Standup", -1)], { dismissed: { Standup: true } }).kind, "none")
assert.equal(M.toastDue(S([ev("X", 2)]), now, 2), true)
assert.equal(M.toastDue(S([ev("X", 3)]), now, 2), false)
assert.equal(M.toastDue(S([ev("X", -1)]), now, 0), true)
assert.equal(M.toastDue(S([ev("X", -30, 60)]), now, 0), false)   // long running: no re-announce after restart
console.log("model-check ok")
