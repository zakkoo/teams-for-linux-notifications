# Spec Delta

## MODIFIED Requirements

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

## RENAMED Requirements

- FROM: `### Requirement: Hidden without Teams`
- TO: `### Requirement: Always visible, dimmed without Teams`

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
