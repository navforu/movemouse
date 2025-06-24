import SwiftUI

@main
struct MoveMouseMacApp: App {
    @StateObject var mainViewModel = MainViewModel()
    @StateObject var powerSourceService = PowerSourceService() // Add PowerSourceService
    @Environment(\.scenePhase) var scenePhase

    // Delegate to handle app lifecycle events like closing the window
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Main Window
        WindowGroup {
            ContentView()
                .environmentObject(mainViewModel)
                .environmentObject(powerSourceService)
                .onAppear {
                    // Attempt to get the window reference once ContentView appears.
                    // This is a common workaround for accessing the window in SwiftUI.
                    appDelegate.window = NSApplication.shared.windows.first
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in // Corrected onChange signature
            if newPhase == .active {
                print("App became active")
            } else if newPhase == .inactive {
                print("App became inactive")
            } else if newPhase == .background {
                print("App is in background")
                // If not using MenuBarExtra and window is closed, default is to hide, not quit.
                // AppDelegate's applicationShouldTerminateAfterLastWindowClosed handles quitting.
            }
        }

        // Conditional MenuBarExtra
        // Note: The structure of the SceneBuilder requires a bit of care here.
        // We can't just conditionally add a MenuBarExtra *inside* the WindowGroup's scope
        // in the same way. It needs to be at the same level in the SceneBuilder.
        // A common pattern is to use an empty scene group if the condition is false,
        // or to always have the MenuBarExtra and control its *content* or behavior.
        // However, for full conditional presence of the MenuBarExtra itself,
        // this is the more direct SwiftUI way if supported by the current Swift version.
        // If this structure causes issues, an alternative is to always include MenuBarExtra
        // but make its content conditional or its visibility controlled differently.

        // The error "Failed to produce diagnostic" often means a compiler bug or a
        // complex type inference issue. Let's try to simplify the conditional MenuBarExtra.
        // One way is to ensure `mainViewModel.settings.minimiseToSystemTray` is accessible
        // and doesn't cause recursive issues during view building.

        // For now, let's assume the conditional MenuBarExtra is the source of the compiler confusion.
        // A slightly different way to structure this, which might be more stable for the compiler:
        // SettingsMenuBarExtra(mainViewModel: mainViewModel, showWindowAction: showWindow) // Removed this

        // --- Direct MenuBarExtra with @ViewBuilder helper ---
        MenuBarExtra(
            "MoveMouse",
            systemImage: mainViewModel.isRunning ? "cursorarrow.motionlines" : "cursorarrow.slash"
        ) {
            menuBarExtraContent()
        }
    }

    // Helper function with @ViewBuilder to provide menu content
    @ViewBuilder
    private func menuBarExtraContent() -> some View {
        if mainViewModel.settings.minimiseToSystemTray {
            Button(mainViewModel.isRunning ? "Pause" : "Start") {
                if mainViewModel.isRunning {
                    mainViewModel.pause()
                } else {
                    mainViewModel.start()
                }
            }
            Button("Show Window") {
                showWindow()
            }
            Divider()
            Button("Settings...") {
                showWindow() // Show window, then user can open settings from there
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } else {
            // If not minimizing to system tray (meaning menu bar item shouldn't really be there or be functional beyond quit)
            // Provide a minimal set of actions, or just Quit.
            // This state implies the MenuBarExtra is visible but the feature driving its full utility is off.
            Button("Enable Menu Bar mode in Settings to activate full menu") {
                showWindow() // Encourage user to open settings
            }.disabled(true) // Or make it open settings directly
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func showWindow() { // Make it private as it's a helper for this App struct
        // This brings the existing window to front or unhides it.
        // It doesn't create a new window if one doesn't exist in typical WindowGroup apps.
        if let window = NSApplication.shared.windows.first { // Assuming single window app
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true) // Bring the app to the foreground
        } else {
            // This case should ideally not happen if WindowGroup is correctly set up
            // and the app hasn't been fully terminated without a window.
            // If it can happen, you might need to re-trigger window creation logic,
            // though SwiftUI's WindowGroup usually handles this.
            print("No window found to show.")
        }
    }
}


// AppDelegate to handle window closing behavior
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // If minimiseToSystemTray is enabled, closing the window should not quit the app.
        // This requires knowing the setting. A simple way is to have MainViewModel accessible here,
        // or save this specific preference to UserDefaults directly.
        // For now, let's assume if a MenuBarExtra is active, we don't quit.

        // A better way: check the actual setting from MainViewModel.
        // This implies MainViewModel needs to be accessible, e.g., via a shared instance or passed.
        // For simplicity in this example, we'll assume a default behavior.
        // If you have a `MainViewModel` instance available (e.g. if it's an `EnvironmentObject`
        // in your App struct, you might need to pass it or its relevant state to AppDelegate).

        // Let's assume we check a simple UserDefaults flag for this behavior,
        // which `MainViewModel` would set when `minimiseToSystemTray` changes.
        if UserDefaults.standard.bool(forKey: "minimiseToSystemTrayEnabled") {
            return false // Don't quit if menu bar extra is the primary interface
        }
        return true // Default behavior: quit if last window closes
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Perform any cleanup before termination if needed
        // e.g., ensure timers are stopped, save final state.
        // MainViewModel's deinit should handle its own cleanup.
    }
}
