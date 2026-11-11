import Foundation
public enum SnapshotCodec {
    public static func encoder() -> JSONEncoder { let e=JSONEncoder(); e.outputFormatting=[.prettyPrinted,.sortedKeys]; e.dateEncodingStrategy = .iso8601; return e }
    public static func decoder() -> JSONDecoder { let d=JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
    public static func encode(_ snapshot: Snapshot) throws -> Data {
        try validate(snapshot)
        let data=try encoder().encode(snapshot)
        guard data.count <= 50*1024*1024 else { throw LumaError.invalid("The local store exceeds 50 MB. Export and archive older history before adding more data.") }
        return data
    }
    public static func decode(_ data: Data) throws -> Snapshot {
        guard data.count <= 50*1024*1024 else { throw LumaError.invalid("Backup exceeds 50 MB.") }
        guard var object=try JSONSerialization.jsonObject(with:data) as? [String:Any], let version=object["schemaVersion"] as? Int else { throw LumaError.invalid("Not a Lotus backup.") }
        guard (1...5).contains(version) else { throw LumaError.unsupportedVersion(version) }
        if version == 1 {
            // v1 used the same records/preferences with no corrections, audio or check-ins.
            object["schemaVersion"]=2
            for key in ["deletedSourceIDs","diaries","corrections","checkIns","audioSessions"] { if object[key] == nil { object[key]=[] } }
            if let old=object["preferences"] as? [String:Any], var defaults=try JSONSerialization.jsonObject(with:encoder().encode(Preferences())) as? [String:Any] {
                defaults.merge(old) { _,new in new }; object["preferences"]=defaults
            } else if object["preferences"] == nil { object["preferences"]=try JSONSerialization.jsonObject(with:encoder().encode(Preferences())) }
        }
        if version < 3 { object["schemaVersion"]=3; object["disturbances"]=[] }
        if version < 4 { object["schemaVersion"]=4; object["caffeineEntries"]=[]; object["customSounds"]=[] }
        if version < 5 { object["schemaVersion"]=5;object["soundBlends"]=[];object["experiments"]=[];object["morningTasks"]=[];object["companions"]=try JSONSerialization.jsonObject(with:encoder().encode(CompanionState())) }
        let result=try decoder().decode(Snapshot.self,from:JSONSerialization.data(withJSONObject:object))
        try validate(result); return result
    }
    public static func validate(_ s: Snapshot) throws {
        guard s.schemaVersion == 5 else { throw LumaError.unsupportedVersion(s.schemaVersion) }
        try s.profile?.validate()
        try s.companions.validate()
        try MorningInbox.validate(s.morningTasks)
        guard s.soundBlends.count <= 100,Set(s.soundBlends.map(\.id)).count == s.soundBlends.count,s.experiments.count <= 100,Set(s.experiments.map(\.id)).count == s.experiments.count,s.experiments.filter({!$0.archived}).count <= 1 else { throw LumaError.invalid("Invalid or duplicate mixes or experiments.") }
        for blend in s.soundBlends { try blend.validate() }
        for experiment in s.experiments { try experiment.validate() }
        guard s.caffeineEntries.count <= 30000,Set(s.caffeineEntries.map(\.id)).count == s.caffeineEntries.count,
              s.customSounds.count <= 50,Set(s.customSounds.map(\.id)).count == s.customSounds.count else { throw LumaError.invalid("Too many or duplicate caffeine entries or custom sounds.") }
        for entry in s.caffeineEntries { try entry.validate() }
        for sound in s.customSounds { try sound.validate() }
        guard s.disturbances.count <= 30000,
              Set(s.disturbances.map(\.id)).count == s.disturbances.count,
              s.disturbances.filter({$0.end == nil}).count <= 1 else { throw LumaError.invalid("Invalid or duplicate wake-up logs.") }
        for entry in s.disturbances { try entry.validate() }
        guard s.records.count <= 200000, s.diaries.count <= 30000, Set(s.records.map(\.id)).count == s.records.count else { throw LumaError.invalid("Too many records or duplicate record identifiers.") }
        guard Set(s.diaries.map(\.id)).count == s.diaries.count,
              Set(s.corrections.map(\.id)).count == s.corrections.count,
              Set(s.checkIns.map(\.id)).count == s.checkIns.count,
              Set(s.audioSessions.map(\.id)).count == s.audioSessions.count else { throw LumaError.invalid("Duplicate identifiers in backup collections.") }
        let p=s.preferences
        guard (4...14).contains(p.targetHours), (0...23).contains(p.boundaryHour), (0..<1440).contains(p.weekdayWakeMinutes), (0..<1440).contains(p.weekendWakeMinutes), (0...180).contains(p.windDownMinutes), (0...120).contains(p.settlingMinutes), (1...30).contains(p.audioRetentionDays), TimeZone(identifier:p.reportingTimeZoneID) != nil else { throw LumaError.invalid("Invalid backup preferences.") }
        for r in s.records { try r.validate() }
        for d in s.diaries {
            guard !d.versions.isEmpty, Set(d.versions.map(\.id)).count == d.versions.count, d.versions.contains(where:{$0.id == d.activeVersionID}) else { throw LumaError.invalid("Invalid diary revision.") }
            for v in d.versions { try v.validate() }
        }
        for c in s.corrections { for r in c.replacements { try r.validate() } }
        for check in s.checkIns { guard (1...5).contains(check.value) else { throw LumaError.invalid("Invalid energy check-in.") } }
        if let a=s.activeSession { guard TimeZone(identifier:a.timeZoneID) != nil else { throw LumaError.invalid("Invalid session timezone.") } }
        for a in s.audioSessions {
            if let f=a.fileName { guard !f.contains("/"), !f.contains("\\"), f.hasSuffix(".m4a") else { throw LumaError.invalid("Invalid audio filename.") } }
            for event in a.events {
                guard event.duration.isFinite, event.duration >= 0, event.peakDB.isFinite else { throw LumaError.invalid("Invalid sound event.") }
                if let offset=event.recordingOffset { guard offset.isFinite, offset >= 0 else { throw LumaError.invalid("Invalid sound replay position.") } }
            }
        }
    }
}
/// Single writer, invoked on the app's main actor. Atomic rename; failed writes never replace the live snapshot.
public struct JSONSnapshotStore: SnapshotStore {
    public let url: URL
    public init(url: URL) { self.url=url }
    public func load() throws -> Snapshot {
        guard FileManager.default.fileExists(atPath:url.path) else { return Snapshot() }
        return try SnapshotCodec.decode(Data(contentsOf:url))
    }
    public func save(_ snapshot: Snapshot) throws {
        let data=try SnapshotCodec.encode(snapshot)
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        #if os(iOS)
        var directory=url.deletingLastPathComponent()
        try FileManager.default.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:directory.path)
        var values=URLResourceValues(); values.isExcludedFromBackup=true; try directory.setResourceValues(values)
        try data.write(to:url,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to:url,options:.atomic)
        #endif
    }
}
public enum SessionActions {
    public static func start(snapshot: inout Snapshot, at date: Date, zone: String, kind: SleepKind) throws {
        guard snapshot.activeSession == nil else { throw LumaError.invalid("A bedtime session is already running.") }
        snapshot.activeSession=ActiveSession(startedAt:date,timeZoneID:zone,kind:kind)
    }
    @discardableResult public static func end(snapshot: inout Snapshot, at date: Date) throws -> UUID {
        guard let session=snapshot.activeSession else { throw LumaError.invalid("No active bedtime session.") }
        var version=DiaryVersion(bedtime:session.startedAt,sleepStart:nil,wake:date,outOfBed:date,timeZoneID:session.timeZoneID)
        version.kind=session.kind; version.method = .bedtime
        try version.validate()
        if let wake=snapshot.disturbances.first(where:{$0.end == nil && $0.sessionID == session.id}),date > wake.start {
            try DisturbanceActions.finish(snapshot:&snapshot,id:wake.id,at:date)
        }
        let entry=DiaryEntry(version:version); snapshot.diaries.append(entry); snapshot.activeSession=nil
        return entry.id
    }
}
