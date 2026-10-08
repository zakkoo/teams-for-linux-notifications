# Spec Delta

## MODIFIED Requirements

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
