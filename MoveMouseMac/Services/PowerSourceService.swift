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
        let sources = IOPSGetPowerSourceList(snapshot).takeRetainedValue() as [CFTypeRef]

        var foundBattery = false
        for ps in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, ps).takeUnretainedValue() as? [String: Any] {
                if let currentCapacity = info[kIOPSCurrentCapacityKey] as? Int,
                   let isCharging = info[kIOPSIsChargingKey] as? Bool,
                   let powerSourceState = info[kIOPSPowerSourceStateKey] as? String {

                    // A power source is listed, let's see if it's a battery and if we're on it
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
