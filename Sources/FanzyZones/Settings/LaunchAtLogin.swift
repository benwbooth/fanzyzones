import ServiceManagement

/// Thin wrapper over `SMAppService` for the "launch at login" toggle.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("FanzyZones: launch-at-login \(enabled ? "register" : "unregister") failed: \(error)")
        }
    }
}
