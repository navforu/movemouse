import SwiftUI

@main
struct MoveMouseMacApp: App {
    @StateObject var mainViewModel = MainViewModel()
    @StateObject var powerSourceService = PowerSourceService() // Add PowerSourceService
    @Environment(\.scenePhase) var scenePhase

    // Delegate to handle app lifecycle events like closing the window
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(mainViewModel)
                .environmentObject(powerSourceService) // Provide it to the environment
                .onAppear {
                    appDelegate.window = NSApplication.shared.windows.first
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // App became active
            } else if newPhase == .inactive {
                // App became inactive (e.g., user switched to another app but window might still be visible)
            } else if newPhase == .background {
                // App is in background (window not visible or app is hidden)
                // If minimiseToSystemTray is NOT enabled, and app is quit from dock, this might be relevant.
                // However, typical macOS behavior is that closing the last window doesn't quit the app
                // unless explicitly handled or if it's a single-window utility app.
            }
        }
        // Use .commands modifier if you need to customize menu bar items, like File > Quit
        // or application lifecycle commands. For system tray, MenuBarExtra is the way.

        // MenuBarExtra for "Minimise to System Tray"
        // Visibility of MenuBarExtra is controlled by a @State variable,
        // which can be toggled by settings.
        // Note: The actual show/hide of the main window when using MenuBarExtra
        // needs to be handled manually.
        if mainViewModel.settings.minimiseToSystemTray {
             MenuBarExtra("MoveMouse", systemImage: mainViewModel.isRunning ? "cursorarrow.motionlines" : "cursorarrow.slash") {
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
                    // Need a way to show settings from here.
                    // One way is to have a global state or notification that ContentView listens to.
                    // Or, if ContentView is already open, bring it to front.
                    // For simplicity, ensure window is shown, then settings can be accessed.
                    showWindow()
                    // A more direct way would involve a shared @State or a specific function in MainViewModel
                    // to trigger showing the settings sheet on the ContentView.
                    // This is a placeholder for that more complex interaction if needed.
                    // mainViewModel.showSettingsFromMenuBar = true // (Example of a trigger)
                }
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    func showWindow() {
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
