# Meeting Bar Widget

## Purpose

Shows the user's next Teams meeting and an in-progress meeting directly in the Omarchy bar, without popups, so they can see what is coming without clicking anything.

## Requirements

### Requirement: Upcoming meeting label
The widget SHALL display the subject and minutes-until-start of the earliest non-cancelled, non-all-day event whose start lies within the configured horizon. When no event qualifies and no meeting is in progress, the widget SHALL still show the calendar icon with no text.

#### Scenario: One event inside the horizon
- **WHEN** the horizon is 15 minutes and an event titled "Standup" starts in 12 minutes
- **THEN** the bar shows "Standup in 12m" and the countdown decreases over time

#### Scenario: No event inside the horizon
- **WHEN** the next event starts in 40 minutes and the horizon is 15 minutes
- **THEN** the bar shows only the calendar icon in the normal bar colour, and hovering it shows the connection status ("Connected", or "Connected · no calendar received yet")

#### Scenario: Several events inside the horizon
- **WHEN** two events start in 5 and 10 minutes
- **THEN** only the one starting in 5 minutes is shown

### Requirement: Meeting-in-progress label is sticky
The widget SHALL switch to an urgent "now" style for an event that has started and the user has not joined, and SHALL keep it until the user is in a call, the event ends, or the user dismisses it. While the user is in a call the widget SHALL stay visible in its normal colour, showing the meeting title with "in call", or "In a call" when no calendar event matches.

#### Scenario: Start time reached
- **WHEN** the current time passes an event's start and Teams reports no active call
- **THEN** the bar shows "<subject> · now" in the bar's urgent colour

#### Scenario: Teams reports the meeting started early
- **WHEN** Teams publishes a meeting-started pulse and an event starts within 5 minutes
- **THEN** that event is shown in the "now" style immediately

#### Scenario: User joins
- **WHEN** Teams reports an active call
- **THEN** the urgent "now" label turns into the normal-coloured title with "in call" and stays until the call ends

#### Scenario: Pulse without a matching event
- **WHEN** a meeting-started pulse arrives and no event starts within 5 minutes
- **THEN** the bar shows "Meeting started" without a join action until an active call is reported or 10 minutes pass

### Requirement: Clicks
Left-clicking the widget SHALL open the popup. Right-clicking SHALL open the shown event's join link in Teams for Linux (falling back to the system URL handler when Teams for Linux is not installed), or open the popup when no event with a join link is shown. Middle-clicking SHALL dismiss the shown meeting and SHALL do nothing when no meeting is shown.

#### Scenario: Left-click
- **WHEN** the user left-clicks the widget
- **THEN** the popup with today's events, settings and the connection controls opens

#### Scenario: Left-click while idle
- **WHEN** no meeting is shown, or Teams for Linux is not connected, and the user left-clicks the icon
- **THEN** the popup opens

#### Scenario: Right-click with a join URL
- **WHEN** the shown event has a Teams join link and the user right-clicks
- **THEN** the link is handed to Teams for Linux, not the browser

#### Scenario: Right-click while idle
- **WHEN** no meeting is shown and the user right-clicks the icon
- **THEN** the popup opens

#### Scenario: Middle-click while idle
- **WHEN** no meeting is shown and the user middle-clicks the icon
- **THEN** nothing changes

#### Scenario: Physical meeting in the popup
- **WHEN** a meeting has no join link
- **THEN** the popup shows its location instead of a Join button

#### Scenario: Join button in the popup
- **WHEN** the user presses Join on a meeting in the popup
- **THEN** the link is handed to Teams for Linux, not the browser

### Requirement: Always visible, dimmed without Teams
The widget SHALL always occupy space in the bar and show the calendar icon. While Teams for Linux is not connected to the bridge, for any reason (bridge starting, Teams not running, Teams not yet configured to connect), the icon SHALL be dimmed and no text SHALL be shown, so the user can tell an idle widget from a broken one and the popup stays reachable. Hovering the dimmed icon SHALL show the reason in a tooltip.

#### Scenario: Setup needed
- **WHEN** Teams for Linux's config does not contain the plugin's MQTT keys
- **THEN** the bar shows a dimmed icon with no text, hovering it says Teams for Linux is not connected yet, and clicking it opens the popup

