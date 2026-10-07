# Spec Delta

## Purpose

Receives calendar and meeting signals from Teams for Linux through an embedded MQTT bridge and lets the user wire Teams to it from the plugin itself.

## ADDED Requirements

### Requirement: Bridge lifecycle follows the shell
The MQTT bridge SHALL start when the widget loads, be restarted if it exits, and stop when the widget unloads. No separate service or unit SHALL be required.

#### Scenario: Shell starts
- **WHEN** the shell loads the widget
- **THEN** a bridge listens on 127.0.0.1 at the configured port within 2 seconds

#### Scenario: Bridge crashes
- **WHEN** the bridge process exits unexpectedly
- **THEN** it is restarted after a short delay and the widget shows "disconnected" meanwhile

#### Scenario: Plugin disabled
- **WHEN** the widget is removed from the bar
- **THEN** the bridge process exits

### Requirement: Calendar polling
The bridge SHALL request today's calendar when Teams subscribes and every poll interval thereafter, and SHALL expose the parsed events (id, subject, start, end, join URL) to the widget.

#### Scenario: Teams connects
- **WHEN** Teams subscribes to the command topic
- **THEN** a get-calendar command for today is sent immediately

#### Scenario: Periodic refresh
- **WHEN** the poll interval elapses
- **THEN** a new get-calendar command is sent

#### Scenario: Cancelled and all-day events
- **WHEN** the calendar contains cancelled or all-day events
- **THEN** they are not exposed to the widget

### Requirement: Connection state
The bridge SHALL expose whether Teams is connected and whether the user is in a call, derived from Teams' connected and in-call topics.

#### Scenario: Teams closes
- **WHEN** Teams disconnects or its last-will message arrives
- **THEN** connected becomes false within 10 seconds

### Requirement: Connect Teams for Linux
The popup SHALL offer a "Connect Teams for Linux" action that adds the MQTT, Graph API and meeting-start-detection settings to Teams' user config.json without altering other keys, keeps a backup, and tells the user to restart Teams.

#### Scenario: Fresh Teams config
- **WHEN** config.json does not exist and the user clicks Connect
- **THEN** config.json is created with only the required keys

#### Scenario: Existing Teams config
- **WHEN** config.json contains unrelated keys and the user clicks Connect
- **THEN** those keys are unchanged, the required keys are set, and a timestamped backup exists

#### Scenario: Already connected
- **WHEN** the required keys are present
- **THEN** the popup shows Disconnect instead of Connect

### Requirement: Disconnect Teams for Linux
The popup SHALL offer a "Disconnect" action that removes exactly the keys added by Connect.

#### Scenario: Disconnect
- **WHEN** the user clicks Disconnect
- **THEN** mqtt, graphApi and meetingStartDetection keys added by Connect are removed and other keys remain
