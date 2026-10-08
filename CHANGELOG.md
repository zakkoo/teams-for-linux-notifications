# Changelog

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
