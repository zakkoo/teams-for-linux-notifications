# Spec Delta

## MODIFIED Requirements

### Requirement: Bridge lifecycle follows the shell
The MQTT bridge SHALL start when the widget loads, be restarted if it exits, and stop when the widget unloads. No separate service or unit SHALL be required. The bridge SHALL survive a misbehaving client: a packet it cannot parse SHALL drop that client only, and a client that sends nothing for one and a half times its declared keepalive SHALL be dropped as disconnected, so a Teams that died without closing its socket cannot wedge the bridge. Calendar polling SHALL continue across client drops and reconnects for the life of the bridge process. A bridge restart that the widget itself triggers (after a settings change) SHALL NOT be reported as an error.

#### Scenario: Shell starts
- **WHEN** the shell loads the widget
- **THEN** a bridge listens on 127.0.0.1 at the configured port within 2 seconds

#### Scenario: Bridge crashes
- **WHEN** the bridge process exits unexpectedly
- **THEN** it is restarted after a short delay and the widget shows "disconnected" meanwhile

#### Scenario: Plugin disabled
- **WHEN** the widget is removed from the bar
- **THEN** the bridge process exits

#### Scenario: Malformed packet
- **WHEN** a connected client sends a packet with a truncated string or an undecodable topic
- **THEN** that client is dropped and connected becomes false, the bridge process keeps running, and the next client is served normally

#### Scenario: Client goes silent
- **WHEN** Teams connected with a keepalive of 60 seconds and then stops sending anything, including pings, without closing the socket
- **THEN** within 90 seconds connected becomes false and a new Teams connection is accepted and served

#### Scenario: Poll outlives a disconnect
- **WHEN** Teams disconnects at the moment a poll is due and reconnects later
- **THEN** the periodic get-calendar command resumes on the new connection without a bridge restart

#### Scenario: Settings change restarts the bridge quietly
- **WHEN** the user changes the poll interval, port or prefix
- **THEN** the bridge restarts with the new arguments and the status text never shows a "bridge exited" error for that restart
