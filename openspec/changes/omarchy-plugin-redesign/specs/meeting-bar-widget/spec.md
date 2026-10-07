# Spec Delta

## Purpose

Shows the user's next Teams meeting and an in-progress meeting directly in the Omarchy bar, without popups, so they can see what is coming without clicking anything.

## ADDED Requirements

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
The widget SHALL switch to an urgent "now" style for an event that has started and the user has not joined, and SHALL keep it until the user is in a call, the event ends, or the user dismisses it.

#### Scenario: Start time reached
- **WHEN** the current time passes an event's start and Teams reports no active call
- **THEN** the bar shows "<subject> · now" in the bar's urgent colour

#### Scenario: Teams reports the meeting started early
- **WHEN** Teams publishes a meeting-started pulse and an event starts within 5 minutes
- **THEN** that event is shown in the "now" style immediately

#### Scenario: User joins
- **WHEN** Teams reports an active call
- **THEN** the "now" label disappears

#### Scenario: Pulse without a matching event
- **WHEN** a meeting-started pulse arrives and no event starts within 5 minutes
- **THEN** the bar shows "Meeting started" without a join action until an active call is reported or 10 minutes pass

### Requirement: Click opens the meeting
Left-clicking the widget SHALL open the shown event's join URL with the system URL handler, or the popup when no URL is known.

#### Scenario: Event has a join URL
- **WHEN** the shown event has a Teams join link and the user left-clicks
- **THEN** the link is opened with xdg-open

#### Scenario: Right-click
- **WHEN** the user right-clicks the widget
- **THEN** the popup with today's events and the connection controls opens

### Requirement: Hidden without Teams
The widget SHALL occupy no space while Teams for Linux is not connected to the bridge, except while Teams has not yet been configured to connect, when it SHALL show only a dimmed icon so the Connect action stays reachable.

#### Scenario: Setup needed
- **WHEN** Teams for Linux's config does not contain the plugin's MQTT keys
- **THEN** the bar shows a dimmed icon with no text, and clicking it opens the popup

#### Scenario: Teams quits
- **WHEN** Teams for Linux disconnects
- **THEN** the widget disappears within 10 seconds, regardless of pending events

### Requirement: Optional toast
When the toast setting is enabled, the widget SHALL send one desktop notification per meeting on the transition into the "now" state, and none otherwise.

#### Scenario: Toast enabled
- **WHEN** toast is on and an event enters the "now" state
- **THEN** exactly one notification with the subject is sent

#### Scenario: Toast disabled (default)
- **WHEN** toast is off and an event enters the "now" state
- **THEN** no notification is sent

### Requirement: Long titles
Titles wider than the label area SHALL scroll horizontally rather than widen the bar.

#### Scenario: Long subject
- **WHEN** the subject is longer than the label area
- **THEN** the label width is capped and the text scrolls
