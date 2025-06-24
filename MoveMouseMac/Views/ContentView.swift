import SwiftUI

struct ContentView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 15) {
            Text("MoveMouse for macOS")
                .font(.largeTitle)
                .padding(.top)

            StatusView()
                .environmentObject(mainViewModel)

            ControlButtonsView()
                .environmentObject(mainViewModel)

            ScheduleBlackoutSummaryView()
                .environmentObject(mainViewModel)

            Spacer()

            Button {
                showingSettings.toggle()
            } label: {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .sheet(isPresented: $showingSettings) {
                SettingsHostView()
                    .environmentObject(mainViewModel) // Pass MainViewModel
            }
            .padding(.bottom)
        }
        .frame(minWidth: 400, idealWidth: 500, minHeight: 350, idealHeight: 450)
        .onAppear {
            // Perform any initial setup if needed when the view appears
            // For example, trigger an initial load or check of schedules if not done in ViewModel's init
             mainViewModel.updateNextEventDisplay() // Ensure it's up-to-date on appear
        }
    }
}

struct StatusView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        VStack {
            Text(mainViewModel.statusMessage)
                .font(.title2)
                .foregroundColor(mainViewModel.isRunning ? .green : .orange)

            if mainViewModel.isRunning {
                ProgressView(value: Double(mainViewModel.settings.delaySeconds - mainViewModel.countdownValue),
                             total: Double(mainViewModel.settings.delaySeconds))
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 200)
                Text("Next action in: \(mainViewModel.countdownValue)s")
            } else if mainViewModel.statusMessage.contains("Blackout") || mainViewModel.statusMessage.contains("Battery") {
                 // Don't show countdown if paused due to blackout/battery
            }
            else {
                Text("Paused") // Generic paused state
            }
        }
        .padding()
    }
}

struct ControlButtonsView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        HStack(spacing: 20) {
            Button {
                if mainViewModel.isRunning {
                    mainViewModel.pause()
                } else {
                    mainViewModel.start()
                }
            } label: {
                Label(mainViewModel.isRunning ? "Pause" : "Start",
                      systemImage: mainViewModel.isRunning ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .controlSize(.large)
            .tint(mainViewModel.isRunning ? .orange : .green)
            .keyboardShortcut(.defaultAction) // Allows Enter/Space to trigger

            // Potentially add a "Stop" button if different from Pause,
            // or other primary controls.
        }
    }
}

struct ScheduleBlackoutSummaryView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Upcoming Events:")
                .font(.headline)
            Text("Next Schedule: \(mainViewModel.nextScheduledEventTime)")
            Text("Next Blackout: \(mainViewModel.nextBlackoutTime)")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading) // Ensure it takes available width
        .background(Color(NSColor.windowBackgroundColor)) // Use system background color
        .cornerRadius(8)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

// Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock MainViewModel for previewing purposes
        let mockViewModel = MainViewModel()
        // Optionally configure the mockViewModel for different states
        // mockViewModel.isRunning = true
        // mockViewModel.statusMessage = "Running... 25s"
        // mockViewModel.countdownValue = 25
        // mockViewModel.settings.delaySeconds = 30

        ContentView()
            .environmentObject(mockViewModel)
    }
}
