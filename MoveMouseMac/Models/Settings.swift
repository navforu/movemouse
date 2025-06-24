import Foundation

struct Settings: Codable {
    var delaySeconds: Int = 30
    var moveMousePointer: Bool = true
    var stealthMode: Bool = false
    var enableStaticPosition: Bool = false
    var staticPositionX: Int = 0
    var staticPositionY: Int = 0
    var clickLeftMouseButton: Bool = false
    var sendKeystroke: Bool = false
    var keystroke: String = "" // Consider an enum or more structured type
    var pauseWhenMouseMoved: Bool = false
    var automaticallyResume: Bool = false
    var resumeSeconds: Int = 60
    var disableOnBattery: Bool = false // May require platform-specific power source detection
    var enableHotkey: Bool = false // Requires event monitoring
    var hotkey: String = "" // Consider a more structured type for key combinations
    var automaticallyStartOnLaunch: Bool = false
    var automaticallyLaunchOnLogon: Bool = false // Requires LaunchAgent/Service configuration
    var minimiseOnPause: Bool = false
    var minimiseOnStart: Bool = false
    var minimiseToSystemTray: Bool = false // macOS equivalent is a MenuBarExtra
    var activateApplication: Bool = false
    var activateApplicationTitle: String = "" // May need AppKit for window/app activation

    var executeStartScript: Bool = false
    var executeIntervalScript: Bool = false
    var executePauseScript: Bool = false
    var showScriptExecution: Bool = false
    var scriptLanguage: String = "AppleScript" // Default to AppleScript, could be enum
    var scriptEditorPath: String = "/System/Applications/Utilities/Script Editor.app"

    var schedules: [Schedule] = []
    var blackouts: [Blackout] = []

    // Add more properties as needed based on the original app's settings

    static let defaultSettings = Settings()
}

struct Schedule: Codable, Identifiable, Hashable {
    var id = UUID()
    var time: Date // Using Date for time components (hour, minute, second)
    var action: ScheduleAction = .start

    enum ScheduleAction: String, Codable, CaseIterable {
        case start = "Start"
        case pause = "Pause"
    }

    // Helper to get just the time components for comparison
    var timeComponents: DateComponents {
        Calendar.current.dateComponents([.hour, .minute, .second], from: time)
    }
}

struct Blackout: Codable, Identifiable, Hashable {
    var id = UUID()
    var startTime: Date // Using Date for time components
    var endTime: Date   // Using Date for time components

    // Helper to get just the time components for comparison
    var startTimeComponents: DateComponents {
        Calendar.current.dateComponents([.hour, .minute, .second], from: startTime)
    }
    var endTimeComponents: DateComponents {
        Calendar.current.dateComponents([.hour, .minute, .second], from: endTime)
    }
}
