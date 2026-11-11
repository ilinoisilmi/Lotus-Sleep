import Foundation

public enum RestPet:String,Codable,CaseIterable,Sendable {
    case bunny,fox,otter,kitten
    public var name:String { switch self {case .bunny:return "Mochi";case .fox:return "Ember";case .otter:return "Pebble";case .kitten:return "Clover"} }
    public var species:String { rawValue.capitalized }
    public var row:Int { Self.allCases.firstIndex(of:self) ?? 0 }
}
public struct PetAward:Codable,Identifiable,Sendable {
    public var dayKey:String
    public var pet:RestPet
    public var streak:Int
    public var earnedAt:Date
    public var id:String { dayKey }
}
public struct CompanionState:Codable,Sendable {
    public var selected=RestPet.bunny
    public var awards:[PetAward]=[]
    public init() {}
    public static let milestones=[0,3,7,14,30]
    public static let stageNames=["Companion","Settled","At ease","At home","Lotus companion"]
    public func best(for pet:RestPet)->Int { awards.filter{$0.pet == pet}.map(\.streak).max() ?? 0 }
    public func stage(for pet:RestPet)->Int { Self.milestones.lastIndex(where:{$0 <= best(for:pet)}) ?? 0 }
    public func validate() throws {
        guard awards.count <= 30000,Set(awards.map(\.dayKey)).count == awards.count,
              awards.allSatisfy({(1...366).contains($0.streak) && $0.dayKey.count == 10 && $0.dayKey.filter({$0 == "-"}).count == 2 && $0.dayKey.allSatisfy({$0.isNumber || $0 == "-"})}) else { throw LumaError.invalid("Invalid companion progress.") }
    }
}
public struct RestStreakSummary:Sendable {
    public var current:Int
    public var best:Int
    public var waitingForLog:Bool
    public var latestGoodDay:Date?
    public var dayKey:String?
}
public enum RestStreak {
    public static func quality(for day:SleepDay,in snapshot:Snapshot,now:Date)->Double? {
        let ratings=snapshot.diaries.filter{!$0.isDeleted && $0.current.kind != .nap && $0.current.wake >= day.window.start && $0.current.wake < day.window.end && $0.current.wake <= now}.compactMap{$0.current.qualityRating}
        return ratings.isEmpty ? nil : Double(ratings.reduce(0,+))/Double(ratings.count)
    }
    public static func summary(snapshot:Snapshot,now:Date)->RestStreakSummary {
        let p=snapshot.preferences,cal=SleepCalendar.calendar(zoneID:p.reportingTimeZoneID)
        let days=SleepCalendar.days(records:snapshot.effectiveRecords.filter{$0.end <= now},endingOn:now,count:366,preferences:p)
        var run=0,best=0,current=0,waiting=false,goodDay:Date?
        for (index,day) in days.enumerated() {
            let rating=NightReview.rating(hours:day.hours,target:p.targetHours,quality:quality(for:day,in:snapshot,now:now))
            // Today's unclosed day may still receive sleep evidence. It cannot end yesterday's run.
            if index == days.count-1,day.window.end > now,rating != .good { break }
            if rating == .good { run+=1;best=max(best,run);goodDay=day.date;waiting=false }
            else { run=0;goodDay=nil;waiting=rating == .unlogged }
            current=run
        }
        let key=goodDay.map{date -> String in let c=cal.dateComponents([.year,.month,.day],from:date);return String(format:"%04d-%02d-%02d",c.year ?? 0,c.month ?? 0,c.day ?? 0)}
        return RestStreakSummary(current:current,best:best,waitingForLog:waiting,latestGoodDay:goodDay,dayKey:key)
    }
    /// At most one pet receives a given sleep day's milestone, including after relaunch or switching pets.
    @discardableResult public static func celebrate(snapshot:inout Snapshot,now:Date)->Bool {
        let streak=summary(snapshot:snapshot,now:now)
        guard let key=streak.dayKey,streak.current > 0,!snapshot.companions.awards.contains(where:{$0.dayKey == key}) else { return false }
        snapshot.companions.awards.append(PetAward(dayKey:key,pet:snapshot.companions.selected,streak:streak.current,earnedAt:now));return true
    }
}
