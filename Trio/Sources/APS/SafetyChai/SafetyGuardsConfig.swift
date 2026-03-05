import Foundation

struct SafetyGuardsConfig {
    // Hard limits (not user-facing)
    static let tickSeconds: UInt64 = 60
    static let maxFloorActiveSeconds: TimeInterval = 15 * 60
    static let loopStaleSeconds: TimeInterval = 15 * 60

    // DASH basal increment
    static let dashBasalIncrementUph: Double = 0.05

    // Derived tolerance for comparisons
    static let basalRateEpsilon: Double = dashBasalIncrementUph / 2.0 // 0.025

    // User-driven preferences set in settings
    let maxTempBasalDurationSeconds: TimeInterval
    let maxTempBasalAgeSeconds: TimeInterval
    let cgmStaleSeconds: TimeInterval
    let allowOverrideManualTempBasal: Bool
    let minBasalFloorUph: Double

    init(preferences: Preferences) {
        // DASH basal duration allowance: cancel (0) OR 30..720 minutes
        func clampDashMinutesAllowZero(_ m: Int) -> Int {
            if m <= 0 { return 0 }
            return min(720, max(30, m))
        }

        maxTempBasalDurationSeconds =
            TimeInterval(
                clampDashMinutesAllowZero(Int(
                    truncating: NSDecimalNumber(decimal: preferences.maxTempBasalDurationMinutes)
                )) * 60
            )

        maxTempBasalAgeSeconds =
            TimeInterval(
                clampDashMinutesAllowZero(Int(
                    truncating: NSDecimalNumber(decimal: preferences.maxTempBasalAgeMinutes)
                )) * 60
            )

        cgmStaleSeconds =
            TimeInterval(
                max(5, Int(
                    truncating: NSDecimalNumber(decimal: preferences.cgmStaleMinutes)
                )) * 60
            )

        allowOverrideManualTempBasal = preferences.allowOverrideManualTempBasal

        minBasalFloorUph = NSDecimalNumber(decimal: preferences.minTempBasalFloorUph).doubleValue
    }
}
