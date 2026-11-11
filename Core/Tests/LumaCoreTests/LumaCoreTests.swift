import XCTest
@testable import LumaCore
final class LumaCoreTests: XCTestCase {
    func d(_ s:String) -> Date { SleepLogFormat.date(s)! }
    func r(_ id:String,_ start:String,_ end:String,_ stage:SleepStage = .asleep,_ source:String = "watch",_ kind:SleepKind = .main) -> SleepRecord {
        SleepRecord(id:id,sourceID:source,sourceName:source,method:.health,start:d(start),end:d(end),timeZoneID:"Europe/Skopje",stage:stage,kind:kind,quality:.wearable)
    }
    func testOverlapNeverDoubleCounts() {
        let a=r("a","2026-01-01T22:00:00Z","2026-01-02T06:00:00Z")
        let b=r("b","2026-01-01T23:00:00Z","2026-01-02T05:00:00Z",.deep,"ring")
        XCTAssertEqual(SleepReconciler.resolve([a,b],priority:["watch","ring"]).asleepSeconds,8*3600)
    }
    func testSourcePriorityAndAwake() {
        let a=r("a","2026-01-01T22:00:00Z","2026-01-02T06:00:00Z")
        let b=r("b","2026-01-02T01:00:00Z","2026-01-02T02:00:00Z",.awake,"diary")
        XCTAssertEqual(SleepReconciler.resolve([a,b],priority:["diary","watch"]).asleepSeconds,7*3600)
        XCTAssertEqual(SleepReconciler.resolve([a,b],priority:["watch","diary"]).asleepSeconds,8*3600)
    }
    func testSameSourceAwakeBeatsGenericAsleep() {
        let a=r("a","2026-01-01T22:00:00Z","2026-01-02T06:00:00Z")
        let b=r("b","2026-01-02T01:00:00Z","2026-01-02T02:00:00Z",.awake)
        XCTAssertEqual(SleepReconciler.resolve([a,b],priority:[]).asleepSeconds,7*3600)
    }
    func testMidnightAndUnknownGap() {
        let a=r("a","2026-01-01T23:00:00Z","2026-01-02T02:00:00Z")
        let b=r("b","2026-01-02T03:00:00Z","2026-01-02T06:00:00Z")
        XCTAssertEqual(SleepReconciler.resolve([a,b],priority:[]).asleepSeconds,6*3600)
        XCTAssertEqual(SleepReconciler.resolve([a,b],priority:[]).segments.count,2)
    }
    func testSpringDSTUsesElapsedTime() {
        let a=r("a","2026-03-29T01:00:00+01:00","2026-03-29T04:00:00+02:00")
        XCTAssertEqual(SleepReconciler.resolve([a],priority:[]).asleepSeconds,7200)
    }
    func testFallDSTUsesElapsedTime() {
        let a=r("a","2026-10-25T01:00:00+02:00","2026-10-25T04:00:00+01:00")
        XCTAssertEqual(SleepReconciler.resolve([a],priority:[]).asleepSeconds,4*3600)
    }
    func testTravelOffsets() {
        let a=r("a","2026-06-01T22:00:00+02:00","2026-06-02T07:00:00+05:00")
        XCTAssertEqual(SleepReconciler.resolve([a],priority:[]).asleepSeconds,6*3600)
    }
    func testCalendarDSTDayIsNotAssumed24Hours() {
        let c=SleepCalendar.calendar(zoneID:"Europe/Skopje")
        let window=SleepCalendar.window(endingOn:d("2026-03-29T12:00:00+02:00"),calendar:c,boundaryHour:18)
        XCTAssertEqual(window.duration,23*3600)
    }
    func testMissingNightsRemainUnknown() {
        var p=Preferences(); p.reportingTimeZoneID="UTC"
        let a=r("a","2026-01-01T22:00:00Z","2026-01-02T06:00:00Z")
        let days=SleepCalendar.days(records:[a],endingOn:d("2026-01-02T12:00:00Z"),count:14,preferences:p)
        let shortfall=SleepInsights.shortfall(days:days,target:9)
        XCTAssertEqual(shortfall.hours,1); XCTAssertEqual(shortfall.observedDays,1)
        XCTAssertEqual(days.filter{$0.hours == nil}.count,13)
    }
    func testNapsCountOnceInSleepDay() {
        var p=Preferences(); p.reportingTimeZoneID="UTC"
        let a=r("a","2026-01-01T22:00:00Z","2026-01-02T06:00:00Z")
        let b=r("b","2026-01-02T14:00:00Z","2026-01-02T15:00:00Z",.asleep,"diary",.nap)
        let day=SleepCalendar.days(records:[a,b],endingOn:d("2026-01-02T16:00:00Z"),count:1,preferences:p)[0]
        XCTAssertEqual(day.hours,9); XCTAssertEqual(day.napHours,1)
        XCTAssertEqual(SleepInsights.shortfall(days:[day],target:9).hours,0)
    }
    func testExtraSleepDoesNotRepayOtherDays() {
        var p=Preferences(); p.reportingTimeZoneID="UTC"
        let a=r("a","2026-01-01T22:00:00Z","2026-01-02T04:00:00Z")
        let b=r("b","2026-01-02T20:00:00Z","2026-01-03T08:00:00Z")
        let days=SleepCalendar.days(records:[a,b],endingOn:d("2026-01-03T12:00:00Z"),count:2,preferences:p)
        XCTAssertEqual(SleepInsights.shortfall(days:days,target:9).hours,3)
    }
    func testEfficiencyRequiresBedEvidence() {
        let a=r("a","2026-01-01T23:00:00Z","2026-01-02T06:00:00Z")
        XCTAssertNil(SleepReconciler.resolve([a],priority:[]).efficiency)
        let bed=r("bed","2026-01-01T22:00:00Z","2026-01-02T06:00:00Z",.inBed)
        XCTAssertEqual(SleepReconciler.resolve([a,bed],priority:[]).efficiency!,7.0/8,accuracy:0.0001)
    }
    func testBedtimeSurvivesSerializationAndEndIsNotSleep() throws {
        var s=Snapshot()
        try SessionActions.start(snapshot:&s,at:d("2026-01-01T22:00:00Z"),zone:"Europe/Skopje",kind:.main)
        s=try SnapshotCodec.decode(SnapshotCodec.encode(s))
        XCTAssertEqual(s.activeSession?.startedAt,d("2026-01-01T22:00:00Z"))
        try SessionActions.end(snapshot:&s,at:d("2026-01-02T06:00:00Z"))
        XCTAssertNil(s.activeSession); XCTAssertNil(s.diaries[0].current.sleepStart)
        XCTAssertEqual(SleepReconciler.resolve(s.effectiveRecords,priority:[]).asleepSeconds,0)
    }
    func testDuplicateSessionStartRejected() throws {
        var s=Snapshot(); try SessionActions.start(snapshot:&s,at:Date(),zone:"UTC",kind:.nap)
        XCTAssertThrowsError(try SessionActions.start(snapshot:&s,at:Date(),zone:"UTC",kind:.main))
    }
    func testRepeatImportAndRoundTrip() throws {
        let p=try SleepLogFormat.preview(SleepLogFormat.exampleCSV(),format:"csv",existing:[])
        XCTAssertEqual(p.accepted.count,1)
        let repeated=try SleepLogFormat.preview(SleepLogFormat.exampleCSV(),format:"csv",existing:p.accepted)
        XCTAssertEqual(repeated.duplicates,1); XCTAssertTrue(repeated.accepted.isEmpty)
        let out=SleepLogFormat.exportCSV(p.accepted)
        let restored=try SleepLogFormat.preview(out,format:"csv",existing:[])
        XCTAssertEqual(restored.accepted,p.accepted)
    }
    func testJSONMatchesCSVExample() throws {
        XCTAssertEqual(try SleepLogFormat.preview(SleepLogFormat.exampleJSON(),format:"json",existing:[]).accepted,
                       try SleepLogFormat.preview(SleepLogFormat.exampleCSV(),format:"csv",existing:[]).accepted)
    }
    func testCSVQuotedNewlineAndEscapedQuote() throws {
        let rows=try SleepLogFormat.parseCSV("a,b\r\n\"two\nlines\",\"say \"\"hi\"\"\"\r\n")
        XCTAssertEqual(rows,[["a","b"],["two\nlines","say \"hi\""]])
        XCTAssertThrowsError(try SleepLogFormat.parseCSV("\"broken"))
    }
    func testInvalidRowsAreReportedAndNotImported() throws {
        let s=String(data:SleepLogFormat.exampleCSV(),encoding:.utf8)!.replacingOccurrences(of:"2026-11-01T23:00:00+01:00",with:"2026-11-01T23:00:00")
        let result=try SleepLogFormat.preview(Data(s.utf8),format:"csv",existing:[])
        XCTAssertEqual(result.rejected.count,1); XCTAssertTrue(result.accepted.isEmpty)
    }
    func testChangedImportIDRejected() throws {
        let a=try SleepLogFormat.preview(SleepLogFormat.exampleCSV(),format:"csv",existing:[])
        let changed=String(data:SleepLogFormat.exampleCSV(),encoding:.utf8)!.replacingOccurrences(of:"07:30",with:"08:30")
        let b=try SleepLogFormat.preview(Data(changed.utf8),format:"csv",existing:a.accepted)
        XCTAssertEqual(b.rejected.count,1)
    }
    func testCorrectionCanBeUndoneWithoutChangingOriginal() {
        var s=Snapshot(); let original=r("a","2026-01-01T22:00:00Z","2026-01-02T06:00:00Z"); s.records=[original]
        let replacement=r("b","2026-01-01T23:00:00Z","2026-01-02T06:00:00Z",.asleep,"correction")
        s.corrections.append(Correction(originalIDs:[original.id],replacements:[replacement],reason:"Morning review"))
        XCTAssertEqual(s.effectiveRecords,[replacement]); XCTAssertEqual(s.records,[original])
        s.corrections[0].isUndone=true; XCTAssertEqual(s.effectiveRecords,[original])
    }
    func testDeletedHealthRecordExcluded() {
        var s=Snapshot(); s.records=[r("health:a","2026-01-01T22:00:00Z","2026-01-02T06:00:00Z")]
        s.deletedSourceIDs.insert("health:a"); XCTAssertTrue(s.effectiveRecords.isEmpty); XCTAssertEqual(s.records.count,1)
    }
    func testAtomicStorageRoundTrip() throws {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("sleep.json")
        defer { try? FileManager.default.removeItem(at:url.deletingLastPathComponent()) }
        let store=JSONSnapshotStore(url:url); var s=Snapshot(); s.preferences.targetHours=8.5
        try store.save(s); XCTAssertEqual(try store.load().preferences.targetHours,8.5)
        s.preferences.targetHours = -1; XCTAssertThrowsError(try store.save(s)); XCTAssertEqual(try store.load().preferences.targetHours,8.5)
    }
    func testMigrationFromV1() throws {
        let data=Data(#"{"schemaVersion":1,"records":[],"preferences":{"targetHours":8}}"#.utf8)
        let s=try SnapshotCodec.decode(data)
        XCTAssertEqual(s.schemaVersion,5); XCTAssertEqual(s.preferences.targetHours,8); XCTAssertTrue(s.corrections.isEmpty)
    }
    func testFutureVersionRejected() { XCTAssertThrowsError(try SnapshotCodec.decode(Data(#"{"schemaVersion":99}"#.utf8))) }
    func testCircularRegularityAcrossMidnight() {
        let dates=[d("2026-01-01T23:50:00Z"),d("2026-01-02T00:00:00Z"),d("2026-01-03T00:10:00Z")]
        XCTAssertLessThan(SleepInsights.timingVariation(wakeDates:dates,calendar:SleepCalendar.calendar(zoneID:"UTC"))!,10)
    }
    func testEnergyRequiresData() { XCTAssertTrue(SleepInsights.energy(wake:Date(),days:[],target:9,checkIns:[]).isEmpty) }
    func testPlannerAccountsForWindDownAndSettling() {
        let p=Preferences(), wake=d("2026-01-02T07:00:00Z")
        let plan=SleepPlanner.plan(wake:wake,preferences:p)
        XCTAssertEqual(wake.timeIntervalSince(plan.bedtime),9*3600+20*60)
        XCTAssertEqual(plan.bedtime.timeIntervalSince(plan.windDown),45*60)
    }
    func testSplitSleepAndOverlappingAwakenings() throws {
        var v=DiaryVersion(bedtime:d("2026-01-01T22:00:00Z"),sleepStart:d("2026-01-01T23:00:00Z"),wake:d("2026-01-02T06:00:00Z"),outOfBed:d("2026-01-02T06:15:00Z"),timeZoneID:"UTC")
        v.awakenings=[AwakeInterval(start:d("2026-01-02T02:00:00Z"),end:d("2026-01-02T03:00:00Z")),AwakeInterval(start:d("2026-01-02T02:30:00Z"),end:d("2026-01-02T03:30:00Z"))]
        try v.validate()
        XCTAssertEqual(SleepReconciler.resolve(v.records(diaryID:UUID()),priority:[]).asleepSeconds,5.5*3600)
    }
}
