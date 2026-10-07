pragma Singleton
import QtQml

// Lets every per-monitor widget instance reach the one shell-owned service
// without asking the host for another plugin's service.
QtObject {
  property QtObject instance: null
}
