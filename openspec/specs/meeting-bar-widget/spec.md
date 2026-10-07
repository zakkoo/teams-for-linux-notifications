# Meeting Bar Widget

## Purpose

Shows the user's next Teams meeting and an in-progress meeting directly in the Omarchy bar, without popups, so they can see what is coming without clicking anything.

## Requirements

### Requirement: Upcoming meeting label
The widget SHALL display the subject and minutes-until-start of the earliest non-cancelled, non-all-day event whose start lies within the configured horizon.

#### Scenario: One event inside the horizon
- **WHEN** the horizon is 15 minutes and an event titled "Standup" starts in 12 minutes
- **THEN** the bar shows "Standup in 12m" and the countdown decreases over time

#### Scenario: No event inside the horizon
- **WHEN** the next event starts in 40 minutes and the horizon is 15 minutes
- **THEN** the widget occupies no space in the bar

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
Left-clicking the widget SHALL open the popup. Right-clicking SHALL open the shown event's join link in Teams for Linux (falling back to the system URL handler when Teams for Linux is not installed). Middle-clicking SHALL dismiss the shown meeting.

#### Scenario: Left-click
- **WHEN** the user left-clicks the widget
- **THEN** the popup with today's events, settings and the connection controls opens

#### Scenario: Right-click with a join URL
- **WHEN** the shown event has a Teams join link and the user right-clicks
- **THEN** the link is handed to Teams for Linux, not the browser

#### Scenario: Physical meeting in the popup
- **WHEN** a meeting has no join link
- **THEN** the popup shows its location instead of a Join button

#### Scenario: Join button in the popup
- **WHEN** the user presses Join on a meeting in the popup
- **THEN** the link is handed to Teams for Linux, not the browser

### Requirement: Hidden without Teams
The widget SHALL occupy no space while Teams for Linux is not connected to the bridge, except while Teams has not yet been configured to connect, when it SHALL show only a dimmed icon so the Connect action stays reachable.

#### Scenario: Setup needed
- **WHEN** Teams for Linux's config does not contain the plugin's MQTT keys
- **THEN** the bar shows a dimmed icon with no text, and clicking it opens the popup

#### Scenario: Teams quits
- **WHEN** Teams for Linux disconnects
- **THEN** the widget disappears within 10 seconds, regardless of pending events

### Requirement: Optional toast
When the toast setting is enabled, the widget SHALL send one desktop notification per meeting on the transition into the "now" state, and none otherwise. The notification SHALL NOT contain the meeting subject: every notification transport (omarchy-notification-send, notify-send, busctl) ends in a process whose argv is world-readable via `/proc/*/cmdline`, so a generic headline ("Teams meeting now" / "Teams meeting in N min") is used and the bar/popup remain the place to see which meeting it is.

#### Scenario: Toast enabled
- **WHEN** toast is on and an event enters the "now" state
- **THEN** exactly one notification with a generic headline is sent; if the meeting has a join URL, clicking it opens the meeting in Teams for Linux

#### Scenario: Subject hidden from other local users
- **WHEN** a toast is being sent
- **THEN** the meeting subject appears nowhere in the toast code path, so no process's `ps`/`/proc/*/cmdline` can show it

#### Scenario: Toast disabled (default)
- **WHEN** toast is off and an event enters the "now" state
- **THEN** no notification is sent

### Requirement: Popup meeting list
The popup SHALL list today's meetings latest first, show at most five rows before scrolling, grey out and strike through finished meetings, offer a one-click toggle to hide finished meetings that persists as a setting, and show the plugin version unobtrusively in its bottom-right corner.

#### Scenario: Many meetings
- **WHEN** the day has more than five meetings
- **THEN** the list is five rows tall and scrolls

#### Scenario: Finished meeting
- **WHEN** a meeting's end time has passed
- **THEN** its row is dimmed and struck through, keeping its Join button or location

#### Scenario: Cut title or location
- **WHEN** a meeting title or location is cut in the popup and the user hovers it
- **THEN** a tooltip shows the full text

#### Scenario: Hide finished
- **WHEN** the user clicks "Hide N finished"
- **THEN** finished meetings disappear from the list and stay hidden on later opens until "Show N finished" is clicked

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
