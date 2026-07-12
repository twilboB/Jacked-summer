import XCTest

/// End-to-end "user tests" driving the real UI on a simulator.
///
/// These rely on a small set of accessibility identifiers added to key controls
/// (prefix per tab, e.g. `food.kcal`, `body.weightField`, `bells.log.2`,
/// `lift.startWeek`) plus the tab-bar and navigation-bar labels. If a selector
/// can't be found on first run, confirm the identifier in the corresponding view.
final class JackedBySummerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        // Start from a clean store so assertions are deterministic.
        app.launchArguments += ["-uiTestingResetState", "YES"]
        app.launch()
        return app
    }

    private func openTab(_ name: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "tab \(name) should exist")
        tab.tap()
    }

    // MARK: Shell

    func testFourTabsPresentAndSwitch() {
        let app = launch()
        for tab in ["Lift", "Bells", "Food", "Body"] {
            openTab(tab, in: app)
            XCTAssertTrue(app.navigationBars[tab].waitForExistence(timeout: 5),
                          "\(tab) screen should show its navigation title")
        }
    }

    // MARK: Food — manual logging (fully offline, no AI required)

    func testAddManualFoodEntry() {
        let app = launch()
        openTab("Food", in: app)

        let name = app.textFields["food.name"]
        let kcal = app.textFields["food.kcal"]
        let protein = app.textFields["food.protein"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))

        name.tap(); name.typeText("Test Chicken Bowl")
        kcal.tap(); kcal.typeText("650")
        protein.tap(); protein.typeText("55")

        // Dismiss the number pad before tapping Log.
        app.navigationBars.firstMatch.tap()
        app.buttons["food.logManual"].tap()

        XCTAssertTrue(app.staticTexts["Test Chicken Bowl"].waitForExistence(timeout: 5),
                      "the logged entry should appear in the day's list")
    }

    func testCompletelyEmptyFoodEntryIsBlocked() {
        let app = launch()
        openTab("Food", in: app)
        let log = app.buttons["food.logManual"]
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        // With no name and no numbers, logging must not create an entry.
        // Either the button is disabled or the tap is a no-op.
        if log.isEnabled { log.tap() }
        // No untitled/zero row should be added — a heuristic: the list stays empty of a known placeholder.
        XCTAssertFalse(app.staticTexts["0 kcal"].exists && app.staticTexts["Untitled"].exists)
    }

    // MARK: Body — log a weigh-in

    func testLogBodyweight() {
        let app = launch()
        openTab("Body", in: app)
        let field = app.textFields["body.weightField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // With a clean UI-testing store there is no prior weight, so the field is empty.
        field.tap()
        field.typeText("88.5")
        app.navigationBars.firstMatch.tap()
        app.buttons["body.logWeight"].tap()
        let current = app.staticTexts["body.currentWeight"]
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        XCTAssertEqual(current.label, "88.5")
    }

    // MARK: Bells — log a session and see the streak start

    func testLogKettlebellSessionStartsStreak() {
        let app = launch()
        openTab("Bells", in: app)
        // Day 2 has no benchmark input, so it's the simplest to log.
        let logButton = app.buttons["bells.log.2"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 5))
        logButton.tap()
        // The streak hero is a combined accessibility element; assert its label
        // reflects a live streak of 1 after logging today.
        let hero = app.descendants(matching: .any).matching(identifier: "bells.streakHero").firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        XCTAssertTrue(hero.label.contains("Current streak 1"),
                      "expected a streak of 1 after logging; got: \(hero.label)")
    }

    // MARK: Lift — start a new week

    func testStartNextWeek() {
        let app = launch()
        openTab("Lift", in: app)
        let weekLabel = app.staticTexts["lift.weekLabel"]
        XCTAssertTrue(weekLabel.waitForExistence(timeout: 5))
        let before = weekLabel.label
        app.buttons["lift.startWeek"].tap()
        XCTAssertNotEqual(weekLabel.label, before, "week label should advance after starting a new week")
    }
}
