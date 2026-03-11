import Foundation

// SafetyGuards - TempBasalState
struct TempBasalState: Equatable {
    let isActive: Bool
    let isManual: Bool
    let rate: Decimal
    let startDate: Date?
    let endDate: Date?
    let configuredMinutes: Int?
    let elapsedMinutes: Int?
    let remainingMinutes: Int
}

// SafetyGuards - Staleness
struct StalenessState: Equatable {
    let glucoseMissing: Bool
    let glucoseStale: Bool
    let loopStale: Bool
}

// SafetyGuards Watchdog
enum SafetyWatchdogResult: Equatable {
    case takeNoAction
    case cancelTempBasal(reasons: [SafetyCancelReason])
}

enum SafetyCancelReason: String, Equatable {
    case staleGlucose
    case staleLoop
    case maxTempBasalAgeExceeded
}

// SafetyGuards Watchdog
enum SafetyGuards {
    static func evaluateWatchdog(
        tempBasalState: TempBasalState,
        stalenessState: StalenessState,
        maxTempBasalAgeMinutes: Int
    ) -> SafetyWatchdogResult {
        guard tempBasalState.isActive else {
            return .takeNoAction
        }

        if tempBasalState.isManual {
            return .takeNoAction
        }

        var reasons: [SafetyCancelReason] = []

        if stalenessState.glucoseMissing || stalenessState.glucoseStale {
            reasons.append(.staleGlucose)
        }

        if stalenessState.loopStale {
            reasons.append(.staleLoop)
        }

        if let elapsedMinutes = tempBasalState.elapsedMinutes,
           elapsedMinutes > maxTempBasalAgeMinutes
        {
            reasons.append(.maxTempBasalAgeExceeded)
        }

        return reasons.isEmpty ? .takeNoAction : .cancelTempBasal(reasons: reasons)
    }
}
