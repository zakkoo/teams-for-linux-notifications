pragma Singleton
import QtQml

// Lets every per-monitor widget instance reach the one shell-owned service
// without asking the host for another plugin's service.
QtObject {
  property QtObject instance: null
  // Setting defaults, mirrored from manifest.json "barWidget.defaults" (the structure test keeps them equal).
  // Every setting(...) fallback in the widget and popup reads from here, nowhere else.
  readonly property var defaults: ({
    horizonMinutes: 15, leadMinutes: 2, pollMinutes: 5, toast: false,
    mqttPort: 1883, mqttPrefix: "teams", hidePast: false, scroll: "Always", scrollTimes: 3
  })
}
