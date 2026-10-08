# Changelog

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
