# Spec Delta

## MODIFIED Requirements

### Requirement: Settings editable in the popup
The popup SHALL offer controls for every setting (horizon, poll interval, reminder card on/off, reminder lead time, MQTT port, MQTT prefix) and persist changes to the widget's shell.json entry, so the shell's settings form is never required. The reminder controls SHALL describe a reminder card with Join, Remind-me and Dismiss buttons, not a desktop notification.

#### Scenario: Change horizon in the popup
- **WHEN** the user sets the horizon control to 60 in the popup
- **THEN** shell.json holds horizonMinutes 60 for the widget and the bar reflects it

#### Scenario: Reminder wording
- **WHEN** the user opens the settings section of the popup or the shell's settings form
- **THEN** the `toast` and `leadMinutes` controls are labelled as the reminder card and its lead time
