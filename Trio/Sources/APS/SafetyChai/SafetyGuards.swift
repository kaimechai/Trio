import Foundation

final class SafetyGuards {
    enum Action {
        case none
        case cancelTempBasal(reason: String) // cancel current temp basal (revert to scheduled basal)
    }

    private var task: Task<Void, Never>?

    func startIfNeeded(every interval: Duration, tick: @escaping @Sendable() async -> Void) {
        guard task == nil else { return }
        task = Task {
            let clock = ContinuousClock()
            var next = clock.now
            while !Task.isCancelled {
                await tick()
                next += interval
                try? await Task.sleep(until: next, clock: clock)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func evaluate(
        now: Date,
        tempBasalIsActive: Bool,
        tempBasalStart: Date?,
        tempBasalRateUph: Double?,
        isManualTempBasal: Bool,
        lastGlucoseDate: Date?,
        lastLoopDate: Date,
        config: SafetyGuardsConfig
    ) -> Action {
        guard tempBasalIsActive,
              let tempBasalStart,
              let tempBasalRateUph
        else { return .none }

        let canInterfere = TempBasalInterferencePolicy.canInterfere(
            isManualTempBasal: isManualTempBasal,
            allowWhenManual: config.allowOverrideManualTempBasal
        )

        let canOverride = isManualTempBasal
            ? config.allowOverrideManualTempBasal
            : true

        // If we can't interfere with a manual temp basal, we can't cancel it for any rule.
        guard canInterfere else { return .none }

        let loopAge = now.timeIntervalSince(lastLoopDate)
        let age = now.timeIntervalSince(tempBasalStart)

        // Rule 2: Loop stale while temp basal active
        if loopAge >= SafetyGuardsConfig.loopStaleSeconds {
            return .cancelTempBasal(
                reason: "Loop inactive ≥ \(Int(SafetyGuardsConfig.loopStaleSeconds / 60)) min while temp basal active. Reverting to scheduled basal."
            )
        }

        // Rule 3: CGM stale OR missing date
        let isCGMStale = lastGlucoseDate.map { now.timeIntervalSince($0) >= config.cgmStaleSeconds } ?? true
        if isCGMStale {
            let reason = (lastGlucoseDate == nil)
                ? "CGM timestamp missing; reverting to scheduled basal."
                : "CGM stale ≥ \(Int(config.cgmStaleSeconds / 60)) min; reverting to scheduled basal."
            return .cancelTempBasal(reason: reason)
        }

        // Rule 4: Max temp basal age exceeded
        if config.maxTempBasalAgeSeconds > 0, age >= config.maxTempBasalAgeSeconds {
            return .cancelTempBasal(
                reason: "Temp basal exceeded max age allowance (\(Int(config.maxTempBasalAgeSeconds / 60)) min). Reverting to scheduled basal."
            )
        }

        // Rule 5: Basal floor active too long
        let floorActive = tempBasalRateUph <= config.minBasalFloorUph + SafetyGuardsConfig.basalRateEpsilon
        if floorActive, age >= SafetyGuardsConfig.maxFloorActiveSeconds {
            return .cancelTempBasal(
                reason: "Minimum basal floor (\(config.minBasalFloorUph) U/hr) active ≥ \(Int(SafetyGuardsConfig.maxFloorActiveSeconds / 60)) min; reverting to scheduled basal."
            )
        }

        return .none
    }
}

enum TempBasalInterferencePolicy {
    static func canInterfere(isManualTempBasal: Bool, allowWhenManual: Bool) -> Bool {
        !isManualTempBasal || allowWhenManual
    }
}