#### Scenario: Teams quits
- **WHEN** Teams for Linux disconnects
- **THEN** within 10 seconds any meeting text disappears and the icon turns dimmed, regardless of pending events; hovering it says the widget is waiting for Teams for Linux

#### Scenario: Teams returns
- **WHEN** Teams for Linux reconnects
- **THEN** the icon returns to the normal bar colour and the meeting label, if any, reappears

### Requirement: Popup meeting list
The popup SHALL show today's meetings in two separate sections: "Today" with the ongoing and upcoming meetings, nearest start at the top, and "Finished" at the bottom with the finished meetings, most recently ended first. Finished meetings SHALL never appear in the Today list. Each section SHALL show at most five rows before scrolling on its own. Finished meetings SHALL be greyed out and struck through, and the Finished section SHALL offer a one-click show/hide toggle that persists as a setting. The plugin version SHALL sit unobtrusively in the bottom-right corner.

#### Scenario: Two sections
- **WHEN** today has meetings at 09:00 and 10:00 (finished), one running since 10:50, and more at 11:30 and 14:00, and it is 11:00
- **THEN** Today lists 10:50, 11:30, 14:00 and Finished lists 10:00, then 09:00, underneath

#### Scenario: Many meetings
- **WHEN** a section has more than five meetings
- **THEN** that section is five rows tall and scrolls, the other is unaffected

#### Scenario: Finished meeting
- **WHEN** a meeting's end time has passed
- **THEN** its row is dimmed and struck through, keeping its Join button or location

#### Scenario: Cut title or location
- **WHEN** a meeting title or location is cut in the popup and the user hovers it
- **THEN** a tooltip shows the full text

#### Scenario: Hide finished
- **WHEN** the user clicks "Hide N" in the Finished section
- **THEN** the finished list collapses, the section header stays, and it remains collapsed on later opens until "Show N" is clicked

### Requirement: Long titles
Titles wider than the label area SHALL never widen the bar. Depending on the scroll setting they SHALL scroll continuously (Always), scroll a configured number of times and then stop (A few times), or be cut at the edge (Never). Whenever the title is cut, hovering the widget SHALL show the full title in a tooltip.

#### Scenario: Always
- **WHEN** the subject is longer than the label area and scroll is Always
- **THEN** the label width is capped and the text scrolls without end

#### Scenario: A few times
- **WHEN** scroll is "A few times" with 3 and a long title appears
- **THEN** the text scrolls through three times and then stays cut at the edge

#### Scenario: Never
- **WHEN** scroll is Never and the title is longer than the label area
- **THEN** the title is cut with an ellipsis and hovering shows the full title

### Requirement: Reminder card
When the reminder setting is enabled, the widget SHALL show a reminder card as an overlay on the focused screen for every meeting whose time to start is at most the lead time or that is in the "now" state, each meeting judged on its own. The judgement for one meeting SHALL depend only on that meeting's times, the current time, and whether a meeting-started pulse adopts it; a pulse that matches no event, or a different event, SHALL NOT hold back any other meeting's card. Cards SHALL stack soonest-start first, at most three at a time; a further due meeting SHALL get a card as soon as one of the three is gone. A card SHALL show the meeting subject and the time to start (or "now"). It SHALL offer a Join button when the meeting has a join link, a Dismiss button, and a Remind-me button while the meeting has not started and more than one minute remains. A card SHALL stay until one of its buttons is pressed, its meeting is dismissed elsewhere, the user is in that meeting's call, or its meeting ends. Being in a call exempts only the meeting the call belongs to; other meetings still get their cards. Clicking a card anywhere outside its buttons SHALL do nothing. The lead time SHALL be capped at the horizon, since a meeting outside the horizon is never shown.

#### Scenario: Card appears at the lead time
- **WHEN** the reminder is on, the lead time is 15 minutes, and "Standup" with a join link starts in 15 minutes
- **THEN** a card reading "Standup in 15 min" appears with the buttons Join, "Remind me in 7 min" and Dismiss

#### Scenario: Card body is inert
- **WHEN** the user clicks the card's text or background
- **THEN** nothing happens and the card stays

#### Scenario: Physical meeting
- **WHEN** the shown meeting has no join link
- **THEN** the card has no Join button and shows the location under the subject when one is set

#### Scenario: Meeting starts while the card is up
- **WHEN** the card is showing and the meeting's start time passes
- **THEN** the card reads "<subject> · now" and the Remind-me button disappears

