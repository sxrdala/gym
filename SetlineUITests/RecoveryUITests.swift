import XCTest

final class RecoveryUITests: XCTestCase {
    @MainActor
    func testSelectedDayDrivesCaloriesAndSurvivesRelaunch() {
        let app = launchWithIsolatedStore()
        let pills = app.scrollViews["training-days"]
        let firstDay = app.buttons["day-2026-11-25"]
        for _ in 0..<10 {
            if firstDay.isHittable { break }
            pills.swipeRight()
        }
        firstDay.tap()
        app.tabBars.buttons["Calories"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Nov 25")).firstMatch.exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["day-2026-11-25"].isSelected)
        XCTAssertTrue(app.buttons["Create Custom Workout"].isHittable)
    }

    @MainActor
    func testTerminateAndResumeTwoSets() {
        continueAfterFailure = false
        let app = launchWithIsolatedStore()
        startBenchPress(in: app)
        logTwoSets(in: app)

        app.terminate()
        app.launch()
        let resume = app.buttons["Resume Active Workout"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        let first = app.buttons["logged-set-1"]
        let second = app.buttons["logged-set-2"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(first.label, "Set 1, 20 kg × 8")
        XCTAssertEqual(second.label, "Set 2, 22.5 kg × 7")
    }

    @MainActor
    func testWorkoutFitsOnFourPointSevenInchScreen() throws {
        continueAfterFailure = false
        let app = launchWithIsolatedStore()
        let screen = app.frame
        try XCTSkipUnless(screen.width == 375 && screen.height == 667,
                          "Run on an iPhone SE simulator with a 375 × 667 pt screen.")

        startBenchPress(in: app)
        app.buttons["Log Set"].tap()
        app.buttons["finish-workout"].tap()
        let confirm = app.buttons.matching(NSPredicate(
            format: "label == %@ AND identifier != %@", "Finish Workout", "finish-workout"
        )).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        startBenchPress(in: app)
        logTwoSets(in: app)

        let reference = app.staticTexts["last-session-reference"]
        let priorSet = app.buttons["last-set-1"]
        let spotify = app.buttons["Open Spotify"]
        let first = app.buttons["logged-set-1"]
        let second = app.buttons["logged-set-2"]
        let weight = app.buttons["Increase weight"]
        let reps = app.buttons["Increase reps"]
        let log = app.buttons["Log Set"]
        for element in [reference, priorSet, spotify, first, second, weight, reps, log] {
            XCTAssertTrue(element.isHittable, element.debugDescription)
            XCTAssertTrue(screen.contains(element.frame), element.debugDescription)
        }
        XCTAssertLessThanOrEqual(reference.frame.maxY, priorSet.frame.minY)
        XCTAssertLessThanOrEqual(priorSet.frame.maxY, spotify.frame.minY)
        XCTAssertLessThanOrEqual(spotify.frame.maxY, first.frame.minY)
        XCTAssertLessThanOrEqual(first.frame.maxY, second.frame.minY)
        XCTAssertLessThanOrEqual(second.frame.maxY, weight.frame.minY)
        XCTAssertLessThanOrEqual(weight.frame.maxY, reps.frame.minY)
        XCTAssertLessThanOrEqual(reps.frame.maxY, log.frame.minY)
    }

    @MainActor
    private func launchWithIsolatedStore() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SETLINE_TEST_STORE"] = UUID().uuidString
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    @MainActor
    private func startBenchPress(in app: XCUIApplication) {
        let choose = app.buttons["Choose workout"]
        XCTAssertTrue(choose.waitForExistence(timeout: 5))
        choose.tap()
        app.buttons["Empty quick workout"].tap()
        let chooseExercise = app.buttons["Choose exercise"]
        XCTAssertTrue(chooseExercise.waitForExistence(timeout: 5))
        chooseExercise.tap()
        let bench = app.buttons["Bench press"]
        XCTAssertTrue(bench.waitForExistence(timeout: 5), app.debugDescription)
        bench.tap()
        XCTAssertTrue(app.buttons["Log Set"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func logTwoSets(in app: XCUIApplication) {
        let log = app.buttons["Log Set"]
        log.tap()
        app.buttons["Increase weight"].tap()
        app.buttons["Decrease reps"].tap()
        log.tap()
        XCTAssertTrue(app.buttons["logged-set-2"].waitForExistence(timeout: 5))
    }
}
