import Foundation
import AppKit // For NSWorkspace to open files with default app

enum ScriptType {
    case start, interval, pause
}

class ScriptExecutionService {

    // Basic script execution. For macOS, this typically means AppleScript or shell scripts.
    // The original app had specific paths based on script type and configured language.
    // We'll need a way to manage these paths. For now, this is a simplified version.

    func executeScript(type: ScriptType, language: String, path: String?, showExecution: Bool) {
        // Determine the actual script path. This logic will need to be more robust,
        // potentially fetching paths from Settings or a dedicated script management system.
        let scriptPath: String
        let scriptName: String

        switch type {
        case .start:
            scriptName = "MoveMouse-Start"
        case .interval:
            scriptName = "MoveMouse-Interval"
        case .pause:
            scriptName = "MoveMouse-Pause"
        }

        // Construct path based on language and type, assuming scripts are in App Support dir for now
        // This needs to be configurable as in the original app.
        // For this placeholder, we'll assume `path` is provided or we construct a default.

        var effectivePath = path

        if effectivePath == nil {
            guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                print("Error: Could not find Application Support directory for scripts.")
                return
            }
            let appDirectoryURL = appSupportURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "MoveMouseMac")
            var scriptExtension = "scpt" // Default for AppleScript
            if language.lowercased().contains("shell") {
                scriptExtension = "sh"
            }
            // Add more language/extension mappings as needed

