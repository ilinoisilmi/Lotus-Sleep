import XCTest
@testable import LumaCore

final class PersonalizationTests:XCTestCase {
    private func date(_ text:String)->Date { ISO8601DateFormatter().date(from:text)! }
    func testV3MigrationPreservesHistoryAndDoesNotInventProfileOrCaffeine() throws {
        var snapshot=Snapshot()
        let start=date("2026-11-10T22:00:00Z")
        snapshot.disturbances=[SleepDisturbance(start:start,end:start.addingTimeInterval(600))]
        snapshot.diaries=[DiaryEntry(version:DiaryVersion(bedtime:start,sleepStart:start,wake:start.addingTimeInterval(8*3600),outOfBed:start.addingTimeInterval(8*3600),timeZoneID:"UTC"))]
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:SnapshotCodec.encode(snapshot)) as? [String:Any])
        json["schemaVersion"]=3
        for key in ["profile","caffeineEntries","customSounds"] { json.removeValue(forKey:key) }
        let restored=try SnapshotCodec.decode(JSONSerialization.data(withJSONObject:json))
        XCTAssertEqual(restored.schemaVersion,5)
        XCTAssertEqual(restored.diaries.first?.id,snapshot.diaries.first?.id)
        XCTAssertEqual(restored.disturbances.first?.id,snapshot.disturbances.first?.id)
        XCTAssertNil(restored.profile);XCTAssertTrue(restored.caffeineEntries.isEmpty);XCTAssertTrue(restored.customSounds.isEmpty)
        XCTAssertNil(restored.preferences.reminderOptions)
    }
    func testProfileAndCaffeineRoundTrip() throws {
        var snapshot=Snapshot(),profile=SleepProfile()
        profile.workSleepMinutes=22*60+30;profile.personalCaffeineCapMG=150
        snapshot.profile=profile;snapshot.caffeineEntries=[CaffeineEntry(date:date("2026-11-11T10:00:00Z"),milligrams:80,label:"Tea")]
        let loaded=try SnapshotCodec.decode(SnapshotCodec.encode(snapshot))
        XCTAssertEqual(loaded.profile?.workSleepMinutes,1350);XCTAssertEqual(loaded.profile?.personalCaffeineCapMG,150)
        XCTAssertEqual(loaded.caffeineEntries.first?.milligrams,80)
    }
    func testInvalidProfileAnswersAndWindowsRejected() throws {
        var profile=SleepProfile();profile.reflectionScores=[];XCTAssertThrowsError(try profile.validate())
        profile=SleepProfile();profile.workWakeMinutes=profile.workSleepMinutes;XCTAssertThrowsError(try profile.validate())
        profile=SleepProfile();profile.freeSleepMinutes=1440;XCTAssertThrowsError(try profile.validate())
        profile=SleepProfile();profile.personalCaffeineCapMG = .nan;XCTAssertThrowsError(try profile.validate())
    }
    func testMidnightSleepAndExtraFreeDaySleepCorrection() {
        var profile=SleepProfile();profile.freeWakeMinutes=10*60
        let result=BodyClockEstimate.estimate(profile)
        XCTAssertEqual(BodyClockEstimate.duration(from:23*60,to:7*60),480)
        XCTAssertEqual(result.freeMidpointMinutes,300)
        XCTAssertEqual(result.adjustedMidpointMinutes ?? -1,257.142857,accuracy:0.001)
        XCTAssertEqual(result.scheduleShiftMinutes,120)
    }
    func testAlarmOrShiftWorkSuppressesChronotypeLabel() {
        for flag in 0...2 {
            var profile=SleepProfile()
            if flag==0 { profile.freeDayAlarm=true }
            if flag==1 { profile.shiftWork=true }
            if flag==2 { profile.workDays=7 }
            let result=BodyClockEstimate.estimate(profile)
            XCTAssertNil(result.adjustedMidpointMinutes);XCTAssertNil(result.scheduleShiftMinutes)
            XCTAssertEqual(result.tendency,"Schedule estimate only")
        }
    }
    func testScheduleGapWrapsAcrossMidnight() {
        var profile=SleepProfile();profile.workSleepMinutes=21*60;profile.workWakeMinutes=60;profile.freeSleepMinutes=23*60;profile.freeWakeMinutes=3*60
        XCTAssertEqual(BodyClockEstimate.estimate(profile).scheduleShiftMinutes,120)
    }
    func testAllFreeDaysDoNotInventWorkdayGap() {
        var profile=SleepProfile();profile.workDays=0
        let result=BodyClockEstimate.estimate(profile)
        XCTAssertNil(result.scheduleShiftMinutes);XCTAssertEqual(result.adjustedMidpointMinutes,result.freeMidpointMinutes)
    }
    func testTeenAndUnknownAgeNeverUseAdultDoseReference() {
        var preferences=Preferences(),profile=SleepProfile();profile.caffeineContext = .standard;profile.personalCaffeineCapMG=400
        for age in ["13–17","unknown"] {
            preferences.ageBand=age
            let text=CaffeineAdvice.message(preferences:preferences,profile:profile,total:50)
            XCTAssertTrue(text.contains("avoiding caffeine"));XCTAssertFalse(text.contains("400"));XCTAssertFalse(CaffeineAdvice.isAdult(preferences))
        }
    }
    func testAdultWithUncertainContextGetsIndividualAdvice() {
        var preferences=Preferences();preferences.ageBand="18–60"
        XCTAssertTrue(CaffeineAdvice.message(preferences:preferences,profile:nil,total:100).contains("individual advice"))
        var profile=SleepProfile();profile.caffeineContext = .individualAdvice
        XCTAssertTrue(CaffeineAdvice.message(preferences:preferences,profile:profile,total:100).contains("clinician"))
    }
    func testAdultWarningsUseChosenCapAndGeneralReference() {
        var preferences=Preferences();preferences.ageBand="18–60"
        var profile=SleepProfile();profile.caffeineContext = .standard;profile.personalCaffeineCapMG=100
        XCTAssertTrue(CaffeineAdvice.message(preferences:preferences,profile:profile,total:125).contains("chosen daily cap"))
        XCTAssertTrue(CaffeineAdvice.message(preferences:preferences,profile:profile,total:400).contains("reached or exceeded"))
    }
    func testCaffeineTotalsUseReportingTimezoneAndExcludeNextDayBoundary() {
        let entries=[CaffeineEntry(date:date("2026-11-10T23:00:00Z"),milligrams:10,label:"Start"),CaffeineEntry(date:date("2026-11-11T22:59:00Z"),milligrams:20,label:"End"),CaffeineEntry(date:date("2026-11-11T23:00:00Z"),milligrams:100,label:"Next day")]
        XCTAssertEqual(CaffeineAdvice.dailyTotal(entries,on:date("2026-11-11T12:00:00Z"),zoneID:"Europe/Skopje"),30)
    }
    func testSensitivityChangesCutoffWithoutCalculatingDose() {
        let bed=date("2026-11-11T22:00:00Z")
        var profile=SleepProfile();profile.caffeineSensitivity = .usual
        XCTAssertEqual(CaffeineAdvice.cutoff(bedtime:bed,profile:profile),date("2026-11-11T14:00:00Z"))
        profile.caffeineSensitivity = .sensitive
        XCTAssertEqual(CaffeineAdvice.cutoff(bedtime:bed,profile:profile),date("2026-11-11T12:00:00Z"))
        XCTAssertEqual(CaffeineAdvice.cutoffHours(nil),10)
    }
    func testInvalidAndDuplicateCaffeineEntriesRejected() throws {
        for mg in [Double.nan,Double.infinity,-1,0,2001] { XCTAssertThrowsError(try CaffeineEntry(date:Date(),milligrams:mg,label:"Test").validate()) }
        var s=Snapshot();let entry=CaffeineEntry(date:Date(),milligrams:80,label:"Tea");s.caffeineEntries=[entry,entry]
        XCTAssertThrowsError(try SnapshotCodec.validate(s))
    }
    func testWeeklyNotificationsAreUniqueAndUsePreviousEvening() throws {
        var p=Preferences();p.reportingTimeZoneID="UTC";p.targetHours=8;p.settlingMinutes=0;p.windDownMinutes=30
        var options=ReminderOptions();options.caffeine=true;p.reminderOptions=options
        let plans=ReminderPlanner.weekly(preferences:p,profile:nil,after:date("2026-11-08T12:00:00Z"))
        XCTAssertEqual(plans.count,21);XCTAssertEqual(Set(plans.map(\.id)).count,21)
        let mondayBed=try XCTUnwrap(plans.first{$0.id=="luma.bed.2"})
        XCTAssertEqual(mondayBed.date,date("2026-11-08T23:00:00Z"))
        let cutoff=try XCTUnwrap(plans.first{$0.id=="luma.caffeine.2"})
        XCTAssertEqual(cutoff.date,date("2026-11-08T13:00:00Z"))
        XCTAssertTrue(cutoff.body.contains("teens"))
    }
    func testReminderTogglesAndFingerprintDetectScheduleChanges() {
        var p=Preferences();let before=ReminderPlanner.fingerprint(preferences:p,profile:nil)
        p.weekdayWakeMinutes+=15
        XCTAssertNotEqual(before,ReminderPlanner.fingerprint(preferences:p,profile:nil))
        var options=ReminderOptions();options.windDown=false;options.bedtime=false;options.caffeine=true;p.reminderOptions=options
        XCTAssertEqual(ReminderPlanner.weekly(preferences:p,profile:nil,after:Date()).count,7)
        options.caffeine=false;p.reminderOptions=options
        XCTAssertTrue(ReminderPlanner.weekly(preferences:p,profile:nil,after:Date()).isEmpty)
    }
    func testCustomSoundRejectsPathTraversalAndInvalidDuration() throws {
        let id=UUID()
        let good=CustomSleepSound(id:id,name:"My sound",fileName:id.uuidString+".mp3",duration:30)
        XCTAssertNoThrow(try good.validate())
        var bad=good;bad.fileName="../outside.mp3";XCTAssertThrowsError(try bad.validate())
        bad=good;bad.duration = .infinity;XCTAssertThrowsError(try bad.validate())
        bad=good;bad.duration=7201;XCTAssertThrowsError(try bad.validate())
        var s=Snapshot();s.customSounds=[good,good];XCTAssertThrowsError(try SnapshotCodec.validate(s))
    }
}
