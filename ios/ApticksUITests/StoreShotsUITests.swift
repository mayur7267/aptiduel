import XCTest

// The raw screens behind the App Store screenshots: a named player with a
// college and a good rating on the fake backend, so nothing real shows.
// Each test starts a fresh launch and saves PNGs to the folder given in
// TEST_RUNNER_STORE_SHOTS_DIR (see store/README.md for the whole recipe).
final class StoreShotsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // Tiko is the app's mascot, but his speech bubble can sit on top of a
    // screen's content, so he is off unless a screen is about him.
    private func start(tiko: Bool = false) {
        app.launchArguments = [
            "-FakeBackend", "-FakeName", "Asha Verma", "-FakeRating", "1342", "-FakeCollege", "1", "-FakeGradYear", "2027",
            "-apticks-onboarding-done", "YES", "-apticks-tour-done", "YES", "-apticks-tiko-off", tiko ? "NO" : "YES",
        ]
        app.launch()
        sleep(4) // the launch splash
    }

    private func shot(_ name: String) {
        usleep(600_000)
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["STORE_SHOTS_DIR"] {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    // Taps a button, scrolling it into view first (the tab bar covers the
    // bottom of the screen).
    private func tap(_ label: String, timeout: TimeInterval = 10) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "No button \(label)")
        let visible = app.frame.insetBy(dx: 0, dy: 110)
        var tries = 0
        while !(button.isHittable && visible.contains(CGPoint(x: button.frame.midX, y: button.frame.midY))) && tries < 5 {
            app.swipeUp(velocity: .slow)
            tries += 1
        }
        button.tap()
    }

    @MainActor
    func testHome() {
        start()
        shot("01-home")
        tap("Today's goals")
        shot("02-goals")
    }

    @MainActor
    func testDuel() {
        start(tiko: true)
        tap("Quick Match")
        XCTAssertTrue(app.staticTexts["Question 1 of 5"].waitForExistence(timeout: 15))
        shot("06-duel-question")
        // Right, wrong (a picture question), right, right, wrong.
        let answers = ["B: 25%", "Option C", "B: ₹2,100", "D: 71", "A: Scarce"]
        for (i, answer) in answers.enumerated() {
            XCTAssertTrue(app.staticTexts["Question \(i + 1) of 5"].waitForExistence(timeout: 10))
            if i == 1 { shot("07-duel-figure") }
            tap(answer)
            usleep(300_000)
            if i == 0 { shot("08-duel-right") }
        }
        XCTAssertTrue(app.buttons["Review answers"].waitForExistence(timeout: 15))
        sleep(2) // the result settles and the confetti falls
        shot("09-result")
        tap("Review answers")
        app.swipeUp()
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        top.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.46)))
        shot("10-review")
    }

    // One winning duel at a human pace, for the App Store preview video. The
    // marks (epoch seconds) say where each part starts in the screen recording.
    @MainActor
    func testPreview() {
        start(tiko: true)
        mark("home")
        sleep(3) // the home screen, so the viewer sees where they are
        app.buttons["Quick Match"].firstMatch.tap()
        mark("quick-tapped")
        // Right answers all the way; the picture question's options are labelled "Option A".
        let answers = ["B: 25%", "Option A", "B: ₹2,100", "D: 71", "B: Plentiful"]
        for (i, answer) in answers.enumerated() {
            XCTAssertTrue(app.staticTexts["Question \(i + 1) of 5"].waitForExistence(timeout: 15))
            mark("q\(i + 1)")
            usleep(i == 0 ? 2_000_000 : 1_500_000) // time to read the question
            app.buttons[answer].firstMatch.tap()
            mark("a\(i + 1)")
            usleep(900_000) // the answer lights up
        }
        XCTAssertTrue(app.buttons["Review answers"].waitForExistence(timeout: 15))
        mark("result")
        sleep(5)
        mark("end")
    }

    private func mark(_ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["STORE_SHOTS_DIR"] else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: dir).appendingPathComponent("preview-marks.txt")
        let line = "\(name) \(Date().timeIntervalSince1970)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    @MainActor
    func testDaily() {
        start()
        tap("Play today's set")
        for i in 1...5 {
            XCTAssertTrue(app.staticTexts["Question \(i) of 5"].waitForExistence(timeout: 15))
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'A: ' OR label BEGINSWITH 'Option A'")).firstMatch.tap()
        }
        let home = app.buttons["Back to home"].firstMatch
        XCTAssertTrue(home.waitForExistence(timeout: 15))
        home.tap()
        XCTAssertTrue(app.buttons["See today's rank"].waitForExistence(timeout: 10))
        shot("11-daily-done")
        tap("View all days")
        XCTAssertTrue(app.staticTexts["Daily calendar"].waitForExistence(timeout: 5))
        shot("12-calendar")
    }

    @MainActor
    func testTabsAndChallenge() {
        start()
        tap("Ranks")
        sleep(1)
        shot("13-ranks")
        tap("Profile")
        sleep(2)
        shot("14-profile")
        app.swipeUp()
        sleep(1)
        shot("15-profile-lower")
        app.open(URL(string: "apticks://c/FRIEND1")!)
        XCTAssertTrue(app.buttons["Accept challenge"].waitForExistence(timeout: 10))
        shot("16-challenge")
    }
}