            effectivePath = appDirectoryURL.appendingPathComponent("\(scriptName).\(scriptExtension)").path
        }

        guard let finalPath = effectivePath, FileManager.default.fileExists(atPath: finalPath) else {
            print("Script file not found at \(effectivePath ?? "N/A") for type \(type) and language \(language)")
            return
        }

        print("Executing \(language) script: \(finalPath)")

        if language.lowercased().contains("applescript") {
            executeAppleScript(path: finalPath, showExecution: showExecution)
        } else if language.lowercased().contains("shell") {
            executeShellScript(path: finalPath, showExecution: showExecution)
        } else {
            print("Unsupported script language: \(language)")
        }
    }

    private func executeAppleScript(path: String, showExecution: Bool) {
        // NSAppleScript can execute AppleScript files or source strings.
        // If showExecution is true, it's harder to control the visibility of Script Editor
        // if we just run a compiled script. osascript is more flexible here.

        let task = Process()
        task.launchPath = "/usr/bin/osascript" // Standard path for osascript
        task.arguments = [path]

        // `showExecution` is tricky with osascript directly for GUI feedback.
        // If `showExecution` is true, one might consider opening the script in Script Editor
        // and having the user run it, but that's not automatic.
        // For now, `showExecution` will be ignored for direct execution.
        // If true, it implies the script itself might present UI.

        do {
            try task.run()
            // task.waitUntilExit() // Uncomment if synchronous execution is needed.
            // For asynchronous:
             if #available(macOS 10.13, *) {
                task.terminationHandler = { process in
                    print("AppleScript finished with status: \(process.terminationStatus)")
                }
            }
            print("AppleScript launched: \(path)")
        } catch {
            print("Error launching AppleScript: \(error)")
        }
    }

    private func executeShellScript(path: String, showExecution: Bool) {
        let task = Process()
        task.launchPath = "/bin/sh" // Or /bin/bash, zsh, etc., depending on script's shebang or requirements
        task.arguments = [path]

        // If showExecution is true, the script might run in a new Terminal window.
        // This is more complex and typically involves AppleScript to tell Terminal to run the script.
        // For a simpler direct execution that doesn't pop a window (unless the script itself does):
        if !showExecution {
            // Standard pipes can be captured if needed
            // let outputPipe = Pipe()
            // task.standardOutput = outputPipe
            // task.standardError = Pipe() // Capture errors separately if desired
        } else {
            // To show execution in Terminal:
            // This is a common way; requires Terminal to be available.
            let terminalScript = """
            tell application "Terminal"
                activate
                do script "\(path.replacingOccurrences(of: "\"", with: "\\\""))"
            end tell
            """
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: terminalScript) {
                let executionResult = scriptObject.executeAndReturnError(&error)
                // NSAppleScript.executeAndReturnError returns an NSAppleEventDescriptor on success,
                // or nil on failure (in which case `error` is populated).
                // The warning is because `executionResult` itself is an optional NSAppleEventDescriptor?,
                // but if it's non-nil, the operation was successful.
                // The original code `scriptObject.executeAndReturnError(&error) == nil` correctly checks for failure.
                // However, the Swift compiler might be overly pedantic if the return type is perceived as non-optional in some contexts.
                // Let's be explicit.
                if executionResult != nil { // Success
                     print("Shell script launched in new Terminal window: \(path)")
                     return // Successfully launched in Terminal
                }
            }
            // Fallback or if above fails, just run it directly (no separate window by default)
            print("Could not launch script in Terminal, running directly (showExecution might not be fully effective).")
        }


        do {
            try task.run()
            // Asynchronous execution is typical for UI apps.
            if #available(macOS 10.13, *) {
                task.terminationHandler = { process in
                     print("Shell script finished with status: \(process.terminationStatus)")
                    // if let outputData = (process.standardOutput as? Pipe)?.fileHandleForReading.readDataToEndOfFile(),
                    //    let outputString = String(data: outputData, encoding: .utf8) {
                    //     print("Script output: \(outputString)")
                    // }
                }
            }
             print("Shell script launched: \(path)")
        } catch {
            print("Error launching shell script: \(error)")
        }
    }

    // Placeholder for creating an empty script (e.g., when user wants to edit a new one)
    // This would be called before opening in the selected script editor.
    func createEmptyScriptIfNeeded(type: ScriptType, language: String, scriptEditorPath: String) -> String? {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("Error: Could not find Application Support directory for scripts.")
            return nil
        }
        let appDirectoryURL = appSupportURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "MoveMouseMac")
        if !FileManager.default.fileExists(atPath: appDirectoryURL.path) {
            do {
                try FileManager.default.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Could not create app directory for scripts: \(error)")
                return nil
            }
        }

        let scriptName: String
        switch type {
        case .start: scriptName = "MoveMouse-Start"
        case .interval: scriptName = "MoveMouse-Interval"
        case .pause: scriptName = "MoveMouse-Pause"
        }

        var scriptExtension = "scpt" // AppleScript
        var defaultContent = "# Move Mouse \(type) script (AppleScript)\n\n"
        if language.lowercased().contains("shell") {
            scriptExtension = "sh"
            defaultContent = "#!/bin/sh\n# Move Mouse \(type) script (Shell)\n\n"
        }
        // Add more types as needed

        let fullPath = appDirectoryURL.appendingPathComponent("\(scriptName).\(scriptExtension)")

        if !FileManager.default.fileExists(atPath: fullPath.path) {
            do {
                try defaultContent.write(to: fullPath, atomically: true, encoding: .utf8)
                print("Created empty script at: \(fullPath.path)")
            } catch {
                print("Failed to create empty script \(fullPath.path): \(error)")
                return nil
            }
        }

        // Open the script with the designated editor
        let workspace = NSWorkspace.shared
        let editorURL = URL(fileURLWithPath: scriptEditorPath)

        // Check if the editor is Script Editor, which might prefer being told to open a file via AppleScript
        // For general .app bundles, open(_:configuration:completionHandler:) is good.
        if #available(macOS 10.15, *) {
            let configuration = NSWorkspace.OpenConfiguration()
            // configuration.activates = true // if you want the editor to become frontmost
            workspace.open([fullPath], withApplicationAt: editorURL, configuration: configuration) { runningApp, error in
                if let error = error {
                    print("Error opening script \(fullPath.path) with \(editorURL.lastPathComponent): \(error)")
                    // Fallback or alert user
                } else {
                    print("Successfully requested open of \(fullPath.path) with \(editorURL.lastPathComponent)")
                }
            }
        } else {
            // Fallback for older macOS versions
            if !workspace.openFile(fullPath.path, withApplication: editorURL.lastPathComponent) {
                 print("Error opening script \(fullPath.path) with \(editorURL.lastPathComponent) (legacy method)")
                 // Try opening with default application for the file type if specific editor fails
                 if !workspace.open(fullPath) {
                     print("Error opening script \(fullPath.path) with default application.")
                 }
            }
        }
        return fullPath.path
    }
}
