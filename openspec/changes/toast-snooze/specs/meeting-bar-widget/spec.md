# Spec Delta

## MODIFIED Requirements

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

## REMOVED Requirements

### Requirement: Optional toast
**Reason**: Replaced by the reminder card. The Omarchy notification daemon renders no action buttons and always dismisses on click, so a desktop notification cannot offer snooze, dismiss and join. The subject restriction existed only because the notification transport exposed its argv to other local users; the card is drawn in-process and has no argv.
**Migration**: The `toast` setting keeps its key and now enables the reminder card. Users who had the toast on get the card with no action needed.

## ADDED Requirements

### Requirement: Reminder card
When the reminder setting is enabled, the widget SHALL show a reminder card as an overlay on the focused screen for every meeting whose time to start is at most the lead time or that is in the "now" state, each meeting judged on its own. Cards SHALL stack soonest-start first, at most three at a time; a further due meeting SHALL get a card as soon as one of the three is gone. A card SHALL show the meeting subject and the time to start (or "now"). It SHALL offer a Join button when the meeting has a join link, a Dismiss button, and a Remind-me button while the meeting has not started and more than one minute remains. A card SHALL stay until one of its buttons is pressed, its meeting is dismissed elsewhere, the user is in that meeting's call, or its meeting ends. Being in a call exempts only the meeting the call belongs to; other meetings still get their cards. Clicking a card anywhere outside its buttons SHALL do nothing. The lead time SHALL be capped at the horizon, since a meeting outside the horizon is never shown.

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

### Requirement: Reminder card buttons
Join SHALL hand the meeting's link to Teams for Linux (with the same fallback as the widget's right-click) and close the card for good. Dismiss on a card before the start SHALL close that card only; the meeting SHALL still get its card at the start. Dismiss on a started meeting's card SHALL skip the meeting exactly as a middle-click on the widget does. A skipped meeting SHALL appear dimmed in the popup with a one-click restore. Once the user has been in a meeting's call and left it, that meeting SHALL count as handled: no card returns and the bar does not turn urgent for it. Remind-me SHALL close the card and show it again after half the remaining time to the start, rounded down to whole minutes and never less than one; the button label SHALL state that number of minutes. Each time the card reappears, the countdown and the Remind-me interval SHALL be recomputed from the then-remaining time.

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

#### Scenario: Join
- **WHEN** the user presses Join
- **THEN** the link is handed to Teams for Linux, not the browser, and the card closes

#### Scenario: Snoozed meeting reaches its start
- **WHEN** the card is snoozed and the meeting starts before the snooze elapses
- **THEN** the card reappears at the start in the "now" form
