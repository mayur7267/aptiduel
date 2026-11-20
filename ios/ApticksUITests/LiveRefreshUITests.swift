import XCTest

// On the real backend, not the fake one: the "Swift.CancellationError
// error 1" box only ever showed there, because only the live backend
// turned a cancelled request into a message. From a cold start, pull to
// refresh on every tab and leave Home part-way through loading, several
// times over. Nothing should ever say a request failed.
//
// Uses this simulator's guest account (one is made on the first run).
final class LiveRefreshUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-apticks-onboarding-done", "YES", "-apticks-tour-done", "YES"]
    }

    @MainActor
    func testRefreshingNeverShowsACancellation() {
        app.launch()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 20))

        // The first pull after a cold start, while home is still loading.
        pull()
        check("cold start")
        sleep(3)
        pull()
        check("second pull")

        for round in 1...4 {
            for tab in ["Daily", "Ranks", "Profile"] {
                app.buttons[tab].tap()
                usleep(400_000)
                pull()
                // Back home straight away: its load starts, and is left
                // part-way when we go again.
                app.buttons["Home"].tap()
                usleep(150_000)
                app.buttons[tab].tap()
                usleep(150_000)
                app.buttons["Home"].tap()
                pull()
                check("round \(round), back from \(tab)")
            }
        }
        sleep(4)
        check("settled")
    }

    // Drags down from the left margin, clear of any button.
    private func pull() {
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.25))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.8))
        top.press(forDuration: 0.05, thenDragTo: bottom)
    }

    private func check(_ when: String) {
        // Give a failed load a moment to show its box.
        sleep(2)
        let failed = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS[c] 'CancellationError' OR label CONTAINS[c] 'cancelled' OR label CONTAINS[c] 'be completed'"))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = when
        shot.lifetime = failed.count > 0 ? .keepAlways : .deleteOnSuccess
        add(shot)
        XCTAssertEqual(failed.count, 0, "\(when): \(failed.firstMatch.label)")
    }
}
