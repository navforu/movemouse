import Foundation

class PersistenceService {
    private var settingsFilePath: URL

    init() {
        // Get the Application Support directory URL
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could not find Application Support directory.")
        }

        // Create a subdirectory for your app if it doesn't exist
        let appDirectoryURL = appSupportURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "MoveMouseMac")
        if !FileManager.default.fileExists(atPath: appDirectoryURL.path) {
            do {
                try FileManager.default.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Could not create app directory in Application Support: \(error)")
            }
        }

        // Define the settings file path
        settingsFilePath = appDirectoryURL.appendingPathComponent("settings.json")

        print("Settings file path: \(settingsFilePath.path)")
    }

    func loadSettings() -> Settings {
        do {
            if FileManager.default.fileExists(atPath: settingsFilePath.path) {
                let data = try Data(contentsOf: settingsFilePath)
                let decoder = JSONDecoder()
                // It's good practice to set a date decoding strategy if your dates are not in a standard ISO8601 format
                // For HH:mm:ss, you might need a custom strategy or store them as TimeIntervals from midnight.
                // For simplicity, if Date uses default encoding/decoding and it works, that's fine.
                // Otherwise, you might need to adjust how Date is encoded/decoded in your Schedule/Blackout models.
                // For now, we assume default Date Codable conformance is sufficient or will be adjusted.
                let settings = try decoder.decode(Settings.self, from: data)
                return settings
            }
        } catch {
            print("Error loading settings: \(error). Returning default settings.")
            // Fallthrough to return default settings if file doesn't exist or decoding fails
        }
        return Settings.defaultSettings
    }

    func saveSettings(_ settings: Settings) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted // For human-readable JSON
            // Similar to decoding, ensure your Date encoding strategy is appropriate.
            let data = try encoder.encode(settings)
            try data.write(to: settingsFilePath, options: .atomic)
            print("Settings saved successfully to \(settingsFilePath.path)")
        } catch {
            print("Error saving settings: \(error)")
        }
    }
}
