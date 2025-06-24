import SwiftUI
import Combine
import CoreGraphics // For mouse control later
import AppKit // For NSApplication activation later

class MainViewModel: ObservableObject {
    @Published var settings: Settings // Remove default init here
    @Published var isRunning: Bool = false
    @Published var countdownValue: Int // Will be set from settings.delaySeconds
    @Published var statusMessage: String = "Paused"
    @Published var nextScheduledEventTime: String = "N/A"
    @Published var nextBlackoutTime: String = "N/A"

    private var mouseMoveTimer: Timer?
    private var scheduleCheckTimer: Timer? // To check for upcoming schedules/blackouts periodically
    private var lastMousePosition: NSPoint? // For auto-pause feature
    private var initialMousePositionForAutoPause: NSPoint?

    // Services (to be implemented)
    private let persistenceService = PersistenceService()
    private let mouseControlService = MouseControlService()
    private let scriptExecutionService = ScriptExecutionService()
    private let powerSourceServiceInstance = PowerSourceService() // For disableOnBattery, manage instance here
    // private let hotkeyService = HotkeyService() // For global hotkeys

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Initialize properties that don't depend on `settings` first.
        // `settings` is already initialized with `Settings.defaultSettings` at its declaration.
        // `countdownValue` needs `settings` so it must be initialized after `settings` is available.
        // However, `settings` is used by `loadSettings()` which is called, and `loadSettings()`
        // itself re-assigns `settings`.
        // The issue is using `settings.delaySeconds` before `super.init()` is implicitly called
        // or before all stored properties of this class are initialized.

        // Step 1: Initialize `countdownValue` with a default or from the initially declared `settings`.
        self.countdownValue = Settings.defaultSettings.delaySeconds // Or use self.settings.delaySeconds if allowed here.
                                                                // Let's use self.settings.delaySeconds as settings is already initialized.
        // self.countdownValue = self.settings.delaySeconds // This should be fine.

        // If the error persists with self.settings.delaySeconds, it implies `settings` itself
        // is not considered fully initialized for complex access patterns until after all other properties.
        // A safer approach is to load settings first, then initialize dependent properties.

        // Load settings first. This will assign to `self.settings`.
        // Note: `loadSettings()` as a separate method call might be tricky if it also uses `self` implicitly
        // before all properties are set. Let's inline or simplify.

        // 1. Load settings into a temporary variable first.
        let loadedSettings = persistenceService.loadSettings()

        // 2. Initialize all stored properties.
        self.settings = loadedSettings
        self.countdownValue = loadedSettings.delaySeconds
        print("MainViewModel init: Loaded settings - Delay: \(self.settings.delaySeconds), Countdown: \(self.countdownValue)") // DEBUG
        // isRunning, statusMessage, etc., already have default values or are fine.
        // mouseMoveTimer, scheduleCheckTimer, etc. are optional and initialized as nil.

        // 3. Now that `self` is fully initialized, set up Combine subscriptions.
        setupSubscribers()


        if self.settings.automaticallyStartOnLaunch { // Use self.settings here
            start()
        }

