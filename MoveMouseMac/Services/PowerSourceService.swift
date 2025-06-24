import Foundation
import IOKit.ps // For power source information

class PowerSourceService: ObservableObject {
    @Published var isOnBattery: Bool = false

    private var timer: Timer?

    init() {
        checkPowerSource()
        // Periodically check, as power source can change.
        // More sophisticated apps might register for power source change notifications (kIOPSTimeRemainingNotificationKey, etc.)
        // For simplicity, a timer is used here.
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkPowerSource()
        }
    }

    func checkPowerSource() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef] // Changed here

        var foundBattery = false
        for ps in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] { // Added optional chaining
                // kIOPSCurrentCapacityKey may not always be present, especially for AC power.
                // let currentCapacity = info[kIOPSCurrentCapacityKey] as? Int
                // let isCharging = info[kIOPSIsChargingKey] as? Bool

                if let powerSourceState = info[kIOPSPowerSourceStateKey] as? String {
                    if powerSourceState == kIOPSBatteryPowerValue {
                        foundBattery = true
                        break // Found we are on battery, no need to check others
                    }
                }
            }
        }

        if self.isOnBattery != foundBattery {
            self.isOnBattery = foundBattery
            print("Power source changed. On Battery: \(self.isOnBattery)")
        }
    }

    deinit {
        timer?.invalidate()
    }
}
