# Spec Delta

## MODIFIED Requirements

### Requirement: Popup meeting list
The popup SHALL list today's meetings with the meetings still to come first, nearest start at the top, followed by finished meetings, most recently ended first. It SHALL show at most five rows before scrolling, grey out and strike through finished meetings, offer a one-click toggle to hide finished meetings that persists as a setting, and show the plugin version unobtrusively in its bottom-right corner.

#### Scenario: Order
- **WHEN** today has meetings at 09:00 and 10:00 (finished), one running since 10:50, and more at 11:30 and 14:00, and it is 11:00
- **THEN** the list reads 10:50, 11:30, 14:00, then 10:00, then 09:00

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

## REMOVED Requirements

### Requirement: Optional toast
**Reason**: Replaced by the reminder card. The Omarchy notification daemon renders no action buttons and always dismisses on click, so a desktop notification cannot offer snooze, dismiss and join. The subject restriction existed only because the notification transport exposed its argv to other local users; the card is drawn in-process and has no argv.
**Migration**: The `toast` setting keeps its key and now enables the reminder card. Users who had the toast on get the card with no action needed.

## ADDED Requirements

### Requirement: Reminder card
When the reminder setting is enabled, the widget SHALL show a reminder card as an overlay on the focused screen for the shown meeting when the time to its start is at most the lead time, or when it enters the "now" state. The card SHALL show the meeting subject and the time to start (or "now"). The card SHALL offer a Join button when the meeting has a join link, a Dismiss button, and a Remind-me button while the meeting has not started and more than one minute remains. The card SHALL stay until one of its buttons is pressed, the meeting is dismissed elsewhere, the user is in a call, or the meeting ends. Clicking the card anywhere outside its buttons SHALL do nothing. At most one card SHALL be shown at a time.

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
- **WHEN** the card is showing and Teams reports an active call
- **THEN** the card closes

#### Scenario: Reminder disabled (default)
- **WHEN** the reminder is off and a meeting reaches the lead time or starts
- **THEN** no card is shown

### Requirement: Reminder card buttons
Join SHALL hand the meeting's link to Teams for Linux (with the same fallback as the widget's right-click) and close the card. Dismiss SHALL close the card and dismiss the meeting exactly as a middle-click on the widget does. Remind-me SHALL close the card and show it again after half the remaining time to the start, rounded down to whole minutes and never less than one; the button label SHALL state that number of minutes. Each time the card reappears, the countdown and the Remind-me interval SHALL be recomputed from the then-remaining time.

#### Scenario: Halving snooze chain
- **WHEN** the card says "in 15 min" and the user presses "Remind me in 7 min"
- **THEN** the card closes, reappears with about 8 minutes left reading "in 8 min", and its button now says "Remind me in 4 min"

#### Scenario: Snooze floor
- **WHEN** the card reappears with 2 minutes left
- **THEN** the button says "Remind me in 1 min"; with 1 minute or less left the button is not offered

#### Scenario: Dismiss
- **WHEN** the user presses Dismiss on the card for "Standup"
- **THEN** the card closes, the bar no longer shows "Standup", and no further card is shown for it

#### Scenario: Join
- **WHEN** the user presses Join
- **THEN** the link is handed to Teams for Linux, not the browser, and the card closes

#### Scenario: Snoozed meeting reaches its start
- **WHEN** the card is snoozed and the meeting starts before the snooze elapses
- **THEN** the card reappears at the start in the "now" form
