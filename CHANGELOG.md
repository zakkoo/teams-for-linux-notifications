# Changelog

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
