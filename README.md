# Teams Meetings for Omarchy

## Prerequisites

- **Omarchy 4.** The widget lives in the Omarchy bar and starts with the shell.
- **[Teams for Linux](https://github.com/IsmaelMartinez/teams-for-linux) 2.20 or newer**, signed in. A package, Flatpak, or Snap install all work. The plugin finds that config on its own.
- **Python 3** at `/usr/bin/python3`. Omarchy already includes it.

Teams for Linux has to be running for meetings to appear.

## Install

```bash
omarchy plugin add https://github.com/zakkoo/teams-for-linux-notifications.git --enable
```

A calendar icon shows up in the center of the bar. Click it and press **Connect Teams for Linux**.

Connect writes a few lines into Teams for Linux's config and keeps a timestamped backup next to that file. Restart Teams for Linux once. The popup tells you when that restart is the step left.

The icon stays dim until Teams connects. Hover it and it says why.

To move the icon:

```bash
omarchy bar move io.github.zakkoo.teams-for-linux-notifications --section right
```

## It comes and finds you

Your next meeting sits on the bar and counts down in the open. Once it is inside the next 15 minutes the bar reads **Standup in 12m**, then 11, then 10. When the meeting starts and you still have not joined, the label turns urgent and stays there: **Standup · now**. It stays until you join, you dismiss it, or the meeting ends. In the call it settles to **Standup · in call**. The rest of the day the calendar icon stays put, quiet.

The part that taps you on the shoulder is the reminder card. Open the icon, turn on **Reminder card as well**, and choose how many minutes before the start it should appear. A card then drops onto the screen you are looking at, over whatever you are doing:

**Standup**
Teams meeting in 15 min

**Join** · **Remind me in 7 min** · **Dismiss**

Remind me sends the card away and brings it back with half the time left. Fifteen minutes becomes a nudge in seven, then four, then two. Inside the last minute that button is gone. Join, or dismiss.

Dismiss before the start only silences that early card. The moment the meeting begins, the card comes back and waits. Dismiss then, and you have skipped the meeting. It stays in the day's list, dimmed, and you can restore it with one click.

Clicking the card outside its buttons does nothing. You join on purpose.

Join opens the meeting in Teams for Linux. A room booking shows the room. Already in a call? That meeting stays quiet, and the next one still gets its own card. Up to three cards stack, soonest on top. A fourth waits until you clear one.

Right-click the bar to join the meeting it is showing. Left-click for the rest of today.

The calendar is the one already signed in inside Teams for Linux. **Connect** is the only setup.

![Preview](preview.png)
