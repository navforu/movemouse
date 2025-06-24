import SwiftUI

// This acts as a bridge to pass the MainViewModel's settings to SettingsViewModel
struct SettingsHostView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        // Create SettingsViewModel here, ensuring it gets the latest settings
        // from MainViewModel and can propagate changes back.
        // This approach is simple for a sheet. For more complex scenarios,
        // you might share a single Settings object or use Combine publishers.
        let settingsViewModel = SettingsViewModel(settings: mainViewModel.settings)

        SettingsView(viewModel: settingsViewModel, onSave: { updatedSettings in
            mainViewModel.settings = updatedSettings // Update MainViewModel's settings
            mainViewModel.saveSettings() // Persist them
            mainViewModel.updateNextEventDisplay() // Refresh schedule/blackout display
            dismiss()
        }, onCancel: {
            dismiss()
        })
    }
}


struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    var onSave: (Settings) -> Void
    var onCancel: () -> Void

    @State private var selectedTab: SettingsTab = .actions

    enum SettingsTab: String, CaseIterable, Identifiable {
        case actions = "Actions"
        case behavior = "Behavior"
        case scheduling = "Scheduling"
        case blackouts = "Blackouts"
        case scripts = "Scripts"
        case advanced = "Advanced"
        var id: String { self.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Settings")
                .font(.title)
                .padding()

            Picker("Settings Tab", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.bottom)

            TabView(selection: $selectedTab) {
                ActionSettingsView(settings: $viewModel.settings)
                    .tag(SettingsTab.actions)
                BehaviorSettingsView(settings: $viewModel.settings)
                    .tag(SettingsTab.behavior)
                ScheduleSettingsView(viewModel: viewModel)
                    .tag(SettingsTab.scheduling)
                BlackoutSettingsView(viewModel: viewModel)
                    .tag(SettingsTab.blackouts)
                ScriptSettingsView(settings: $viewModel.settings, scriptViewModel: viewModel)
                    .tag(SettingsTab.scripts)
                AdvancedSettingsView(settings: $viewModel.settings)
                    .tag(SettingsTab.advanced)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // Hides default page dots for TabView

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                Spacer()
                Button("Save") {
                    onSave(viewModel.settings)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 500, idealWidth: 650, minHeight: 400, idealHeight: 550)
    }
}

// MARK: - Actions Settings
struct ActionSettingsView: View {
    @Binding var settings: Settings

    var body: some View {
        Form {
            Section(header: Text("Mouse Actions")) {
                Toggle("Move Mouse Pointer", isOn: $settings.moveMousePointer)
                if settings.moveMousePointer {
                    Toggle("Stealth Mode (no visible movement)", isOn: $settings.stealthMode)
                        .padding(.leading)
                }

                Toggle("Click Left Mouse Button", isOn: $settings.clickLeftMouseButton)
            }

            Section(header: Text("Static Position")) {
                Toggle("Enable Static Position", isOn: $settings.enableStaticPosition)
                if settings.enableStaticPosition {
                    HStack {
                        Text("X:")
                        TextField("X", value: $settings.staticPositionX, formatter: NumberFormatter())
                            .frame(maxWidth: 80)
                        Text("Y:")
                        TextField("Y", value: $settings.staticPositionY, formatter: NumberFormatter())
                            .frame(maxWidth: 80)
                        Button("Trace") {
                            // Placeholder for trace functionality
                            // This would need to communicate back to a service or view model
                            // that can monitor mouse position, perhaps via AppKit.
                            print("Trace button pressed - functionality to be implemented via AppKit.")
                            // Example: Briefly update X and Y with current mouse position
                            // This is conceptual. Direct NSEvent access isn't typical in pure SwiftUI.
                            // You'd usually call a method on a service/VM that uses AppKit.
                            // settings.staticPositionX = Int(NSEvent.mouseLocation.x)
                            // settings.staticPositionY = Int(NSScreen.main!.frame.height - NSEvent.mouseLocation.y) // Adjust for Y-coordinate system
                        }
                    }
                    .padding(.leading)
                }
            }

            Section(header: Text("Keyboard Actions")) {
                Toggle("Send Keystroke", isOn: $settings.sendKeystroke)
                if settings.sendKeystroke {
                    // Consider a dropdown for common keys or a more robust key capture
                    TextField("Keystroke (e.g., {F15})", text: $settings.keystroke)
                        .padding(.leading)
                }
            }

            Section(header: Text("Timing")) {
                 HStack {
                    Text("Seconds between actions:")
                    TextField("Delay", value: $settings.delaySeconds, formatter: NumberFormatter())
                        .frame(maxWidth: 80)
                }
            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - Behavior Settings
struct BehaviorSettingsView: View {
    @Binding var settings: Settings

    var body: some View {
        Form {
            Section(header: Text("Automatic Pausing")) {
                Toggle("Pause when mouse moved manually", isOn: $settings.pauseWhenMouseMoved)
                Toggle("Automatically resume after pause", isOn: $settings.automaticallyResume)
                if settings.automaticallyResume {
                    HStack {
                        Text("Resume after (seconds):")
                        TextField("Seconds", value: $settings.resumeSeconds, formatter: NumberFormatter())
                            .frame(maxWidth: 80)
                    }.padding(.leading)
                }
            }

            Section(header: Text("Power Management")) {
                Toggle("Disable on Battery Power", isOn: $settings.disableOnBattery)
                // Text(" (Power source detection is active)")
                //    .font(.caption)
            }

            Section(header: Text("Application Control")) {
                Toggle("Activate Specific Application", isOn: $settings.activateApplication)
                    .disabled(true) // Placeholder
                if settings.activateApplication {
                    TextField("Application Name/Title", text: $settings.activateApplicationTitle)
                        .padding(.leading)
                     Text(" (App activation - Not yet implemented)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - Schedule Settings
struct ScheduleSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var selectedSchedules = Set<Schedule.ID>()
    @State private var showingAddScheduleSheet = false
    @State private var scheduleToEdit: Schedule? = nil

    var body: some View {
        VStack {
            List(selection: $selectedSchedules) {
                ForEach(viewModel.settings.schedules) { schedule in
                    HStack {
                        Text(schedule.time, style: .time)
                        Text(schedule.action.rawValue)
                        Spacer()
                    }
                    .tag(schedule.id)
                    .onTapGesture(count: 2) {
                        scheduleToEdit = schedule
                        showingAddScheduleSheet = true
                    }
                }
                .onDelete(perform: viewModel.deleteSchedule)
            }
            .listStyle(InsetListStyle())

            HStack {
                Button {
                    scheduleToEdit = nil // Ensure it's a new schedule
                    showingAddScheduleSheet = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                }

                Button("Edit") {
                    if let firstSelectedID = selectedSchedules.first,
                       let schedule = viewModel.settings.schedules.first(where: { $0.id == firstSelectedID }) {
                        scheduleToEdit = schedule
                        showingAddScheduleSheet = true
                    }
                }
                .disabled(selectedSchedules.count != 1)

                Button("Delete") {
                    viewModel.deleteSchedules(schedules: viewModel.settings.schedules.filter { selectedSchedules.contains($0.id) })
                    selectedSchedules.removeAll()
                }
                .disabled(selectedSchedules.isEmpty)
                .tint(.red)

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingAddScheduleSheet) {
            AddEditScheduleView(
                viewModel: viewModel,
                scheduleToEdit: $scheduleToEdit,
                isPresented: $showingAddScheduleSheet
            )
        }
    }
}

struct AddEditScheduleView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var scheduleToEdit: Schedule?
    @Binding var isPresented: Bool

    @State private var time: Date
    @State private var action: Schedule.ScheduleAction

    init(viewModel: SettingsViewModel, scheduleToEdit: Binding<Schedule?>, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._scheduleToEdit = scheduleToEdit
        self._isPresented = isPresented

        if let schedule = scheduleToEdit.wrappedValue {
            _time = State(initialValue: schedule.time)
            _action = State(initialValue: schedule.action)
        } else {
            _time = State(initialValue: Date())
            _action = State(initialValue: .start)
        }
    }

    var body: some View {
        VStack {
            Text(scheduleToEdit == nil ? "Add Schedule" : "Edit Schedule")
                .font(.headline)
            Form {
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                Picker("Action", selection: $action) {
                    ForEach(Schedule.ScheduleAction.allCases, id: \.self) { actionValue in
                        Text(actionValue.rawValue).tag(actionValue)
                    }
                }
            }
            HStack {
                Button("Cancel") { isPresented = false }
                Button(scheduleToEdit == nil ? "Add" : "Save") {
                    if let schedule = scheduleToEdit {
                        viewModel.updateSchedule(schedule: schedule, newTime: time, newAction: action)
                    } else {
                        viewModel.addSchedule(time: time, action: action)
                    }
                    isPresented = false
                }
            }
            .padding()
        }
        .padding()
        .frame(minWidth: 300, minHeight: 250)
    }
}


// MARK: - Blackout Settings
struct BlackoutSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var selectedBlackouts = Set<Blackout.ID>()
    @State private var showingAddBlackoutSheet = false
    @State private var blackoutToEdit: Blackout? = nil

    var body: some View {
        VStack {
            List(selection: $selectedBlackouts) {
                ForEach(viewModel.settings.blackouts) { blackout in
                    HStack {
                        Text("From: \(blackout.startTime, style: .time)")
                        Text("To: \(blackout.endTime, style: .time)")
                        Spacer()
                    }
                    .tag(blackout.id)
                     .onTapGesture(count: 2) {
                        blackoutToEdit = blackout
                        showingAddBlackoutSheet = true
                    }
                }
                .onDelete(perform: viewModel.deleteBlackout)
            }
            .listStyle(InsetListStyle())

            HStack {
                 Button {
                    blackoutToEdit = nil // Ensure new blackout
                    showingAddBlackoutSheet = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                Button("Edit") {
                     if let firstSelectedID = selectedBlackouts.first,
                       let blackout = viewModel.settings.blackouts.first(where: { $0.id == firstSelectedID }) {
                        blackoutToEdit = blackout
                        showingAddBlackoutSheet = true
                    }
                }
                .disabled(selectedBlackouts.count != 1)

                Button("Delete") {
                    viewModel.deleteBlackouts(blackouts: viewModel.settings.blackouts.filter { selectedBlackouts.contains($0.id) })
                    selectedBlackouts.removeAll()
                }
                .disabled(selectedBlackouts.isEmpty)
                .tint(.red)
                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingAddBlackoutSheet) {
            AddEditBlackoutView(
                viewModel: viewModel,
                blackoutToEdit: $blackoutToEdit,
                isPresented: $showingAddBlackoutSheet
            )
        }
    }
}

struct AddEditBlackoutView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var blackoutToEdit: Blackout?
    @Binding var isPresented: Bool

    @State private var startTime: Date
    @State private var endTime: Date
    @State private var showErrorAlert = false

    init(viewModel: SettingsViewModel, blackoutToEdit: Binding<Blackout?>, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._blackoutToEdit = blackoutToEdit
        self._isPresented = isPresented

        if let blackout = blackoutToEdit.wrappedValue {
            _startTime = State(initialValue: blackout.startTime)
            _endTime = State(initialValue: blackout.endTime)
        } else {
            // Default new blackout to sensible times, e.g., current time and one hour later
            let now = Date()
            _startTime = State(initialValue: now)
            _endTime = State(initialValue: Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now)
        }
    }

    var body: some View {
        VStack {
            Text(blackoutToEdit == nil ? "Add Blackout" : "Edit Blackout")
                .font(.headline)
            Form {
                DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
            }
            HStack {
                Button("Cancel") { isPresented = false }
                Button(blackoutToEdit == nil ? "Add" : "Save") {
                    if startTime >= endTime {
                        showErrorAlert = true
                    } else {
                        if let blackout = blackoutToEdit {
                            viewModel.updateBlackout(blackout: blackout, newStartTime: startTime, newEndTime: endTime)
                        } else {
                            viewModel.addBlackout(startTime: startTime, endTime: endTime)
                        }
                        isPresented = false
                    }
                }
            }
            .padding()
        }
        .padding()
        .frame(minWidth: 300, minHeight: 250)
        .alert("Invalid Time Range", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Blackout start time must be before the end time.")
        }
    }
}


// MARK: - Script Settings
struct ScriptSettingsView: View {
    @Binding var settings: Settings
    @ObservedObject var scriptViewModel: SettingsViewModel // For file dialog

    // Consider making scriptLanguage an enum for type safety
    let scriptLanguages = ["AppleScript", "Shell Script"] // Example languages

    var body: some View {
        Form {
            Section(header: Text("Script Execution")) {
                Toggle("Execute script on start", isOn: $settings.executeStartScript)
                Toggle("Execute script on interval", isOn: $settings.executeIntervalScript)
                Toggle("Execute script on pause", isOn: $settings.executePauseScript)
            }

            Section(header: Text("Script Configuration")) {
                Toggle("Show script execution window", isOn: $settings.showScriptExecution)

                Picker("Script Language", selection: $settings.scriptLanguage) {
                    ForEach(scriptLanguages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
            }

            Section(header: Text("Edit Scripts")) {
                HStack {
                    Button("Edit Start Script") { scriptViewModel.editScript(type: .start) }
                        .disabled(!settings.executeStartScript)
                    Spacer()
                    Button("Edit Interval Script") { scriptViewModel.editScript(type: .interval) }
                        .disabled(!settings.executeIntervalScript)
                    Spacer()
                    Button("Edit Pause Script") { scriptViewModel.editScript(type: .pause) }
                        .disabled(!settings.executePauseScript)
                }
                Text("Scripts are stored in Application Support and will be created if they don't exist.")
                    .font(.caption)
            }

            Section(header: Text("Script Editor")) {
                HStack {
                    Text("Editor:")
                    TextField("Path to Script Editor", text: $settings.scriptEditorPath)
                        .truncationMode(.head)
                    Button("Browse...") {
                        scriptViewModel.selectScriptEditor()
                    }
                }
                Text("Current: \(settings.scriptEditorPath)")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)

            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - Advanced Settings
struct AdvancedSettingsView: View {
    @Binding var settings: Settings

    var body: some View {
        Form {
            Section(header: Text("Startup & System Tray")) {
                Toggle("Automatically start on application launch", isOn: $settings.automaticallyStartOnLaunch)
                Toggle("Automatically launch on logon", isOn: $settings.automaticallyLaunchOnLogon)
                    .disabled(true) // Placeholder: Requires LaunchAgent setup
                 Text(" (Requires LaunchAgent setup - Not yet implemented)")
                    .font(.caption)
                    .foregroundColor(.gray)


                Toggle("Minimise on pause", isOn: $settings.minimiseOnPause)
                Toggle("Minimise on start", isOn: $settings.minimiseOnStart)
                Toggle("Minimise to Menu Bar (System Tray)", isOn: $settings.minimiseToSystemTray)
                // Text(" (App will show in menu bar when active)")
                //    .font(.caption)
            }

            // Add other "advanced" or less frequently used settings here.
            // For example, hotkey configuration if it's complex.
            Section(header: Text("Global Hotkey")) {
                Toggle("Enable Global Hotkey to Start/Pause", isOn: $settings.enableHotkey)
                    .disabled(true) // Placeholder
                if settings.enableHotkey {
                    TextField("Hotkey (e.g. Cmd+Shift+M)", text: $settings.hotkey)
                        .padding(.leading)
                        .disabled(true)
                }
                Text(" (Global hotkey monitoring - Not yet implemented)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }


            Spacer()
        }
        .padding()
    }
}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock SettingsViewModel for preview
        let mockSettings = Settings.defaultSettings
        let mockSettingsViewModel = SettingsViewModel(settings: mockSettings)

        SettingsView(viewModel: mockSettingsViewModel, onSave: { _ in }, onCancel: { })
            .environmentObject(MainViewModel()) // For SettingsHostView if testing that
    }
}
