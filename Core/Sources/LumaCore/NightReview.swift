import Foundation

public enum DisturbanceReason: String, Codable, CaseIterable, Sendable {
    case unsure, noise, thoughts, bathroom, temperature, discomfort
    public var title: String {
        switch self {
        case .unsure: return "Not sure"
        case .noise: return "Noise or someone nearby"
        case .thoughts: return "Racing thoughts"
        case .bathroom: return "Bathroom break"
        case .temperature: return "Too warm or cold"
        case .discomfort: return "Pain or discomfort"
        }
    }
    public var guidance: String {
        switch self {
        case .unsure: return "Brief wake-ups can happen. Keep things dim and quiet, relax your shoulders, and let your breathing settle naturally. You do not need to force sleep."
        case .noise: return "If possible, reduce the noise or move to a quieter spot. Keep lights low and avoid checking notifications while you settle again."
        case .thoughts: return "Write a short note about what is on your mind, then leave it for tomorrow. Relax your jaw and shoulders and breathe comfortably, without holding your breath."
        case .bathroom: return "Use only as much light as you need to move safely. Return to your usual sleep setting and give yourself a quiet moment to settle."
        case .temperature: return "Adjust a blanket, clothing or ventilation until the room feels comfortable. A cool, dark and quiet bedroom can make settling easier."
        case .discomfort: return "Try a comfortable position. If discomfort is new, severe or keeps returning, seek medical advice rather than relying on this guide."
        }
    }
}

public struct SleepDisturbance: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var start: Date
    public var end: Date?
    public var reason: DisturbanceReason = .unsure
    public var notes = ""
    public var sessionID: UUID?
    public init(start: Date, end: Date? = nil, sessionID: UUID? = nil) {
        self.start=start; self.end=end; self.sessionID=sessionID
    }
    public func validate() throws {
        if let end {
            guard end.timeIntervalSince(start) >= 1, end.timeIntervalSince(start) <= 48*3600 else {
                throw LumaError.invalid("Use a wake-up interval of at least one second and no more than 48 hours.")
            }
        }
        guard notes.count <= 4000 else { throw LumaError.invalid("Keep wake-up notes under 4,000 characters.") }
    }
}

public enum DisturbanceActions {
    /// A live wake-up survives relaunches and cannot be duplicated by repeated taps.
    @discardableResult public static func start(snapshot: inout Snapshot, at date: Date) -> UUID {
        if let existing=snapshot.disturbances.first(where:{$0.end == nil}) { return existing.id }
        let entry=SleepDisturbance(start:date,sessionID:snapshot.activeSession?.id)
        snapshot.disturbances.append(entry)
        return entry.id
    }
    public static func finish(snapshot: inout Snapshot, id: UUID, at date: Date) throws {
        guard let index=snapshot.disturbances.firstIndex(where:{$0.id == id}) else { throw LumaError.invalid("Wake-up log not found.") }
        guard snapshot.disturbances[index].end == nil else { return }
        var entry=snapshot.disturbances[index]
        entry.end=date
        try entry.validate()
        snapshot.disturbances[index]=entry
    }
    /// Explicitly imported during diary review. Merge overlaps and clip to the user's sleep estimate.
    public static func intervals(_ entries: [SleepDisturbance], sleepStart: Date, wake: Date) -> [AwakeInterval] {
        guard sleepStart < wake else { return [] }
        let ranges=entries.compactMap { entry -> DateInterval? in
            guard let end=entry.end else { return nil }
            let a=max(entry.start,sleepStart), b=min(end,wake)
            return a < b ? DateInterval(start:a,end:b) : nil
        }
        return SleepReconciler.union(ranges).map { AwakeInterval(start:$0.start,end:$0.end) }
    }
}

public enum NightRating: String, Sendable {
    case unlogged = "Not logged", good = "Good", mixed = "Mixed", attention = "Needs attention"
    public var symbol: String {
        switch self {
        case .unlogged: return "minus.circle"
        case .good: return "checkmark.circle.fill"
        case .mixed: return "circle.lefthalf.filled"
        case .attention: return "exclamationmark.circle.fill"
        }
    }
}

public enum NightReview {
    /// An explained diary summary, not a medical sleep score. Missing data is never a bad night.
    public static func rating(hours: Double?, target: Double, quality: Double?) -> NightRating {
        guard let hours, hours.isFinite else { return .unlogged }
        if hours < target-1 || (quality.map{$0 <= 2} ?? false) { return .attention }
        if hours >= target-0.5 && (quality.map{$0 >= 4} ?? true) { return .good }
        return .mixed
    }
    public static func explanation(hours: Double?, target: Double, quality: Double?) -> String {
        guard let hours else { return "No confirmed sleep estimate yet." }
        let minutes=Int((abs(hours-target)*60).rounded())
        let duration=minutes == 0 ? "At your duration target" : "\(minutes) min \(hours < target ? "below" : "above") your target"
        return duration + (quality.map { " · quality \(String(format:"%.1f",$0))/5" } ?? " · quality not rated")
    }
}
