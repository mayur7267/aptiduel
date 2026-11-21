import XCTest

// Walks the app on the fake backend (no production data) and keeps a
// screenshot of each screen: the tour, a whole duel, its result, the tabs
// and both sides of a challenge link.
final class ScreensUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // The fake backend; the intro and the tour as on a first launch, or not.
    private func launch(intro: Bool = false, tour: Bool = true, extra: [String] = []) {
        app.launchArguments = ["-FakeBackend", "-apticks-onboarding-done", intro ? "NO" : "YES", "-apticks-tour-done", tour ? "NO" : "YES"] + extra
        app.launch()
        snap("00-splash")
        sleep(3) // the launch splash
    }

    // A few frames of a scene while it plays.
    private func film(_ name: String, frames: Int, every seconds: Double) {
        for i in 1...frames {
            usleep(UInt32(seconds * 1_000_000))
            snap("\(name)-\(i)")
        }
    }

    @MainActor
    func testOnboarding() {
        launch(intro: true, tour: false)
        XCTAssertTrue(app.buttons["Let's go"].waitForExistence(timeout: 10))
        film("80-hello", frames: 8, every: 0.35)
        tap("Let's go")
        film("81-duel", frames: 8, every: 0.55)
        tap("Next")
        film("82-challenge", frames: 6, every: 0.55)
        tap("Next")
        film("83-climb", frames: 7, every: 0.6)
        tap("Next")
        sleep(1)
        snap("84-name-1")
        app.textFields.firstMatch.tap()
        // A fresh simulator shows a one-time keyboard tip first.
        let tip = app.buttons["Continue"]
        if tip.waitForExistence(timeout: 2) { tip.tap() }
        app.textFields.firstMatch.typeText("Asha")
        sleep(1)
        snap("84-name-2")
        app.textFields.firstMatch.typeText("\n") // Return saves and moves on
        film("85-ready", frames: 8, every: 0.35)
        tap("Find my first match")
        XCTAssertTrue(app.staticTexts["Quick Match"].waitForExistence(timeout: 10))
    }

    private func snap(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    // Taps a button, scrolling it into view first (the tab bar covers the
    // bottom of the screen).
    private func tap(_ label: String, timeout: TimeInterval = 8) {
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
    func testTourThenDuel() {
        launch(tour: true)
        XCTAssertTrue(app.buttons["Show me"].waitForExistence(timeout: 10))
        snap("01-tour-intro")
        tap("Show me")
        for step in 2...7 {
            sleep(2)
            snap(String(format: "%02d-tour-step", step))
            tap("Next")
        }
        sleep(2)
        snap("08-tour-ready")
        tap("Find a match")

        sleep(1)
        snap("10-matchmaking")
        XCTAssertTrue(app.staticTexts["Question 1 of 5"].waitForExistence(timeout: 12))
        snap("11-duel-q1")
        // Right, wrong (a picture question), right, right, wrong.
        let answers = ["B: 25%", "Option C", "B: ₹2,100", "D: 71", "A: Scarce"]
        for (i, answer) in answers.enumerated() {
            XCTAssertTrue(app.staticTexts["Question \(i + 1) of 5"].waitForExistence(timeout: 10))
            if i == 1 { snap("12-duel-figures") }
            tap(answer)
            usleep(400_000)
            snap(String(format: "%02d-duel-reveal-%d", 13 + i, i + 1))
        }
        XCTAssertTrue(app.buttons["Review answers"].waitForExistence(timeout: 12))
        sleep(1)
        snap("20-result")
        tap("Review answers")
        app.swipeUp()
        snap("21-review")
    }

    // The Daily on a guest: Start makes the run, then the result offers
    // WhatsApp and a Story picture, asks for a name, and offers an 8 pm
    // reminder, which Profile can turn off.
    // The four subject tabs on Home, the colour pouring into the Coding
    // card, English, GK coming soon, and a coding duel showing its program.
    // An English duel from Home: plain-text questions, no code.
    @MainActor
    func testEnglishSubject() {
        launch(tour: false, extra: ["-apticks-subject", "english"])
        XCTAssertTrue(app.buttons["English Quick Match"].waitForExistence(timeout: 10))
        tap("English Quick Match")
        XCTAssertTrue(app.staticTexts["Choose the word closest in meaning to CANDID."].waitForExistence(timeout: 15))
        sleep(1)
        snap("97-english-question")
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Frank'")).firstMatch.tap()
        sleep(2)
        snap("98-english-answered")
    }

    @MainActor
    func testCodingSubject() {
        launch(tour: false, extra: ["-apticks-subject", "aptitude", "-apticks-code-lang", "java"])
        XCTAssertTrue(app.buttons["Coding"].waitForExistence(timeout: 10))
        tap("Aptitude")
        sleep(1)
        snap("95-subjects-aptitude")
        tap("Coding")
        usleep(200_000)
        snap("95-subjects-pouring")
        sleep(1)
        snap("95-subjects-coding")
        XCTAssertTrue(app.buttons["Show code in Java"].exists)
        tap("English")
        sleep(1)
        snap("95-subjects-english")
        XCTAssertTrue(app.buttons["English Quick Match"].waitForExistence(timeout: 3))
        tap("GK, coming soon")
        sleep(1)
        snap("95-subjects-gk")
        XCTAssertTrue(app.buttons["Play Aptitude meanwhile"].waitForExistence(timeout: 3))
        tap("Coding")
        sleep(1)
        tap("Coding Quick Match")
        XCTAssertTrue(app.staticTexts["What does this code print?"].waitForExistence(timeout: 15))
        sleep(1)
        snap("96-coding-question")
        XCTAssertTrue(app.staticTexts["Main.java"].exists)
    }

    @MainActor
    func testDailyShareAndReminder() {
        // As if the reminder had never been offered on this phone.
        launch(tour: false, extra: ["-apticks-reminder-on", "NO", "-apticks-reminder-offered", "NO"])
        tap("Daily", timeout: 10)
        sleep(1)
        snap("90-daily-start")
        tap("Start")
        let answers = ["B: 25%", "Option C", "B: ₹2,100", "D: 71", "A: Scarce"]
        for (i, answer) in answers.enumerated() {
            let shown = app.staticTexts["Question \(i + 1) of 5"].waitForExistence(timeout: 10)
            snap("90-daily-q\(i + 1)")
            XCTAssertTrue(shown)
            tap(answer)
            usleep(400_000)
            snap("90-daily-a\(i + 1)")
        }
        XCTAssertTrue(app.buttons["Review answers"].waitForExistence(timeout: 12))
        sleep(2)
        snap("91-daily-result")
        XCTAssertTrue(app.buttons["WhatsApp"].exists)
        XCTAssertTrue(app.buttons["Share a story picture of your score"].exists)
        XCTAssertTrue(app.staticTexts["What should friends call you?"].exists)

        app.swipeUp(velocity: .slow)
        sleep(1)
        snap("92-daily-result-lower")
        // The system asks first; allow it.
        tap("Remind me")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        XCTAssertFalse(app.staticTexts["Your link is copied too: add it to your Story with Instagram's Link sticker."].exists)
        XCTAssertTrue(app.staticTexts["Reminder on: 8 pm, on days you haven't played."].waitForExistence(timeout: 8))
        snap("93-reminder-on")

        app.swipeDown(velocity: .slow)
        sleep(1)
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        let tip = app.buttons["Continue"]
        if tip.waitForExistence(timeout: 2) { tip.tap() }
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) { field.tap() }
        field.typeText("Asha")
        tap("Save")
        XCTAssertTrue(app.staticTexts["What should friends call you?"].waitForNonExistence(timeout: 8))
        snap("94-named")

        app.buttons["Back to home"].firstMatch.tap()
        tap("Profile")
        sleep(1)
        app.swipeUp()
        sleep(1)
        snap("95-profile-reminder")
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Daily reminder'")).firstMatch.exists)
    }

    @MainActor
    func testTabsAndChallengeLinks() {
        launch(tour: true)
        tap("Skip", timeout: 10)
        sleep(1)
        snap("30-home")
        app.swipeUp()
        snap("31-home-lower")
        app.swipeUp()
        snap("32-home-bottom")

        tap("Ranks")
        sleep(1)
        snap("40-ranks-college")
        app.buttons["Everyone"].firstMatch.tap()
        sleep(1)
        snap("41-ranks-india")
        app.buttons["Coding leaderboard"].firstMatch.tap()
        sleep(2)
        snap("42-ranks-coding")

        tap("Profile")
        sleep(2)
        snap("50-profile")
        let codingTile = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Coding'")).firstMatch
        if codingTile.waitForExistence(timeout: 5) {
            codingTile.tap()
            sleep(1)
            snap("50b-profile-coding")
        }
        app.swipeUp()
        sleep(1)
        snap("51-profile-lower")
        app.swipeUp()
        sleep(1)
        snap("51b-profile-bottom")

        // Feedback, from the "Found a bug?" sticky note.
        tap("Found a bug?")
        let box = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(box.waitForExistence(timeout: 5))
        let tip = app.buttons["Continue"]
        if tip.waitForExistence(timeout: 2) { tip.tap() }
        box.tap()
        box.typeText("The timer froze on question 3")
        snap("52-feedback")
        tap("Send")
        XCTAssertTrue(app.staticTexts["Thank you!"].waitForExistence(timeout: 8))
        snap("53-feedback-sent")
        tap("Done")

        tap("Daily")
        sleep(1)
        snap("60-daily")

        // A friend's link, then your own.
        app.open(URL(string: "apticks://c/FRIEND1")!)
        XCTAssertTrue(app.buttons["Accept challenge"].waitForExistence(timeout: 10))
        snap("70-challenge-friend")
        app.buttons["Back to home"].firstMatch.tap()
        tap("Home")
        tap("Duel a friend")
        XCTAssertTrue(app.buttons["Send code"].waitForExistence(timeout: 10))
        snap("71-live-sign-in")
    }

    // A live friend duel against the pretend friend: sign in, lobby, the
    // countdown, five questions together, the result.
    @MainActor
    func testLiveDuel() {
        // A room opens in the subject open on Home: start on Aptitude.
        // The pretend friend joins after 6 s, so the lobby is there to see.
        launch(extra: ["-apticks-subject", "aptitude", "-FakeFriendDelay", "6"])
        tap("Duel a friend")
        let email = app.textFields["Email"].firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        snap("80-live-sign-in")
        email.tap()
        email.typeText("asha@test.local")
        tap("Send code")
        let code = app.textFields["Code"].firstMatch
        XCTAssertTrue(code.waitForExistence(timeout: 10))
        code.tap()
        code.typeText("123456")
        if app.buttons["Continue"].waitForExistence(timeout: 1) { app.buttons["Continue"].tap() }
        tap("Confirm")
        XCTAssertTrue(app.staticTexts["Waiting for your friend"].waitForExistence(timeout: 10))
        snap("81-live-lobby")
        // The countdown is short, so its picture is a bonus.
        if app.staticTexts["Same 5 questions, same moment. Fast and right wins."].waitForExistence(timeout: 12) { snap("82-live-countdown") }
        // The race: no waiting between questions, the friend's progress alongside.
        let answers = ["B: 25%", "Option C", "B: ₹2,100", "D: 71", "A: Scarce"]
        for (i, answer) in answers.enumerated() {
            XCTAssertTrue(app.staticTexts["Question \(i + 1) of 5"].waitForExistence(timeout: 20))
            let option = app.buttons[answer].firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 10))
            if i == 0 { snap("83-live-question") }
            if i == 2 { snap("84-live-progress") }
            option.tap()
        }
        // Done first: waiting for the friend, with their progress.
        if app.staticTexts["Waiting for Kavya R"].waitForExistence(timeout: 10) { snap("85-live-waiting") }
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Rematch'")).firstMatch.waitForExistence(timeout: 20))
        sleep(1)
        snap("86-live-result")
    }

    // A friend duel in Coding: the host switches the subject in the lobby
    // while waiting (the pretend friend is late here).
    @MainActor
    func testLiveSubject() {
        launch(extra: ["-FakeFriendDelay", "120", "-apticks-subject", "aptitude"])
        tap("Duel a friend")
        let email = app.textFields["Email"].firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.typeText("asha@test.local")
        tap("Send code")
        let code = app.textFields["Code"].firstMatch
        XCTAssertTrue(code.waitForExistence(timeout: 10))
        code.tap()
        code.typeText("123456")
        if app.buttons["Continue"].waitForExistence(timeout: 1) { app.buttons["Continue"].tap() }
        tap("Confirm")
        XCTAssertTrue(app.staticTexts["Waiting for your friend"].waitForExistence(timeout: 10))
        let coding = app.buttons["room-subject-coding"]
        XCTAssertTrue(coding.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["room-subject-aptitude"].isSelected)
        snap("87-live-subject-aptitude")
        coding.tap()
        XCTAssertTrue(coding.isSelected)
        sleep(2)
        snap("88-live-subject-coding")
    }

    // The placement test countdown, on the last page of home's Today deck.
    @MainActor
    func testDriveCard() {
        launch(tour: false)
        tap("Placement test", timeout: 10)
        XCTAssertTrue(app.staticTexts["When's your placement test?"].waitForExistence(timeout: 5))
        sleep(1)
        snap("90-drive-prompt")
        tap("Set my test")
        XCTAssertTrue(app.buttons["Start countdown"].waitForExistence(timeout: 5))
        sleep(1)
        snap("91-drive-form")
        tap("Start countdown")
        XCTAssertTrue(app.staticTexts["days to go"].waitForExistence(timeout: 10))
        sleep(1)
        snap("92-drive-countdown")
    }

    // Today's Daily Challenge, then back home: today's bubble is filled,
    // and the calendar shows every day done.
    @MainActor
    func testDailyFillsToday() {
        launch(tour: false)
        let today = app.otherElements.matching(NSPredicate(format: "label ENDSWITH ', today'")).firstMatch
        XCTAssertTrue(today.waitForExistence(timeout: 10))
        let day = String(today.label.prefix(3))
        tap("Play today's set")
        for i in 1...5 {
            XCTAssertTrue(app.staticTexts["Question \(i) of 5"].waitForExistence(timeout: 15))
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'A: ' OR label BEGINSWITH 'Option A'")).firstMatch.tap()
        }
        let home = app.buttons["Back to home"].firstMatch
        XCTAssertTrue(home.waitForExistence(timeout: 15))
        home.tap()
        // Home stays on the Daily page to show the day filling in.
        XCTAssertTrue(app.otherElements["\(day), done"].waitForExistence(timeout: 10), "\(day) isn't filled in")
        XCTAssertTrue(app.buttons["See today's rank"].waitForExistence(timeout: 5))
        sleep(1)
        snap("97-daily-done")
        tap("View all days")
        XCTAssertTrue(app.staticTexts["Daily calendar"].waitForExistence(timeout: 5))
        sleep(1)
        snap("98-daily-calendar")
        app.buttons["Previous month"].tap()
        sleep(1)
        snap("99-daily-calendar-last-month")
    }

    // Today's Daily Challenge, started from the calendar sheet.
    @MainActor
    func testDailyFromCalendar() {
        launch(tour: false)
        tap("View all days", timeout: 10)
        XCTAssertTrue(app.staticTexts["Daily calendar"].waitForExistence(timeout: 5))
        tap("Play today's set")
        XCTAssertTrue(app.staticTexts["Question 1 of 5"].waitForExistence(timeout: 15), "The Daily didn't open")
        sleep(1)
        snap("100-daily-from-calendar")
    }

    // Home on one screen: the deck's pages by swipe and by tab, then a
    // company duel from the company sheet.
    @MainActor
    func testHomeDeckAndCompanies() {
        launch(tour: false)
        XCTAssertTrue(app.buttons["Quick Match"].waitForExistence(timeout: 10))
        sleep(1)
        snap("93-home")
        app.buttons["Play today's set"].firstMatch.swipeLeft()
        XCTAssertTrue(app.buttons["Win 2 Quick Matches"].waitForExistence(timeout: 5))
        sleep(1)
        snap("94-home-goals")
        tap("Daily Challenge")
        sleep(1)
        tap("Company prep")
        XCTAssertTrue(app.buttons["Cognizant"].waitForExistence(timeout: 5))
        sleep(1)
        snap("95-company-sheet")
        tap("Cognizant")
        XCTAssertTrue(app.staticTexts["Question 1 of 5"].waitForExistence(timeout: 15))
        snap("96-company-duel")
    }
}
