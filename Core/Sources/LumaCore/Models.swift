import Foundation

public enum SleepStage: String, Codable, CaseIterable, Sendable {
    case inBed, awake, asleep, core, deep, rem
    public var isAsleep: Bool { self != .inBed && self != .awake }
    public var label: String { self == .inBed ? "In bed" : self == .rem ? "REM" : self == .asleep ? "Asleep (unspecified)" : rawValue.capitalized }
}
public enum TrackingMethod: String, Codable, CaseIterable, Sendable { case diary, bedtime, health, file, motion }
public enum EvidenceQuality: String, Codable, Sendable { case reported, wearable, estimated, imported }
public enum SleepKind: String, Codable, CaseIterable, Sendable { case main, nap, unspecified }

/// Absolute instants determine duration. The IANA zone preserves the source's local context.
public struct SleepRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var sourceID: String
    public var sourceName: String
    public var method: TrackingMethod
    public var start: Date
    public var end: Date
    public var timeZoneID: String
    public var stage: SleepStage
    public var kind: SleepKind
    public var quality: EvidenceQuality
    public var groupID: String
    public init(id: String, sourceID: String, sourceName: String, method: TrackingMethod, start: Date, end: Date, timeZoneID: String, stage: SleepStage, kind: SleepKind = .unspecified, quality: EvidenceQuality = .reported, groupID: String = "") {
        self.id=id; self.sourceID=sourceID; self.sourceName=sourceName; self.method=method
        self.start=start; self.end=end; self.timeZoneID=timeZoneID; self.stage=stage; self.kind=kind; self.quality=quality; self.groupID=groupID.isEmpty ? id : groupID
    }
    public func validate() throws {
        guard !id.isEmpty, !sourceID.isEmpty, !sourceName.isEmpty, start < end, end.timeIntervalSince(start) <= 172800,
              TimeZone(identifier: timeZoneID) != nil else { throw LumaError.invalid("Record \(id): check timestamps, timezone, source and duration (maximum 48 hours per record).") }
    }
}
public struct AwakeInterval: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var start: Date
    public var end: Date
    public init(start: Date, end: Date) { self.start=start; self.end=end }
}
public struct DiaryVersion: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var savedAt: Date = Date()
    public var bedtime: Date
    public var sleepStart: Date?
    public var wake: Date
    public var outOfBed: Date
    public var awakenings: [AwakeInterval] = []
    public var kind: SleepKind = .main
    public var qualityRating: Int?
    public var notes: String = ""
    public var tags: [String] = []
    public var timeZoneID: String
    public var method: TrackingMethod = .diary
    public var includesInBedEvidence: Bool?
    public init(bedtime: Date, sleepStart: Date?, wake: Date, outOfBed: Date, timeZoneID: String) {
        self.bedtime=bedtime; self.sleepStart=sleepStart; self.wake=wake; self.outOfBed=outOfBed; self.timeZoneID=timeZoneID
    }
    public func validate() throws {
        guard bedtime < outOfBed, bedtime <= wake, wake <= outOfBed,
              outOfBed.timeIntervalSince(bedtime) <= 172800, TimeZone(identifier: timeZoneID) != nil else { throw LumaError.invalid("Use an in-bed window of up to 48 hours with a valid timezone and wake before getting up.") }
        if let sleepStart { guard sleepStart >= bedtime, sleepStart < wake else { throw LumaError.invalid("Falling asleep must be between bedtime and final wake.") } }
        if let qualityRating { guard (1...5).contains(qualityRating) else { throw LumaError.invalid("Quality must be 1–5.") } }
        for a in awakenings {
            guard let sleepStart, a.start >= sleepStart, a.end <= wake, a.start < a.end else { throw LumaError.invalid("Awakenings must fit inside the estimated sleep window.") }
        }
    }
    public func records(diaryID: UUID, sourceID: String = "diary", sourceName: String = "Sleep diary") -> [SleepRecord] {
        let base = diaryID.uuidString + ":" + id.uuidString
        func record(_ suffix: String, _ a: Date, _ b: Date, _ stage: SleepStage) -> SleepRecord {
            SleepRecord(id: base+suffix, sourceID: sourceID, sourceName: sourceName, method: method, start: a, end: b, timeZoneID: timeZoneID, stage: stage, kind: kind, quality: .reported, groupID: diaryID.uuidString)
        }
        var result = includesInBedEvidence == false ? [] : [record(":bed", bedtime, outOfBed, .inBed)]
        if let sleepStart {
            result.append(record(":sleep", sleepStart, wake, .asleep))
            result += awakenings.enumerated().map { record(":awake\($0.offset)", $0.element.start, $0.element.end, .awake) }
        }
        return result
    }
}
public struct DiaryEntry: Identifiable, Codable, Sendable {
    public var id: UUID = UUID()
    public var versions: [DiaryVersion]
    public var activeVersionID: UUID
    public var isDeleted = false
    public init(version: DiaryVersion) { versions=[version]; activeVersionID=version.id }
    public var current: DiaryVersion { versions.first(where: { $0.id == activeVersionID }) ?? versions[versions.count-1] }
    public mutating func revise(_ version: DiaryVersion) { versions.append(version); activeVersionID=version.id }
    public mutating func undoRevision() { if let i=versions.firstIndex(where: { $0.id == activeVersionID }), i > 0 { activeVersionID=versions[i-1].id } }
}
public struct Correction: Identifiable, Codable, Sendable {
    public var id = UUID()
    public var createdAt = Date()
    public var originalIDs: [String]
    public var replacements: [SleepRecord]
    public var isUndone = false
    public var reason: String
    public init(originalIDs: [String], replacements: [SleepRecord], reason: String) { self.originalIDs=originalIDs; self.replacements=replacements; self.reason=reason }
}
public struct ActiveSession: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var startedAt: Date
    public var timeZoneID: String
    public var kind: SleepKind
    public init(startedAt: Date, timeZoneID: String, kind: SleepKind) { self.startedAt=startedAt; self.timeZoneID=timeZoneID; self.kind=kind }
}
public struct EnergyCheckIn: Identifiable, Codable, Sendable {
    public var id = UUID()
    public var date: Date
    public var value: Int
    public init(date: Date, value: Int) { self.date=date; self.value=value }
}
public struct SoundEvent: Identifiable, Codable, Sendable {
    public var id = UUID()
    public var date: Date
    public var duration: TimeInterval
    public var peakDB: Float
    public var recordingOffset: TimeInterval?
    public init(date: Date, duration: TimeInterval, peakDB: Float, recordingOffset:TimeInterval? = nil) { self.date=date; self.duration=duration; self.peakDB=peakDB; self.recordingOffset=recordingOffset }
}
public struct AudioSession: Identifiable, Codable, Sendable {
    public var id = UUID()
    public var start: Date
    public var end: Date?
    public var status: String = "Recording"
    public var retainsAudio = false
    public var events: [SoundEvent] = []
    public var fileName: String?
    public init(start: Date) { self.start=start }
}
public struct Preferences: Codable, Sendable {
    public var targetHours: Double = 9
    public var ageBand: String = "13–17"
    public var weekdayWakeMinutes = 420
    public var weekendWakeMinutes = 540
    public var windDownMinutes = 45
    public var settlingMinutes = 20
    public var boundaryHour = 18
    public var reportingTimeZoneID = TimeZone.current.identifier
    public var sourcePriority: [String] = ["correction", "diary"]
    public var preferredMethod: TrackingMethod = .bedtime
    public var appearance: String = "system"
    public var onboardingComplete = false
    public var remindersEnabled = false
    public var reminderOptions:ReminderOptions?
    public var remindersFingerprint:String?
    public var retainAudio = false
    public var audioRetentionDays = 3
    public var widgetEnabled = false
    public var showCompanion:Bool?
    public init() {}
}
public struct Snapshot: Codable, Sendable {
    public var schemaVersion = 5
    public var records: [SleepRecord] = []
    public var deletedSourceIDs: Set<String> = []
    public var diaries: [DiaryEntry] = []
    public var corrections: [Correction] = []
    public var activeSession: ActiveSession?
    public var checkIns: [EnergyCheckIn] = []
    public var audioSessions: [AudioSession] = []
    public var disturbances: [SleepDisturbance] = []
    public var profile:SleepProfile?
    public var caffeineEntries:[CaffeineEntry] = []
    public var customSounds:[CustomSleepSound] = []
    public var soundBlends:[SoundBlend] = []
    public var experiments:[SleepExperiment] = []
    public var companions=CompanionState()
    public var morningTasks:[MorningTask]=[]
    public var preferences = Preferences()
    public var healthAnchor: Data?
    public var lastHealthSync: Date?
    public init() {}
    public var effectiveRecords: [SleepRecord] {
        var output = records.filter { !deletedSourceIDs.contains($0.id) }
        output += diaries.filter { !$0.isDeleted }.flatMap { $0.current.records(diaryID: $0.id) }
        for correction in corrections where !correction.isUndone {
            let hidden=Set(correction.originalIDs)
            output.removeAll { hidden.contains($0.id) }
            output += correction.replacements
        }
        return output
    }
}
public enum LumaError: LocalizedError {
    case invalid(String), unsupportedVersion(Int), unavailable(String)
    public var errorDescription: String? { switch self { case .invalid(let s), .unavailable(let s): return s; case .unsupportedVersion(let n): return "This backup uses version \(n). Update Lotus before opening it." } }
}
public protocol LumaClock { var now: Date { get } }
public struct SystemClock: LumaClock { public init() {}; public var now: Date { Date() } }
public protocol SnapshotStore { func load() throws -> Snapshot; func save(_ snapshot: Snapshot) throws }
