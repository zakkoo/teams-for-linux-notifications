# Spec Delta

## Purpose

Every tunable of the plugin is exposed through the Omarchy shell's settings form so the user never edits a JSON file.

## ADDED Requirements

### Requirement: Settings declared in the manifest
The plugin manifest SHALL declare these settings with defaults and bounds: leadMinutes (2, 0-60), horizonMinutes (15, 1-240), pollMinutes (5, 1-60), toast (false), mqttPort (1883, 1024-65535), mqttPrefix ("teams").

#### Scenario: Fresh install
- **WHEN** the plugin is enabled without any configuration
- **THEN** it behaves with the defaults above

#### Scenario: Validation
- **WHEN** `omarchy plugin validate` runs on the repository
- **THEN** it reports the manifest as valid

### Requirement: Settings editable in the popup
The popup SHALL offer controls for every setting (horizon, poll interval, toast on/off, toast lead time, MQTT port, MQTT prefix) and persist changes to the widget's shell.json entry, so the shell's settings form is never required.

#### Scenario: Change horizon in the popup
- **WHEN** the user sets the horizon control to 60 in the popup
- **THEN** shell.json holds horizonMinutes 60 for the widget and the bar reflects it

### Requirement: Settings apply live
Changing leadMinutes, horizonMinutes or toast SHALL take effect without restarting the shell or Teams; changing pollMinutes, mqttPort or mqttPrefix SHALL restart the bridge automatically.

#### Scenario: Horizon changed
- **WHEN** the user raises horizonMinutes from 15 to 60 and an event starts in 40 minutes
- **THEN** the event appears in the bar within 15 seconds

#### Scenario: Port changed
- **WHEN** the user changes mqttPort
- **THEN** the bridge listens on the new port and the popup reminds the user to Connect again

### Requirement: Placement is the shell's
The widget SHALL default to the center section and SHALL be movable with the standard bar gestures and `omarchy bar move`.

#### Scenario: Move to right
- **WHEN** the user runs `omarchy bar move io.github.zakkoo.teams-for-linux-notifications --section right`
- **THEN** the widget renders in the right section