        // Periodically check for schedules and blackouts to update UI
        scheduleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNextEventDisplay()
            self?.checkSchedules() // Check schedules every second
        }

        // Ensure UserDefaults for AppDelegate is set initially
        UserDefaults.standard.set(self.settings.minimiseToSystemTray, forKey: "minimiseToSystemTrayEnabled")
    }

    private func setupSubscribers() {
        // Update countdownValue when settings.delaySeconds changes
        $settings
            .map { settings -> Int in // Explicitly show what's happening
                print("MainViewModel $settings publisher: settings.delaySeconds is \(settings.delaySeconds)") // DEBUG
                return settings.delaySeconds
            }
            .assign(to: \.countdownValue, on: self)
            .store(in: &cancellables)

        // Observe changes to minimiseToSystemTray to update UserDefaults for AppDelegate
        $settings
            .map { $0.minimiseToSystemTray }
            .sink { enabled in
                UserDefaults.standard.set(enabled, forKey: "minimiseToSystemTrayEnabled")
                // Also update the AppDelegate's knowledge if it's direct
            }
            .store(in: &cancellables)

        // Observe power source changes from our instance
        powerSourceServiceInstance.$isOnBattery
            .sink { [weak self] onBattery in
                guard let self = self else { return }
                if self.settings.disableOnBattery && onBattery && self.isRunning {
                    self.pause()
                    self.statusMessage = "Paused (On Battery)"
                } else if self.settings.disableOnBattery && !onBattery && !self.isRunning && self.statusMessage.contains("On Battery") {
                    self.statusMessage = "Paused (Plugged In)"
                }
            }
            .store(in: &cancellables)
    }


    func loadSettings() {
        // This method is now primarily for re-loading if needed,
        // initial load is handled in init.
        let loadedSettings = persistenceService.loadSettings()
        self.settings = loadedSettings
        self.countdownValue = loadedSettings.delaySeconds
        print("MainViewModel loadSettings: Reloaded settings - Delay: \(self.settings.delaySeconds), Countdown: \(self.countdownValue)") // DEBUG
        UserDefaults.standard.set(self.settings.minimiseToSystemTray, forKey: "minimiseToSystemTrayEnabled")
        // if settings.enableHotkey { hotkeyService.register(settings.hotkey) }
    }

    func saveSettings() {
        print("MainViewModel saveSettings: Current settings before save - Delay: \(settings.delaySeconds)") // DEBUG
        persistenceService.saveSettings(settings)
        UserDefaults.standard.set(settings.minimiseToSystemTray, forKey: "minimiseToSystemTrayEnabled")
        print("MainViewModel saveSettings: Settings should now be persisted.") // DEBUG
        // After saving, we might want to ensure that the MainViewModel's own `settings` published
        // property, if it was changed through a binding from SettingsView, is the source of truth
        // for its Combine publishers. The current setup where SettingsHostView updates mainViewModel.settings
        // should trigger the $settings publisher.
        // No explicit reload needed here if SettingsHostView correctly updates mainViewModel.settings.
    }

    func start() {
        print("MainViewModel start: Using delay \(settings.delaySeconds)") // DEBUG
        guard !isRunning else { return }

        if isBlackoutActive() {
            statusMessage = "Blackout Active. Paused."
            isRunning = false // Ensure it's not set to running
            return
        }

        if settings.disableOnBattery && powerSourceServiceInstance.isOnBattery {
            statusMessage = "On Battery. Paused."
            isRunning = false // Ensure it's not set to running
            return
        }

        isRunning = true
        statusMessage = "Running..."
        countdownValue = settings.delaySeconds // Explicitly set here too

        if settings.executeStartScript {
            scriptExecutionService.executeScript(type: .start, language: settings.scriptLanguage, path: nil, showExecution: settings.showScriptExecution)
        }

        // if settings.activateApplication && !settings.activateApplicationTitle.isEmpty {
        //     activateApp(named: settings.activateApplicationTitle)
        // }

        // if settings.minimiseOnStart {
        //     // Logic to minimize window - typically handled by App delegate or Scene delegate
        // }

        mouseMoveTimer?.invalidate() // Ensure no existing timer
        mouseMoveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.timerTick()
        }

        if settings.pauseWhenMouseMoved {
            initialMousePositionForAutoPause = NSEvent.mouseLocation
        }
    }

    func pause() {
        guard isRunning else { return }
        isRunning = false
        statusMessage = "Paused"
        mouseMoveTimer?.invalidate()
        mouseMoveTimer = nil
        countdownValue = settings.delaySeconds // Reset countdown for next start

        if settings.executePauseScript {
            scriptExecutionService.executeScript(type: .pause, language: settings.scriptLanguage, path: nil, showExecution: settings.showScriptExecution)
        }

        // if settings.minimiseOnPause {
        //     // Logic to minimize window
        // }
    }

    private func timerTick() {
        guard isRunning else { return }

        if isBlackoutActive() {
            statusMessage = "Blackout Active. Paused."
            // Consider temporarily pausing instead of a full stop, or re-evaluating if this should be a full pause.
            // For now, let's just reflect the status. The actual movement blocking will happen before action.
            return
        }

        // if settings.disableOnBattery && powerSourceService.isOnBattery {
        //     statusMessage = "On Battery. Paused."
        //     return
        // }

        if settings.pauseWhenMouseMoved {
            let currentMousePosition = NSEvent.mouseLocation
            if let initialPos = initialMousePositionForAutoPause, initialPos != currentMousePosition {
                // Small delay to avoid pausing from the app's own mouse move if it's very quick
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                     if self.initialMousePositionForAutoPause != NSEvent.mouseLocation {
                        self.pause()
                        self.statusMessage = "Paused (mouse moved)"
                        return
                     }
                }
            }
        }

        if countdownValue > 0 {
            countdownValue -= 1
            statusMessage = "Running... \(countdownValue)s"
        } else {
            print("MainViewModel timerTick: Performing actions with delay \(settings.delaySeconds)") // DEBUG
            performMouseActions()
            countdownValue = settings.delaySeconds
            statusMessage = "Running... \(countdownValue)s"
            if settings.executeIntervalScript {
                 scriptExecutionService.executeScript(type: .interval, language: settings.scriptLanguage, path: nil, showExecution: settings.showScriptExecution)
            }
        }
    }

    private func performMouseActions() {
        if isBlackoutActive() { // Double check before action
            statusMessage = "Blackout Active. Action skipped."
            return
        }
        // if settings.disableOnBattery && powerSourceService.isOnBattery { // Double check
        //     statusMessage = "On Battery. Action skipped."
        //     return
        // }

        if settings.moveMousePointer {
            if settings.enableStaticPosition {
                mouseControlService.moveMouse(to: CGPoint(x: settings.staticPositionX, y: settings.staticPositionY))
            } else {
                mouseControlService.moveMouseSlightly(stealth: settings.stealthMode)
            }
        }

        if settings.clickLeftMouseButton {
            mouseControlService.performLeftClick()
        }

        // if settings.sendKeystroke && !settings.keystroke.isEmpty {
        //     // To be implemented: Send keystroke
        // }

        // Update last mouse position for auto-pause detection if it's not based on initial
        // lastMousePosition = NSEvent.mouseLocation
    }

    func checkSchedules() {
        let now = Date()
        let calendar = Calendar.current
        let currentTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: now)

        for schedule in settings.schedules {
            let scheduleTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: schedule.time)
            if scheduleTimeComponents == currentTimeComponents {
                switch schedule.action {
                case .start:
                    if !isRunning { start() }
                case .pause:
                    if isRunning { pause() }
                }
            }
        }
    }

    func isBlackoutActive() -> Bool {
        let now = Date()
        let calendar = Calendar.current
        let currentTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
        guard let nowHour = currentTimeComponents.hour,
              let nowMinute = currentTimeComponents.minute,
              let nowSecond = currentTimeComponents.second else { return false }

        for blackout in settings.blackouts {
            let startTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: blackout.startTime)
            let endTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: blackout.endTime)

            guard let startHour = startTimeComponents.hour, let startMinute = startTimeComponents.minute, let startSecond = startTimeComponents.second,
                  let endHour = endTimeComponents.hour, let endMinute = endTimeComponents.minute, let endSecond = endTimeComponents.second else {
                continue
            }

            let nowTotalSeconds = nowHour * 3600 + nowMinute * 60 + nowSecond
            let startTotalSeconds = startHour * 3600 + startMinute * 60 + startSecond
            let endTotalSeconds = endHour * 3600 + endMinute * 60 + endSecond

            if startTotalSeconds <= endTotalSeconds { // Blackout does not cross midnight
                if nowTotalSeconds >= startTotalSeconds && nowTotalSeconds < endTotalSeconds {
                    return true
                }
            } else { // Blackout crosses midnight
                if nowTotalSeconds >= startTotalSeconds || nowTotalSeconds < endTotalSeconds {
                    return true
                }
            }
        }
        return false
    }

    func updateNextEventDisplay() { // Changed from private to internal (default)
        let now = Date()
        let calendar = Calendar.current
        var nextEvent: (time: Date, description: String)? = nil

        // Check schedules
        for schedule in settings.schedules where schedule.time > now {
            if nextEvent == nil || schedule.time < nextEvent!.time {
                nextEvent = (schedule.time, "Schedule: \(schedule.action.rawValue) at \(formatTime(schedule.time))")
            }
        }

        // Check blackouts (start and end times)
        for blackout in settings.blackouts {
            if blackout.startTime > now {
                if nextEvent == nil || blackout.startTime < nextEvent!.time {
                    nextEvent = (blackout.startTime, "Blackout starts at \(formatTime(blackout.startTime))")
                }
            }
            if blackout.endTime > now { // Also consider the end of a current or upcoming blackout
                 if nextEvent == nil || blackout.endTime < nextEvent!.time {
                    // Only show end time if it's truly the *next* event, or if it's an ongoing blackout
                    if isBlackoutActive() && (nextEvent == nil || blackout.endTime < nextEvent!.time) {
                         nextEvent = (blackout.endTime, "Blackout ends at \(formatTime(blackout.endTime))")
                    } else if !isBlackoutActive() && (nextEvent == nil || blackout.endTime < nextEvent!.time) {
                        // If not currently in blackout, only show end if it's earlier than a start
                         // This logic can be tricky; for now, let's simplify:
                         // if nextEvent == nil || blackout.endTime < nextEvent!.time {
                         //    nextEvent = (blackout.endTime, "Blackout period ends at \(formatTime(blackout.endTime))")
                         // }
                    }
                }
            }
        }

        if let event = nextEvent {
            // Check if this event is a blackout start/end or a schedule
            // This differentiation is already in the description.
            self.nextScheduledEventTime = event.description
        } else {
            self.nextScheduledEventTime = "N/A"
        }

        // A simpler way to show next blackout if one is upcoming or active
        let activeOrUpcomingBlackout = settings.blackouts.filter { blackout in
            let nowTotalSeconds = calendar.dateComponents([.hour, .minute, .second], from: now).totalSeconds ?? 0
            let startTotalSeconds = calendar.dateComponents([.hour, .minute, .second], from: blackout.startTime).totalSeconds ?? 0
            let endTotalSeconds = calendar.dateComponents([.hour, .minute, .second], from: blackout.endTime).totalSeconds ?? 0

            if startTotalSeconds <= endTotalSeconds {
                return (nowTotalSeconds >= startTotalSeconds && nowTotalSeconds < endTotalSeconds) || nowTotalSeconds < startTotalSeconds
            } else {
                return (nowTotalSeconds >= startTotalSeconds || nowTotalSeconds < endTotalSeconds)
            }
        }.min(by: { $0.startTime < $1.startTime })

        if let bo = activeOrUpcomingBlackout {
            if isBlackoutActive() { // Check if currently inside this specific blackout
                 if isTimeWithinBlackout(time: now, blackout: bo) {
                    self.nextBlackoutTime = "Ends at \(formatTime(bo.endTime))"
                 } else { // Or if another blackout is active, and this one is upcoming
                    self.nextBlackoutTime = "Starts at \(formatTime(bo.startTime))"
                 }
            } else {
                 self.nextBlackoutTime = "Starts at \(formatTime(bo.startTime))"
            }
        } else {
            self.nextBlackoutTime = "N/A"
        }
    }

    private func isTimeWithinBlackout(time: Date, blackout: Blackout) -> Bool {
        let calendar = Calendar.current
        let currentTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        guard let nowHour = currentTimeComponents.hour,
              let nowMinute = currentTimeComponents.minute,
              let nowSecond = currentTimeComponents.second else { return false }

        let startTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: blackout.startTime)
        let endTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: blackout.endTime)

        guard let startHour = startTimeComponents.hour, let startMinute = startTimeComponents.minute, let startSecond = startTimeComponents.second,
              let endHour = endTimeComponents.hour, let endMinute = endTimeComponents.minute, let endSecond = endTimeComponents.second else {
            return false
        }

        let nowTotalSeconds = nowHour * 3600 + nowMinute * 60 + nowSecond
        let startTotalSeconds = startHour * 3600 + startMinute * 60 + startSecond
        let endTotalSeconds = endHour * 3600 + endMinute * 60 + endSecond

        if startTotalSeconds <= endTotalSeconds {
            return nowTotalSeconds >= startTotalSeconds && nowTotalSeconds < endTotalSeconds
        } else {
            return nowTotalSeconds >= startTotalSeconds || nowTotalSeconds < endTotalSeconds
        }
    }


    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    // Placeholder for App Activation
    // func activateApp(named appName: String) {
    //     if let app = NSRunningApplication.runningApplications(withBundleIdentifier: appName).first {
    //         app.activate(options: .activateAllWindows)
    //     } else {
    //         // Try to launch if path is known or it's a common app name
    //         NSWorkspace.shared.launchApplication(appName)
    //     }
    // }

    deinit {
        mouseMoveTimer?.invalidate()
        scheduleCheckTimer?.invalidate()
    }
}

extension DateComponents {
    var totalSeconds: Int? {
        guard let hour = hour, let minute = minute, let second = second else { return nil }
        return hour * 3600 + minute * 60 + second
    }
}
