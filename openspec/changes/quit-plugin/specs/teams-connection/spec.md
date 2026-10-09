# Spec Delta

## ADDED Requirements

### Requirement: Disabling the plugin stops the bridge
Disabling the plugin SHALL stop the bridge process and SHALL NOT start another until the plugin is enabled again. Disabling SHALL NOT add, remove, or change keys in the Teams for Linux config.

#### Scenario: Confirmed quit
- **WHEN** the user confirms "Quit plugin"
- **THEN** the bridge process exits, and ten seconds later no bridge process for this plugin is running

#### Scenario: Removed from the bar
- **WHEN** the widget is removed from the bar with `omarchy plugin disable`
- **THEN** the bridge process exits and is not started again while the plugin stays disabled

#### Scenario: Teams config is left alone
- **WHEN** the user confirms "Quit plugin" and the Teams for Linux config contains the keys added by Connect plus an unrelated key
- **THEN** those keys are unchanged and this action writes no backup

#### Scenario: A crash while enabled still restarts
- **WHEN** the plugin is enabled and the bridge process exits unexpectedly
- **THEN** the bridge is restarted after a short delay and the widget shows "disconnected" meanwhile
