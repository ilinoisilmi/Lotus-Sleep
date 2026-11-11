import AppIntents
import Foundation
struct StartBedtimeIntent:AppIntent {
    static var title:LocalizedStringResource="Start bedtime"
    static var description=IntentDescription("Save a bedtime start time in Lotus Sleep.")
    static var openAppWhenRun=true
    @MainActor func perform() async throws -> some IntentResult {
        let store=AppStore.shared
        guard !store.isDemo else { throw LumaError.unavailable("Exit demo mode first.") }
        try store.transact { try SessionActions.start(snapshot:&$0,at:store.now,zone:TimeZone.current.identifier,kind:.main) }
        store.selectedTab=1
        return .result()
    }
}
struct EndBedtimeIntent:AppIntent {
    static var title:LocalizedStringResource="End bedtime"
    static var description=IntentDescription("End time in bed and open your morning review.")
    static var openAppWhenRun=true
    @MainActor func perform() async throws -> some IntentResult {
        let store=AppStore.shared
        guard !store.isDemo else { throw LumaError.unavailable("Exit demo mode first.") }
        var id:UUID?
        try store.transact { id=try SessionActions.end(snapshot:&$0,at:store.now) }
        store.audio.stop(reason:"Ended using Shortcuts"); store.pendingReviewID=id; store.selectedTab=1
        return .result()
    }
}
struct LogNapIntent:AppIntent {
    static var title:LocalizedStringResource="Log a nap"
    static var description=IntentDescription("Record a reported nap ending now. The duration is your estimate.")
    static var openAppWhenRun=true
    @Parameter(title:"Minutes",default:20) var minutes:Int
    @MainActor func perform() async throws -> some IntentResult {
        guard (1...240).contains(minutes) else { throw LumaError.invalid("Use 1–240 minutes.") }
        let store=AppStore.shared
        guard !store.isDemo else { throw LumaError.unavailable("Exit demo mode first.") }
        let end=store.now, start=end.addingTimeInterval(-Double(minutes)*60)
        var version=DiaryVersion(bedtime:start,sleepStart:start,wake:end,outOfBed:end,timeZoneID:TimeZone.current.identifier)
        version.kind = .nap; try store.saveDiary(version); store.selectedTab=2
        return .result()
    }
}
struct LumaShortcuts:AppShortcutsProvider {
    static var appShortcuts:[AppShortcut] {
        AppShortcut(intent:StartBedtimeIntent(),phrases:["Start bedtime in \(.applicationName)"],shortTitle:"Start bedtime",systemImageName:"moon.zzz")
        AppShortcut(intent:EndBedtimeIntent(),phrases:["End bedtime in \(.applicationName)"],shortTitle:"I'm awake",systemImageName:"sun.max")
        AppShortcut(intent:LogNapIntent(),phrases:["Log a nap in \(.applicationName)"],shortTitle:"Log a nap",systemImageName:"sun.haze")
    }
}
