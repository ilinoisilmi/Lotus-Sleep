import XCTest
@testable import LumaCore

final class NightReviewTests:XCTestCase {
    let start=Date(timeIntervalSince1970:1_700_000_000)
    func testV2MigrationPreservesExistingSleepAndStartsEmptyWakeLog() throws {
        var old=Snapshot()
        old.diaries=[DiaryEntry(version:DiaryVersion(bedtime:start,sleepStart:start,wake:start.addingTimeInterval(8*3600),outOfBed:start.addingTimeInterval(8*3600),timeZoneID:"UTC"))]
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:SnapshotCodec.encode(old)) as? [String:Any])
        json["schemaVersion"]=2; json.removeValue(forKey:"disturbances")
        let result=try SnapshotCodec.decode(JSONSerialization.data(withJSONObject:json))
        XCTAssertEqual(result.schemaVersion,5); XCTAssertEqual(result.diaries.count,1)
        XCTAssertEqual(result.diaries[0].id,old.diaries[0].id); XCTAssertTrue(result.disturbances.isEmpty)
    }
    func testLiveWakePersistsAndRepeatedTapDoesNotDuplicate() throws {
        var snapshot=Snapshot()
        try SessionActions.start(snapshot:&snapshot,at:start,zone:"UTC",kind:.main)
        let id=DisturbanceActions.start(snapshot:&snapshot,at:start.addingTimeInterval(3600))
        XCTAssertEqual(DisturbanceActions.start(snapshot:&snapshot,at:start.addingTimeInterval(3601)),id)
        let loaded=try SnapshotCodec.decode(SnapshotCodec.encode(snapshot))
        XCTAssertEqual(loaded.disturbances.count,1); XCTAssertNil(loaded.disturbances[0].end)
        XCTAssertEqual(loaded.disturbances[0].sessionID,loaded.activeSession?.id)
        XCTAssertTrue(loaded.effectiveRecords.isEmpty,"An unfinished timer or wake-up must not invent sleep.")
    }
    func testFinishWakeDoesNotEndBedtimeAndDoesNotInventSleep() throws {
        var snapshot=Snapshot()
        try SessionActions.start(snapshot:&snapshot,at:start,zone:"UTC",kind:.main)
        let id=DisturbanceActions.start(snapshot:&snapshot,at:start.addingTimeInterval(3600))
        try DisturbanceActions.finish(snapshot:&snapshot,id:id,at:start.addingTimeInterval(4200))
        XCTAssertNotNil(snapshot.activeSession); XCTAssertTrue(snapshot.effectiveRecords.isEmpty)
        XCTAssertEqual(snapshot.disturbances[0].end,start.addingTimeInterval(4200))
    }
    func testEndingBedtimeClosesItsWakeLogForAllCallers() throws {
        var snapshot=Snapshot()
        try SessionActions.start(snapshot:&snapshot,at:start,zone:"UTC",kind:.main)
        DisturbanceActions.start(snapshot:&snapshot,at:start.addingTimeInterval(3600))
        try SessionActions.end(snapshot:&snapshot,at:start.addingTimeInterval(7200))
        XCTAssertNil(snapshot.activeSession)
        XCTAssertEqual(snapshot.disturbances[0].end,start.addingTimeInterval(7200))
        XCTAssertNil(snapshot.diaries[0].current.sleepStart)
    }
    func testReviewWakeIntervalsMergeClipAndIgnoreOpenLogs() {
        let entries=[SleepDisturbance(start:start.addingTimeInterval(-100),end:start.addingTimeInterval(300)),SleepDisturbance(start:start.addingTimeInterval(200),end:start.addingTimeInterval(700)),SleepDisturbance(start:start.addingTimeInterval(800))]
        let result=DisturbanceActions.intervals(entries,sleepStart:start,wake:start.addingTimeInterval(600))
        XCTAssertEqual(result.count,1); XCTAssertEqual(result[0].start,start); XCTAssertEqual(result[0].end,start.addingTimeInterval(600))
    }
    func testIncludedWakeTimeReducesDiarySleepOnlyOnce() {
        var diary=DiaryVersion(bedtime:start,sleepStart:start,wake:start.addingTimeInterval(8*3600),outOfBed:start.addingTimeInterval(8*3600),timeZoneID:"UTC")
        let wake=SleepDisturbance(start:start.addingTimeInterval(3600),end:start.addingTimeInterval(5400))
        diary.awakenings=DisturbanceActions.intervals([wake,wake],sleepStart:start,wake:diary.wake)
        XCTAssertEqual(SleepReconciler.resolve(diary.records(diaryID:UUID()),priority:[]).asleepSeconds,7.5*3600)
    }
    func testInvalidWakeIntervalsAndDuplicateOpenLogsRejected() throws {
        XCTAssertThrowsError(try SleepDisturbance(start:start,end:start).validate())
        XCTAssertThrowsError(try SleepDisturbance(start:start,end:start.addingTimeInterval(49*3600)).validate())
        var s=Snapshot();s.disturbances=[SleepDisturbance(start:start),SleepDisturbance(start:start.addingTimeInterval(30))]
        XCTAssertThrowsError(try SnapshotCodec.validate(s))
    }
    func testSubsecondWakeCannotBecomeAnInvalidWholeSecondBackup() {
        let entry=SleepDisturbance(start:start.addingTimeInterval(0.1),end:start.addingTimeInterval(0.4))
        XCTAssertThrowsError(try entry.validate())
    }
    func testMissingDataAndQualityOverride() {
        XCTAssertEqual(NightReview.rating(hours:nil,target:9,quality:1),.unlogged)
        XCTAssertEqual(NightReview.rating(hours:9,target:9,quality:2),.attention)
        XCTAssertEqual(NightReview.rating(hours:8.5,target:9,quality:4),.good)
        XCTAssertEqual(NightReview.rating(hours:8,target:9,quality:nil),.mixed)
        XCTAssertEqual(NightReview.rating(hours:7.9,target:9,quality:nil),.attention)
    }
    func testQuickDurationDoesNotInventBedtimeOrEfficiency() {
        var entry=DiaryVersion(bedtime:start,sleepStart:start,wake:start.addingTimeInterval(8*3600),outOfBed:start.addingTimeInterval(8*3600),timeZoneID:"UTC")
        entry.includesInBedEvidence=false
        let result=SleepReconciler.resolve(entry.records(diaryID:UUID()),priority:[])
        XCTAssertEqual(result.asleepSeconds,8*3600)
        XCTAssertEqual(result.inBedSeconds,0); XCTAssertNil(result.efficiency)
    }
    func testSoundCalibrationIgnoresStableFan() {
        var detector=SoundEventDetector()
        for i in 0..<400 { XCTAssertNil(detector.consume(levelDB:-35,offset:Double(i)*0.1,duration:0.1)) }
        XCTAssertNil(detector.finish())
    }
    func testShortSoundHasAudioFrameOffsetAndEndsAfterQuiet() throws {
        var detector=SoundEventDetector()
        for i in 0..<60 { _=detector.consume(levelDB:-65,offset:Double(i)*0.1,duration:0.1) }
        for i in 60..<66 { _=detector.consume(levelDB:-20,offset:Double(i)*0.1,duration:0.1) }
        var result:DetectedSound?
        for i in 66..<78 { if let event=detector.consume(levelDB:-65,offset:Double(i)*0.1,duration:0.1) { result=event } }
        let event=try XCTUnwrap(result)
        XCTAssertEqual(event.offset,6,accuracy:0.001); XCTAssertEqual(event.duration,0.6,accuracy:0.001)
        XCTAssertEqual(event.peakDB,-20); XCTAssertNil(detector.finish())
    }
    func testTransientIsDiscardedAndLastEventFlushesOnStop() throws {
        var detector=SoundEventDetector()
        for i in 0..<60 { _=detector.consume(levelDB:-65,offset:Double(i)*0.1,duration:0.1) }
        _=detector.consume(levelDB:-20,offset:6,duration:0.1)
        for i in 61..<75 { XCTAssertNil(detector.consume(levelDB:-65,offset:Double(i)*0.1,duration:0.1)) }
        _=detector.consume(levelDB:-20,offset:8,duration:0.5)
        XCTAssertEqual(try XCTUnwrap(detector.finish()).duration,0.5,accuracy:0.001)
        XCTAssertNil(detector.finish())
    }
    func testLongNoiseIsBoundedIntoReplayableEvents() {
        var detector=SoundEventDetector();var result:[DetectedSound]=[]
        for i in 0..<60 { _=detector.consume(levelDB:-65,offset:Double(i)*0.1,duration:0.1) }
        for i in 60..<760 { if let event=detector.consume(levelDB:-20,offset:Double(i)*0.1,duration:0.1) { result.append(event) } }
        if let event=detector.finish() { result.append(event) }
        XCTAssertEqual(result.count,3); XCTAssertTrue(result.allSatisfy{$0.duration <= 30.11})
        XCTAssertEqual(result.reduce(0){$0+$1.duration},70,accuracy:0.01)
    }
    func testLegacySoundEventsDecodeWithoutReplayOffset() throws {
        let json=Data("{\"id\":\"11111111-1111-1111-1111-111111111111\",\"date\":\"2026-11-10T01:00:00Z\",\"duration\":3,\"peakDB\":-20}".utf8)
        XCTAssertNil(try SnapshotCodec.decoder().decode(SoundEvent.self,from:json).recordingOffset)
    }
}
