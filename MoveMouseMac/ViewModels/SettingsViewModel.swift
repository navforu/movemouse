import SwiftUI
import Combine

class SettingsViewModel: ObservableObject {
    @Published var settings: Settings
    private var persistenceService = PersistenceService()
    private var cancellables = Set<AnyCancellable>()

    // Temporary states for editing schedules and blackouts if needed for modal presentation
    @Published var isEditingSchedule: Bool = false
    @Published var currentEditingSchedule: Schedule = Schedule(time: Date())
    @Published var isEditingBlackout: Bool = false
    @Published var currentEditingBlackout: Blackout = Blackout(startTime: Date(), endTime: Date())


    init(settings: Settings) {
        self.settings = settings
        // Propagate changes from this ViewModel's settings back to a shared source if necessary,
        // or ensure this ViewModel is the single source of truth during settings editing.
    }

    func saveSettings() {
        persistenceService.saveSettings(settings)
        // Potentially notify MainViewModel to reload settings if they are not directly bound
    }

    // MARK: - Schedule Management
    func addSchedule(time: Date, action: Schedule.ScheduleAction) {
        let newSchedule = Schedule(time: time, action: action)
        settings.schedules.append(newSchedule)
        sortSchedules()
    }

    func updateSchedule(schedule: Schedule, newTime: Date, newAction: Schedule.ScheduleAction) {
        if let index = settings.schedules.firstIndex(where: { $0.id == schedule.id }) {
            settings.schedules[index].time = newTime
            settings.schedules[index].action = newAction
            sortSchedules()
        }
    }

    func deleteSchedule(at offsets: IndexSet) {
        settings.schedules.remove(atOffsets: offsets)
    }

    func deleteSchedules(schedules: [Schedule]) {
        for schedule in schedules {
            if let index = settings.schedules.firstIndex(where: { $0.id == schedule.id }) {
                settings.schedules.remove(at: index)
            }
        }
    }

    private func sortSchedules() {
        settings.schedules.sort { $0.time < $1.time }
    }

    // MARK: - Blackout Management
    func addBlackout(startTime: Date, endTime: Date) {
        guard startTime < endTime else {
            // Optionally show an alert to the user
            print("Error: Blackout start time must be before end time.")
            return
        }
        let newBlackout = Blackout(startTime: startTime, endTime: endTime)
        settings.blackouts.append(newBlackout)
        sortBlackouts()
    }

    func updateBlackout(blackout: Blackout, newStartTime: Date, newEndTime: Date) {
        guard newStartTime < newEndTime else {
            print("Error: Blackout start time must be before end time.")
            return
        }
        if let index = settings.blackouts.firstIndex(where: { $0.id == blackout.id }) {
            settings.blackouts[index].startTime = newStartTime
            settings.blackouts[index].endTime = newEndTime
            sortBlackouts()
        }
    }

    func deleteBlackout(at offsets: IndexSet) {
        settings.blackouts.remove(atOffsets: offsets)
    }

    func deleteBlackouts(blackouts: [Blackout]) {
        for blackout in blackouts {
            if let index = settings.blackouts.firstIndex(where: { $0.id == blackout.id }) {
                settings.blackouts.remove(at: index)
            }
        }
    }

    private func sortBlackouts() {
        settings.blackouts.sort { $0.startTime < $1.startTime }
    }

    // MARK: - Script Editor Path
    func selectScriptEditor() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.application] // For .app bundles

        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                settings.scriptEditorPath = url.path
            }
        }
    }

    // MARK: - Script Management
    func editScript(type: ScriptType) {
        // This function will call the ScriptExecutionService to create (if needed) and open the script.
        // The actual path construction and editor opening is handled by the service.
        let service = ScriptExecutionService()
        _ = service.createEmptyScriptIfNeeded(type: type, language: settings.scriptLanguage, scriptEditorPath: settings.scriptEditorPath)
    }
}