#### Scenario: User joins from elsewhere
- **WHEN** the card is showing and Teams reports an active call for that meeting
- **THEN** the card closes

#### Scenario: Another meeting starts during a call
- **WHEN** the user is in the call for Standup and Planning reaches its lead time or starts
- **THEN** Planning gets its card with Join and Dismiss while Standup gets none

#### Scenario: Several meetings due
- **WHEN** one meeting is running unjoined and two more start in 2 and 10 minutes, all within the lead time
- **THEN** three cards are stacked in that order, each with its own buttons, and a fourth due meeting appears only after one of them is joined, snoozed or dismissed

#### Scenario: Settings apply at once
- **WHEN** the user changes the lead time or toggles the reminder
- **THEN** cards appear or disappear immediately, and any snooze made under the old setting is forgotten

#### Scenario: Reminder disabled (default)
- **WHEN** the reminder is off and a meeting reaches the lead time or starts
- **THEN** no card is shown

#### Scenario: Unmatched pulse does not hold back a card
- **WHEN** Teams sends a meeting-started pulse that matches no event within 5 minutes, the bar shows "Meeting started", and Planning starts in 8 minutes with a lead time of 10
- **THEN** Planning's card reading "Planning in 8 min" appears regardless of the pulse

#### Scenario: Pulse adopts one meeting only
- **WHEN** a meeting-started pulse arrives and two meetings start within 5 minutes of now
- **THEN** only the earlier one is shown in the "now" form; the later one keeps its countdown and its Remind-me button

### Requirement: Reminder card buttons
Join SHALL hand the meeting's link to Teams for Linux (with the same fallback as the widget's right-click) and close the card for good. Dismiss on a card before the start SHALL close that card only; the meeting SHALL still get its card at the start. Dismiss on a started meeting's card SHALL skip the meeting exactly as a middle-click on the widget does. A skipped meeting SHALL appear dimmed in the popup with a one-click restore. Once the user has been in a meeting's call and left it, that meeting SHALL count as handled: no card returns and the bar does not turn urgent for it. The meeting a call belongs to SHALL be fixed when the call starts (or, when the calendar arrives later, the first time a meeting matches during that call) and SHALL NOT change for the rest of the call, even when its end time passes while the call continues. Remind-me SHALL close the card and show it again after half the remaining time to the start, rounded down to whole minutes and never less than one; the button label SHALL state that number of minutes. Each time the card reappears, the countdown and the Remind-me interval SHALL be recomputed from the then-remaining time.

#### Scenario: Halving snooze chain
- **WHEN** the card says "in 15 min" and the user presses "Remind me in 7 min"
- **THEN** the card closes, reappears with about 8 minutes left reading "in 8 min", and its button now says "Remind me in 4 min"

#### Scenario: Snooze floor
- **WHEN** the card reappears with 2 minutes left
- **THEN** the button says "Remind me in 1 min"; with 1 minute or less left the button is not offered

#### Scenario: Dismiss before the start
- **WHEN** the card says "Standup in 8 min" and the user presses Dismiss
- **THEN** the card closes, the bar keeps counting down to Standup, and at the start a card reading "Standup · now" appears with Join and Dismiss

#### Scenario: Dismiss after the start
- **WHEN** the user presses Dismiss on the card "Standup · now"
- **THEN** the card closes, the bar no longer shows Standup, the popup shows Standup dimmed with "Skipped · restore", and no further card is shown for it

#### Scenario: Restore a skipped meeting
- **WHEN** the user presses "Skipped · restore" in the popup
- **THEN** the meeting returns to the bar and, if due, its card

#### Scenario: Left the call
- **WHEN** Teams reports the call for Standup ended while Standup is still running
- **THEN** the bar does not turn urgent for Standup and no card appears for it

#### Scenario: Call overruns into the next meeting
- **WHEN** the user is in the call for Standup (10:00–10:30), stays in it until 10:40, and Planning is scheduled 10:30–11:00
- **THEN** leaving the call marks only Standup as handled; Planning turns the bar urgent and gets its card as if the user had never been in a call

#### Scenario: Join
- **WHEN** the user presses Join
- **THEN** the link is handed to Teams for Linux, not the browser, and the card closes

#### Scenario: Snoozed meeting reaches its start
- **WHEN** the card is snoozed and the meeting starts before the snooze elapses
- **THEN** the card reappears at the start in the "now" form
