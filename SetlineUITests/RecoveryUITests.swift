import XCTest

final class RecoveryUITests: XCTestCase {
    @MainActor
    func testFiveTabsAndSharedDateSurviveRelaunch() {
        let app = launch()
        let tabs = app.tabBars.buttons
        XCTAssertEqual(tabs.allElementsBoundByIndex.map(\.label), ["Workout", "Diet", "Music", "Profile", "Settings"])
        let first = app.buttons["day-2026-11-25"]
        for _ in 0..<12 {
            if first.isHittable { break }
            app.scrollViews["training-days"].swipeRight()
        }
        first.tap()
        tabs["Diet"].tap()
        XCTAssertTrue(first.isSelected)
        app.buttons["Cardio"].tap()
        XCTAssertTrue(app.buttons["Log cardio"].exists)
        tabs["Music"].tap()
        XCTAssertTrue(app.buttons["Open Spotify"].exists)
        XCTAssertTrue(app.buttons["Copy"].exists)
        tabs["Settings"].tap()
        XCTAssertTrue(app.buttons["Copy"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(first.isSelected)
    }

    @MainActor
    func testTwoSetsCollapseEditAndRecoverOnSmallScreen() throws {
        let app = launch()
        try XCTSkipUnless(app.frame.width == 375 && app.frame.height == 667, "Use a 4.7-inch simulator.")
        app.buttons["Quick workout"].tap()
        app.buttons["Add exercise"].tap()
        app.buttons["Bench press"].tap()
        let first = app.buttons["set-1"], second = app.buttons["set-2"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(app.frame.contains(second.frame))
        XCTAssertEqual(second.label, "20 kg × 8")
        second.tap()
        app.buttons["Increase weight"].tap()
        app.buttons["Decrease reps"].tap()
        app.buttons["Save changes"].tap()
        app.buttons["exercise-Bench press"].tap()
        XCTAssertFalse(first.exists)
        app.terminate()
        app.launch()
        app.buttons["workout-Quick workout"].tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(second.label, "22.5 kg × 7")
    }

    @MainActor
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SETLINE_TEST_STORE"] = UUID().uuidString
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }
}
