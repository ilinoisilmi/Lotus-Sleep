import XCTest
@testable import LumaCore

final class SleepExperiencesTests:XCTestCase {
    private func date(_ value:String)->Date { ISO8601DateFormatter().date(from:value)! }
    private var now:Date { date("2026-11-11T12:00:00Z") }
    private func snapshot()->Snapshot { var s=Snapshot();s.preferences.reportingTimeZoneID="UTC";s.preferences.targetHours=8;return s }
    private func addNight(_ day:Int,hours:Double=8,quality:Int?=nil,to s:inout Snapshot,kind:SleepKind = .main) {
        let wake=date(String(format:"2026-11-%02dT07:00:00Z",day))
        let start=wake.addingTimeInterval(-hours*3600)
        var v=DiaryVersion(bedtime:start,sleepStart:start,wake:wake,outOfBed:wake,timeZoneID:"UTC");v.qualityRating=quality;v.kind=kind
        s.diaries.append(DiaryEntry(version:v))
    }
    private func experiment(zone:String="UTC",start:String="2026-11-01T00:00:00Z")->SleepExperiment {
        SleepExperiment(title:"Room sound",optionA:"Quiet",optionB:"Soft rain",startDay:date(start),timeZoneID:zone,boundaryHour:18)
    }
    func testV4MigrationPreservesAllExistingDataAndStartsEmptyFeatures() throws {
        var s=snapshot();addNight(10,to:&s);s.profile=SleepProfile();s.caffeineEntries=[CaffeineEntry(date:now,milligrams:40,label:"Tea")]
        let soundID=UUID();s.customSounds=[CustomSleepSound(id:soundID,name:"Rain",fileName:soundID.uuidString+".mp3",duration:30)]
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:SnapshotCodec.encode(s)) as? [String:Any]);json["schemaVersion"]=4
        for key in ["soundBlends","experiments","companions","morningTasks"] { json.removeValue(forKey:key) }
        let loaded=try SnapshotCodec.decode(JSONSerialization.data(withJSONObject:json))
        XCTAssertEqual(loaded.schemaVersion,5);XCTAssertEqual(loaded.diaries.first?.id,s.diaries.first?.id);XCTAssertEqual(loaded.customSounds.first?.id,soundID)
        XCTAssertNotNil(loaded.profile);XCTAssertEqual(loaded.caffeineEntries.first?.milligrams,40)
        XCTAssertTrue(loaded.soundBlends.isEmpty && loaded.experiments.isEmpty && loaded.companions.awards.isEmpty && loaded.morningTasks.isEmpty)
    }
    func testNewExperiencesRoundTripIncludingMissingCustomReference() throws {
        var s=snapshot();let missing=UUID()
        s.soundBlends=[SoundBlend(name:"My room",layers:[SoundLayer(source:.builtIn("rain")),SoundLayer(source:.custom(missing))])]
        s.experiments=[experiment()];s.morningTasks=[MorningTask(text:"Bring charger",createdAt:now,remindAt:now.addingTimeInterval(3600))]
        addNight(11,to:&s);RestStreak.celebrate(snapshot:&s,now:now)
        let loaded=try SnapshotCodec.decode(SnapshotCodec.encode(s))
        XCTAssertEqual(loaded.soundBlends[0].layers[1].source,.custom(missing));XCTAssertEqual(loaded.experiments[0].id,s.experiments[0].id)
        XCTAssertEqual(loaded.morningTasks[0].text,"Bring charger");XCTAssertEqual(loaded.companions.awards.count,1)
    }
    func testMixGainNormalizationAndFadeNeverExceedMaster() {
        let layers=["rain","brown","fan"].map{SoundLayer(source:.builtIn($0),volume:1)}
        let gains=SoundBlend.gains(layers:layers,master:0.6,fade:0.5)
        XCTAssertEqual(gains.reduce(0,+),0.3,accuracy:0.0001);XCTAssertEqual(gains[0],0.1,accuracy:0.0001)
        XCTAssertEqual(SoundBlend.gains(layers:layers,master:0,fade:1),[0,0,0])
    }
    func testMixKeepsQuietSingleLayerQuiet() {
        XCTAssertEqual(SoundBlend.gains(layers:[SoundLayer(source:.builtIn("rain"),volume:0.1)],master:0.5,fade:1)[0],0.05,accuracy:0.0001)
    }
    func testMixRejectsDuplicateEmptySilentAndExcessLayers() {
        let one=SoundLayer(source:.builtIn("rain"))
        for layers in [[],[one,one],SleepSoundSource.builtInIDs.prefix(4).map{SoundLayer(source:.builtIn($0))},[SoundLayer(source:.builtIn("rain"),volume:0)]] {
            XCTAssertThrowsError(try SoundBlend(name:"Mix",layers:layers).validate())
        }
    }
    func testMixRejectsUnknownSoundAndNonfiniteVolume() {
        for layer in [SoundLayer(source:.builtIn("fake")),SoundLayer(source:.builtIn("rain"),volume:.nan),SoundLayer(source:.builtIn("rain"),volume:1.1)] {
            XCTAssertThrowsError(try SoundBlend(name:"Mix",layers:[layer]).validate())
        }
        var blend=SoundBlend(name:"Mix",layers:[SoundLayer(source:.builtIn("rain"))]);blend.timerMinutes=9
        XCTAssertThrowsError(try blend.validate())
    }
    func testBalancedExperimentHasSevenOfEach() {
        let e=experiment();XCTAssertEqual((0..<14).filter{e.planned($0) == .a}.count,7);XCTAssertEqual((0..<14).filter{e.planned($0) == .b}.count,7)
    }
    func testExperimentRejectsFutureAndArchivedEditsWithoutMutation() throws {
        var e=experiment()
        XCTAssertThrowsError(try e.log(ExperimentNight(dayIndex:11,condition:.a,rested:4),at:now));XCTAssertTrue(e.nights.isEmpty)
        e.archived=true;XCTAssertThrowsError(try e.log(ExperimentNight(dayIndex:0,condition:.a,rested:4),at:now))
    }
    func testMorningReportUpsertsAndRequiresRatingOrSkip() throws {
        var e=experiment();try e.log(ExperimentNight(dayIndex:0,condition:.a,rested:4),at:now)
        try e.log(ExperimentNight(dayIndex:0,condition:.b,rested:3),at:now)
        XCTAssertEqual(e.nights.count,1);XCTAssertEqual(e.nights[0].condition,.b)
        XCTAssertThrowsError(try e.log(ExperimentNight(dayIndex:1,condition:.a,rested:nil),at:now))
        XCTAssertThrowsError(try e.log(ExperimentNight(dayIndex:1,condition:.skipped,rested:3),at:now))
        try e.log(ExperimentNight(dayIndex:1,condition:.skipped,rested:nil),at:now);XCTAssertEqual(e.nights.count,2)
    }
    func testComparisonUsesActualConditionAndExcludesMissingAndSkipped() throws {
        var e=experiment(),s=snapshot()
        for index in 0..<6 { try e.log(ExperimentNight(dayIndex:index,condition:index < 3 ? .b : .a,rested:index < 3 ? 5 : 2),at:now) }
        try e.log(ExperimentNight(dayIndex:6,condition:.skipped,rested:nil),at:now)
        addNight(1,hours:7,to:&s)
        let c=ExperimentComparison.calculate(e,snapshot:s,now:now)
        XCTAssertTrue(c.ready);XCTAssertEqual(c.a.count,3);XCTAssertEqual(c.b.meanRested,5);XCTAssertEqual(c.a.meanRested,2);XCTAssertEqual(c.skipped,1)
        XCTAssertEqual(c.b.sleepCount,1);XCTAssertEqual(c.b.meanSleepHours,7);XCTAssertNil(c.a.meanSleepHours)
    }
    func testComparisonDoesNotBecomeReadyWithOnlyTwoOfOneOption() throws {
        var e=experiment()
        for i in 0..<5 { try e.log(ExperimentNight(dayIndex:i,condition:i < 2 ? .a : .b,rested:4),at:now) }
        XCTAssertFalse(ExperimentComparison.calculate(e,snapshot:snapshot(),now:now).ready)
    }
    func testExperimentDatesSurviveDSTAndReportingTimezoneChanges() throws {
        var e=experiment(zone:"Europe/Skopje",start:"2026-10-24T00:00:00Z")
        XCTAssertEqual(e.day(2).timeIntervalSince(e.day(1)),25*3600)
        XCTAssertEqual(e.availableIndex(at:date("2026-10-23T21:00:00Z")),-1)
        try e.log(ExperimentNight(dayIndex:2,condition:.a,rested:4),at:now)
        var s=snapshot();s.preferences.reportingTimeZoneID="Pacific/Honolulu"
        XCTAssertEqual(ExperimentComparison.calculate(e,snapshot:s,now:now).a.count,1)
    }
    func testSnapshotRejectsMultipleActiveExperiments() {
        var s=snapshot();s.experiments=[experiment(),experiment()];XCTAssertThrowsError(try SnapshotCodec.validate(s))
        s.experiments[1].archived=true;XCTAssertNoThrow(try SnapshotCodec.validate(s))
    }
    func testThreeGoodNightsAndUnfinishedCurrentDayKeepStreak() {
        var s=snapshot();for day in 8...10 { addNight(day,quality:4,to:&s) }
        let result=RestStreak.summary(snapshot:s,now:now)
        XCTAssertEqual(result.current,3);XCTAssertEqual(result.best,3);XCTAssertEqual(result.dayKey,"2026-11-10");XCTAssertFalse(result.waitingForLog)
    }
    func testClosedUnloggedDayRequiresVerification() {
        var s=snapshot();for day in 8...10 { addNight(day,to:&s) }
        let result=RestStreak.summary(snapshot:s,now:date("2026-11-11T19:00:00Z"))
        XCTAssertEqual(result.current,0);XCTAssertEqual(result.best,3);XCTAssertTrue(result.waitingForLog);XCTAssertNil(result.dayKey)
    }
    func testPoorRatedNightBreaksClosedStreakButDoesNotRemoveAppearance() {
        var s=snapshot();for day in 8...10 { addNight(day,to:&s) }
        RestStreak.celebrate(snapshot:&s,now:now);XCTAssertEqual(s.companions.stage(for:.bunny),1)
        addNight(11,quality:2,to:&s)
        let result=RestStreak.summary(snapshot:s,now:date("2026-11-11T19:00:00Z"))
        XCTAssertEqual(result.current,0);XCTAssertFalse(result.waitingForLog);XCTAssertEqual(s.companions.stage(for:.bunny),1)
    }
    func testFutureSleepCannotEarnCurrentDay() {
        var s=snapshot();addNight(12,to:&s)
        XCTAssertEqual(RestStreak.summary(snapshot:s,now:now).current,0)
        XCTAssertFalse(RestStreak.celebrate(snapshot:&s,now:now))
    }
    func testNapsContributeButNapQualityDoesNotOverrideMainNight() {
        var s=snapshot();addNight(11,hours:7,quality:5,to:&s)
        let start=date("2026-11-11T10:00:00Z")
        var nap=DiaryVersion(bedtime:start,sleepStart:start,wake:start.addingTimeInterval(3600),outOfBed:start.addingTimeInterval(3600),timeZoneID:"UTC");nap.kind = .nap;nap.qualityRating=1;s.diaries.append(DiaryEntry(version:nap))
        XCTAssertEqual(RestStreak.summary(snapshot:s,now:now).current,1)
    }
    func testPetSwitchAndRelaunchCannotCreditSameSleepDayTwice() throws {
        var s=snapshot();for day in 8...10 { addNight(day,to:&s) }
        XCTAssertTrue(RestStreak.celebrate(snapshot:&s,now:now));s.companions.selected = .fox
        XCTAssertFalse(RestStreak.celebrate(snapshot:&s,now:now));XCTAssertEqual(s.companions.stage(for:.fox),0)
        s=try SnapshotCodec.decode(SnapshotCodec.encode(s));XCTAssertFalse(RestStreak.celebrate(snapshot:&s,now:now))
        addNight(11,to:&s);XCTAssertTrue(RestStreak.celebrate(snapshot:&s,now:now));XCTAssertEqual(s.companions.stage(for:.fox),1)
        XCTAssertEqual(s.companions.awards.count,2)
    }
    func testAllFivePetStagesUseStoredPersonalAwards() throws {
        var state=CompanionState()
        for (i,milestone) in CompanionState.milestones.enumerated() {
            if milestone>0 { state.awards.append(PetAward(dayKey:String(format:"2026-11-%02d",i),pet:.otter,streak:milestone,earnedAt:now)) }
            XCTAssertEqual(state.stage(for:.otter),i);XCTAssertEqual(state.stage(for:.kitten),0)
        }
        XCTAssertNoThrow(try state.validate())
    }
    func testRewindClipsEvidenceAndKeepsSourcesAndUnknownGaps() {
        var s=snapshot();let start=date("2026-11-10T22:00:00Z"),end=date("2026-11-11T08:00:00Z")
        s.records=[SleepRecord(id:"watch",sourceID:"watch",sourceName:"My watch",method:.health,start:start.addingTimeInterval(-3600),end:start.addingTimeInterval(2*3600),timeZoneID:"UTC",stage:.deep,quality:.wearable)]
        let items=NightRewind.items(snapshot:s,window:DateInterval(start:start,end:end),now:now)
        XCTAssertEqual(items.first{$0.kind == .sleep}?.start,start);XCTAssertTrue(items.first{$0.kind == .sleep}?.detail.contains("My watch") ?? false)
        XCTAssertEqual(items.first{$0.kind == .unknown}?.start,start.addingTimeInterval(7200));XCTAssertEqual(items.first{$0.kind == .unknown}?.end,end)
    }
    func testSoundDoesNotFillUnknownSleepAndHasDirectReplayIdentifiers() {
        var s=snapshot();let start=now.addingTimeInterval(-3600)
        var audio=AudioSession(start:start);let event=SoundEvent(date:start.addingTimeInterval(20),duration:5,peakDB:-15);audio.events=[event];s.audioSessions=[audio]
        let items=NightRewind.items(snapshot:s,window:DateInterval(start:start,end:now),now:now)
        XCTAssertEqual(items.filter{$0.kind == .sleep}.count,0);XCTAssertEqual(items.first{$0.kind == .unknown}?.end,now)
        XCTAssertEqual(items.first{$0.kind == .sound}?.sessionID,audio.id);XCTAssertEqual(items.first{$0.kind == .sound}?.eventID,event.id)
    }
    func testOpenWakeCrossingWindowNeverHasNegativeDuration() {
        var s=snapshot();let start=now.addingTimeInterval(-3600);s.disturbances=[SleepDisturbance(start:start.addingTimeInterval(-100))]
        let items=NightRewind.items(snapshot:s,window:DateInterval(start:start,end:now.addingTimeInterval(100)),now:now)
        XCTAssertTrue(items.allSatisfy{$0.end >= $0.start && $0.end <= now});XCTAssertEqual(items.first{$0.kind == .wake}?.start,start)
        XCTAssertTrue(items.first{$0.kind == .wake}?.detail.contains("End not recorded") ?? false)
    }
    func testInboxDueBoundaryAndCompletion() {
        var task=MorningTask(text:"Take charger",createdAt:now.addingTimeInterval(-100),remindAt:now)
        XCTAssertTrue(task.isDue(at:now));XCTAssertFalse(task.isDue(at:now.addingTimeInterval(-1)))
        task.completedAt=now;XCTAssertFalse(task.isDue(at:now));XCTAssertTrue(MorningInbox.active([task]).isEmpty)
    }
    func testInboxRejectsDuplicateBlankLongAndCompletedNotifications() {
        var task=MorningTask(text:"Note",createdAt:now,remindAt:now.addingTimeInterval(100))
        XCTAssertThrowsError(try MorningInbox.validate([task,task]))
        task.text="  ";XCTAssertThrowsError(try task.validate());task.text=String(repeating:"a",count:1001);XCTAssertThrowsError(try task.validate())
        task.text="Note";task.completedAt=now;task.notificationScheduled=true;XCTAssertThrowsError(try task.validate())
    }
    func testInboxLimitsPendingNotificationsWithoutLimitingUnscheduledNotes() {
        var tasks=(0..<21).map{MorningTask(text:"Note \($0)",createdAt:now,remindAt:now.addingTimeInterval(100))}
        XCTAssertNoThrow(try MorningInbox.validate(tasks))
        for i in tasks.indices { tasks[i].notificationScheduled=true }
        XCTAssertThrowsError(try MorningInbox.validate(tasks));tasks[0].notificationScheduled=false
        XCTAssertNoThrow(try MorningInbox.validate(tasks))
    }
    func testInboxExpiredFlagsClearAndUpcomingNotesStayScheduled() {
        var past=MorningTask(text:"Past",createdAt:now.addingTimeInterval(-100),remindAt:now),future=MorningTask(text:"Future",createdAt:now,remindAt:now.addingTimeInterval(100))
        past.notificationScheduled=true;future.notificationScheduled=true
        var tasks=[future,past];MorningInbox.clearExpired(&tasks,at:now)
        XCTAssertTrue(tasks[0].notificationScheduled);XCTAssertFalse(tasks[1].notificationScheduled)
        XCTAssertEqual(MorningInbox.active(tasks).map(\.text),["Past","Future"])
    }
}
