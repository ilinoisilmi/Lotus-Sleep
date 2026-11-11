import XCTest
final class LumaUITests:XCTestCase {
    func reveal(_ element:XCUIElement,in app:XCUIApplication) {
        for _ in 0..<8 { if element.isHittable { return };app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    func launch(reset:Bool=true)->XCUIApplication {
        let app=XCUIApplication();app.launchArguments=["--ui-testing"]+(reset ? ["--reset-ui-testing"] : []);app.launch();return app
    }
    func onboard(_ app:XCUIApplication) {
        let button=app.buttons["Start my sleep diary"]
        if !button.isHittable{app.swipeUp()}
        XCTAssertTrue(button.waitForExistence(timeout:5));button.tap()
    }
    func testManualEntryReachesHistory() {
        let app=launch();onboard(app);app.tabBars.buttons["Track"].tap();app.buttons["Add sleep"].tap();app.navigationBars.buttons["Save"].tap();app.tabBars.buttons["History"].tap();XCTAssertTrue(app.staticTexts["Your last seven days."].exists)
    }
    func testTimerSurvivesRelaunch() {
        var app=launch();onboard(app);app.tabBars.buttons["Track"].tap();app.buttons["Start bedtime"].tap();app.terminate()
        app=launch(reset:false);app.tabBars.buttons["Track"].tap();XCTAssertTrue(app.buttons["End night & review"].exists)
    }
    func testDemoLabel() {
        let app=launch();app.swipeUp();app.buttons["Explore a clearly labeled demo"].tap();XCTAssertTrue(app.staticTexts["DEMO · sample history"].waitForExistence(timeout:5))
    }
    func testHistoryUsesSevenDaysWithoutCalendar() {
        let app=launch();onboard(app);app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Your last seven days."].exists)
        XCTAssertEqual(app.datePickers.count,0)
        XCTAssertTrue(app.staticTexts["0 of 7 days logged"].exists)
    }
    func testNightWakeSurvivesRelaunch() {
        var app=launch();onboard(app);app.tabBars.buttons["Track"].tap()
        app.buttons["Nighttime help"].tap();app.buttons["I'm awake now"].tap()
        XCTAssertTrue(app.staticTexts["Wake-up saved"].exists)
        app.terminate();app=launch(reset:false);app.tabBars.buttons["Track"].tap()
        XCTAssertTrue(app.buttons["Finish your open wake-up log"].exists)
    }
    func testSleepProfileHasAnEditableQuestionnaire() {
        let app=launch();onboard(app);app.tabBars.buttons["Settings"].tap()
        app.buttons["My sleep profile & questionnaire"].tap()
        app.buttons["Get to know my sleep"].tap()
        XCTAssertTrue(app.navigationBars["About you"].exists)
        XCTAssertTrue(app.buttons["Continue"].exists)
    }
    func testNotificationsExposeAnExplicitTestAction() {
        let app=launch();onboard(app);app.tabBars.buttons["Settings"].tap()
        app.buttons["Notifications"].tap()
        XCTAssertTrue(app.buttons["Send a test in 5 seconds"].waitForExistence(timeout:5))
        XCTAssertEqual(app.alerts.count,0,"Opening settings must not request notification permission.")
    }
    func testSoundLibraryOffersBuiltInAndImportedAudio() {
        let app=launch();onboard(app);app.tabBars.buttons["Track"].tap()
        app.buttons["Relaxing sounds & your MP3s"].tap()
        XCTAssertTrue(app.navigationBars["Sleep sounds"].exists)
        app.swipeUp()
        XCTAssertTrue(app.buttons["Play White noise"].exists)
        app.swipeUp();app.swipeUp()
        XCTAssertTrue(app.buttons["Import an MP3, M4A or WAV"].exists)
    }
    func testMorningNotePersistsWithoutRequestingNotificationPermission() {
        var app=launch();onboard(app);app.tabBars.buttons["Settings"].tap();app.buttons["Morning inbox"].tap()
        app.buttons["Leave a morning note"].tap()
        let note=app.descendants(matching:.any).matching(identifier:"morning.note").firstMatch;note.tap();note.typeText("Bring the charger")
        let notify=app.switches["Notify me at this time"];reveal(notify,in:app);notify.tap();app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Bring the charger"].waitForExistence(timeout:5));XCTAssertEqual(app.alerts.count,0)
        app.terminate();app=launch(reset:false);app.tabBars.buttons["Settings"].tap();app.buttons["Morning inbox"].tap()
        XCTAssertTrue(app.staticTexts["Bring the charger"].exists)
        app.buttons["Mark done: Bring the charger"].tap();XCTAssertTrue(app.buttons["Reopen: Bring the charger"].exists)
    }
    func testSelectedCompanionSurvivesRelaunch() {
        var app=launch();onboard(app);app.tabBars.buttons["Settings"].tap();app.buttons["Rest streak & companions"].tap()
        let fox=app.buttons["companion.fox"];reveal(fox,in:app);fox.tap()
        XCTAssertTrue(fox.label.contains("selected"))
        app.terminate();app=launch(reset:false);app.tabBars.buttons["Settings"].tap();app.buttons["Rest streak & companions"].tap()
        XCTAssertTrue(app.staticTexts["Ember"].firstMatch.exists)
    }
    func testCreateSavedSoundBlend() {
        let app=launch();onboard(app);app.tabBars.buttons["Track"].tap();app.buttons["Relaxing sounds & your MP3s"].tap()
        let blends=app.buttons["Saved sound blends"];reveal(blends,in:app);blends.tap();app.buttons["Create a sound blend"].tap()
        let name=app.textFields["blend.name"];name.tap();name.typeText("Quiet room")
        let rain=app.switches["Soft rain"];reveal(rain,in:app);rain.tap()
        app.navigationBars.buttons["Save"].tap();XCTAssertTrue(app.staticTexts["Quiet room"].waitForExistence(timeout:5))
    }
    func testExperimentSetupShowsTwoOptionsAndFirstMorning() {
        let app=launch();onboard(app);app.tabBars.buttons["Settings"].tap();app.buttons["Sleep experiments"].tap();app.buttons["Start an experiment"].tap()
        XCTAssertTrue(app.navigationBars["New experiment"].exists)
        XCTAssertTrue(app.textFields["Option A"].exists);XCTAssertTrue(app.textFields["Option B"].exists)
        XCTAssertTrue(app.datePickers["First morning"].exists)
    }
}
