
import Foundation

struct SafetyGuardsConfig {
    let tickSeconds: UInt64 = 60

    let maxTempBasalDurationSeconds: TimeInterval
    let maxTempBasalAgeSeconds: TimeInterval
    let cgmStaleSeconds: TimeInterval
    let allowCancelDuringManualTempBasal: Bool
    let minBasalFloorUph: Double

    init(preferences: Preferences) {
        // DASH legal duration: cancel (0) OR 30..720 minutes
        func clampDashMinutes(_ m: Int) -> Int { min(720, max(30, m)) }

        maxTempBasalDurationSeconds =
            TimeInterval(
                clampDashMinutes(Int(truncating: NSDecimalNumber(decimal: preferences.maxTempBasalDurationMinutes))) *
                    60
            )
        maxTempBasalAgeSeconds =
            TimeInterval(clampDashMinutes(Int(truncating: NSDecimalNumber(decimal: preferences.maxTempBasalAgeMinutes))) * 60)

        cgmStaleSeconds = TimeInterval(max(5, Int(truncating: NSDecimalNumber(decimal: preferences.cgmStaleMinutes))) * 60)

        allowCancelDuringManualTempBasal = preferences.allowCancelDuringManualTempBasal

        // DASH increments 0.05 U/hr; use Double for arithmetic
        minBasalFloorUph = NSDecimalNumber(decimal: preferences.minTempBasalFloorUph).doubleValue
    }

    // SAFETY_GUARDS — hard limit (not user-facing)
    let maxFloorActiveSeconds: TimeInterval = 15 * 60
}
