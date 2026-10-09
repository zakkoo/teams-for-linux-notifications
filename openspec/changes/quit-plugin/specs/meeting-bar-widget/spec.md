# Spec Delta

## ADDED Requirements

### Requirement: Quit the plugin
The settings section of the popup SHALL offer a "Quit plugin" action. After the user confirms it once in the popup, the action SHALL disable this plugin so the widget leaves the bar and stays gone until the user enables it again. The confirmation SHALL name `omarchy plugin enable io.github.zakkoo.teams-for-linux-notifications`. Quit SHALL NOT uninstall the plugin files.

#### Scenario: Confirmation before quitting
- **WHEN** the user opens the settings section and activates "Quit plugin" once
- **THEN** the widget stays on the bar and the popup asks them to confirm, naming `omarchy plugin enable io.github.zakkoo.teams-for-linux-notifications`

#### Scenario: Closing the popup drops the confirmation
- **WHEN** the user activates "Quit plugin" once and then closes the popup
- **THEN** the plugin stays enabled, and opening the popup again shows "Quit plugin" waiting for a first activation

#### Scenario: Confirmed quit
- **WHEN** the user confirms "Quit plugin"
- **THEN** the widget leaves the bar on every monitor, any reminder card disappears, and both are still gone after the shell restarts

#### Scenario: Quit fails
- **WHEN** the user confirms "Quit plugin" and the plugin is not disabled
- **THEN** the widget stays on the bar and the popup says that quitting failed

#### Scenario: Enable again uses defaults
- **WHEN** the user had set the horizon to 60, confirms "Quit plugin", and then enables the plugin again
- **THEN** the widget returns to the bar with the manifest defaults, including a horizon of 15 minutes

#### Scenario: Disconnect is not quit
- **WHEN** the user activates "Disconnect Teams for Linux"
- **THEN** the widget stays on the bar
