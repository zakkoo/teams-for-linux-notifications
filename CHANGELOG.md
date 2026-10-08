# Changelog

## 0.3.7

Hovering a cut-off meeting title or location now shows the whole text. The
tooltip used to run past the panel's edge and get clipped, so the longest
titles, the ones that needed it, were the ones it could not show. It now
wraps inside the panel.

## 0.3.6

No visible change. The setting defaults now live in one place in the plugin
(pinned to the manifest by a test) instead of being repeated in the widget,
the popup and the service, and the 15-second refresh tick and the 3-second
bridge restart delay are named rules rather than inline numbers.

## 0.3.5

Five fixes. A "meeting started" signal from Teams that matched no calendar
entry used to hold back every reminder card for ten minutes; now each meeting
is judged on its own. Staying in a call past the meeting's end no longer makes
the widget treat the next meeting as handled when you leave. The bridge's
calendar polling could die silently if Teams disconnected at the wrong moment,
a malformed packet could take the whole bridge down, and a Teams that died
without closing its connection left the widget saying "connected" forever and
blocked the reconnect; all three are fixed, and a settings change no longer
flashes a "bridge exited" error. Under the hood the meeting logic, the service
bookkeeping and the bridge were restructured into clearer, separately testable
pieces with no other change in behaviour.

## 0.3.4

The popup now has two sections: Today with the ongoing and upcoming meetings,
and Finished at the bottom with its own show/hide toggle. Finished meetings no
longer share a scrolling list with the rest, so they can never slip in between
upcoming ones.

## 0.3.3

Long titles in the bar no longer collapse to a few letters once scrolling
stops. The label area was sized from the label's own width, which Qt reports
as the elided width, so each pass cut the title a little shorter. The full
width is now measured separately, and the title parks at the left edge when
static.

## 0.3.2

Being in a call no longer silences every reminder. Only the meeting the call
belongs to is exempt; another meeting that reaches its lead time or starts
while you are in a call still gets its card, so a clash is visible.

## 0.3.1

Dismissing a reminder card before the meeting starts now only silences that
early reminder: the meeting stays in the bar and announces itself at the start
with Join and Dismiss. Dismissing a started meeting's card skips the meeting,
and the popup now shows skipped meetings dimmed with a one-click restore. A
started meeting's card no longer vanishes after five minutes; it stays until
you act. Once you leave a meeting's call the bar stays quiet for it instead of
turning urgent again. The calendar day is now the local day, not the UTC day.

## 0.3.0

Every due meeting now gets its own reminder card. Cards stack soonest first,
at most three at a time, each with its own Join, Remind me and Dismiss; a
further meeting takes a slot as soon as one frees up. A running meeting you
have not joined keeps its card until you act on it, as before.

## 0.2.2

Settings now take effect the instant they are saved: the bar label, the
reminder card and its countdown re-evaluate immediately instead of at the next
refresh. Changing the lead time or toggling the reminder clears any pending
snooze, so the new rule applies cleanly. The lead time is capped at the
horizon, since a meeting outside the horizon is never shown and could never
remind.

## 0.2.1

The reminder card now disappears the moment Join, Remind me or Dismiss is
pressed, and a middle-click dismissal clears the bar at once. Both used to wait
for the next 15-second refresh.

## 0.2.0

The optional reminder is now a card the widget draws itself, with Join,
Remind me and Dismiss buttons. Remind me halves the time left on every press
(15 min → 7 → 4 → 2 → 1) and the card comes back accordingly; clicking the
card body does nothing. It replaces the desktop notification, which the
Omarchy shell renders without buttons. The reminder setting keeps its key, so
nothing needs reconfiguring. The popup now lists what is still to come first,
nearest at the top, with finished meetings underneath, most recent first.

## 0.1.4

Meeting subjects and locations in the popup are rendered as plain text. Qt's
default AutoText treated invitation markup as rich text, which could fetch
attacker-chosen image URLs (marketplace review,
omarchy-plugin-marketplace#10443).

## 0.1.3

The calendar icon now stays in the bar at all times. Before, the widget
collapsed to nothing whenever no meeting fell inside the horizon, so there was
no way to tell "idle" from "crashed" and no click target for the popup. The
icon is dimmed while Teams for Linux is not connected, and hovering the idle
icon shows the connection status.

## 0.1.2

The reminder toast no longer contains the meeting subject at all. Every
notification transport ends in a process whose argv is world-readable, so the
only way to keep the title private is to leave it out; the bar and popup still
show it (marketplace review, omarchy-plugin-marketplace#10397).

## 0.1.1

Reminder toasts no longer put the meeting subject or join URL on the command
line of the notification helper, where other local users could read them via
process listings (marketplace review, omarchy-plugin-marketplace#10397).

## 0.1.0

First release as an Omarchy bar widget: next meeting with countdown in the bar,
sticky "now" until joined, popup with today's meetings, Join in Teams for Linux,
room shown for physical meetings, one-click Connect/Disconnect for Teams for
Linux, settings in the popup, optional pop-up reminder.
