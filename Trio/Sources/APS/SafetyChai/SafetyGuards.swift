import Foundation

// SAFETY_GUARDS

final class SafetyGuards {
    enum Action {
        case none
        case cancelTempBasal(reason: String) // cancel current temp basal (revert to profile)
    }

    private var task: Task<Void, Never>?

    func startIfNeeded(tickSeconds: UInt64, tick: @escaping @Sendable() async -> Void) {
        guard task == nil else { return }
        task = Task {
            while !Task.isCancelled {
                await tick()
                try? await Task.sleep(nanoseconds: tickSeconds * 1_000_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func evaluate(
        now: Date,
        tempBasalisActive: Bool,
        tempBasalStart: Date,
        tempBasalRateUph: Double,
        lastGlucoseDate: Date?,
        lastLoopDate: Date,
        config: SafetyGuardsConfig
    ) -> Action {
        // Rule: CGM stale => force revert to profile (cancel temp basal if one is active)
        if let last = lastGlucoseDate {
            let stale = now.timeIntervalSince(last) >= config.cgmStaleSeconds
            if stale, tempBasalisActive {
                return .cancelTempBasal(
                    reason: "CGM stale ≥ \(Int(config.cgmStaleSeconds / 60)) min; reverting to scheduled basal."
                )
            }
        }

        // Rule: minimum basal floor active too long => cancel temp basal (revert to profile)
        let age = now.timeIntervalSince(tempBasalStart)
        let floorActive = tempBasalRateUph <= (config.minBasalFloorUph + 0.0001)

        if floorActive, age >= SafetyGuardsConfig.maxFloorActiveSeconds {
            return .cancelTempBasal(
                reason: "Minimum basal floor (\(config.minBasalFloorUph) U/hr) active ≥ 15 min; reverting to scheduled basal."
            )
        }

        guard tempBasalisActive else { return .none }

        // Rule: Loop stale (no loop for 15 min) AND temp basal active => cancel temp basal
        let loopStaleSeconds: TimeInterval = 15 * 60
        if tempBasalisActive, now.timeIntervalSince(lastLoopDate) >= loopStaleSeconds {
            return .cancelTempBasal(reason: "Loop inactive ≥ 15 min; cancelling temp basal to revert to scheduled basal.")
        }

        // Rule: temp basal too old
        if age >= config.maxTempBasalAgeSeconds {
            return .cancelTempBasal(
                reason: "Temp basal exceeded max age; reverting to scheduled basal."
            )
        }

        if floorActive, age >= SafetyGuardsConfig.maxFloorActiveSeconds {}

        return .none
    }
}
