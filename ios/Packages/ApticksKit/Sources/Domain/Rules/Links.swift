import Foundation

// Challenge links point at the website, so friends without the app can play.
// Links made before the move to playapticks.in still say aptiduel.vercel.app;
// that address stays up and opens in the app too (see Apticks.entitlements),
// and route(from:) reads the path, whichever address it's on.
public enum Links {
    public static let site = "https://www.playapticks.in"

    public static func challenge(_ code: String) -> String { "\(site)/c/\(code)" }
    // A shared Daily: who sent it and how they did, never the questions.
    public static func daily(_ code: String) -> String { "\(site)/d/\(code)" }
    // Nobody can tap a Story picture, so this goes on Instagram's Link sticker.
    public static let story = "\(site)/?via=story"

    // Pages the App Store listing and the app both point to.
    public static let privacyPolicy = URL(string: "\(site)/privacy")!
    public static let support = URL(string: "\(site)/support")!

    // The code in a challenge link: apticks://c/CODE or https://…/c/CODE.
    public static func challengeCode(from url: URL) -> String? {
        if case let .challenge(code) = route(from: url) { return code }
        return nil
    }

    // Where a link into the app leads. The website's /c, /duel and /play
    // pages open in the app once universal links are set up
    // (web/public/apple-app-site-association), so each needs a screen.
    public static func route(from url: URL) -> AppLink? {
        var parts = url.pathComponents.filter { $0 != "/" }
        if url.scheme == "apticks", let host = url.host() { parts.insert(host, at: 0) }
        switch parts.first {
        case "c":
            guard parts.count >= 2, parts[1].wholeMatch(of: /[A-Za-z0-9]{4,12}/) != nil else { return nil }
            return .challenge(parts[1])
        case "duel":
            guard parts.count >= 2, UUID(uuidString: parts[1]) != nil else { return nil }
            return parts.count >= 3 && parts[2] == "result" ? .result(parts[1]) : .duel(parts[1])
        case "play":
            guard parts.count >= 2 else { return .play(nil) }
            guard let company = COMPANIES.first(where: { $0.slug == parts[1] && !$0.comingSoon }) else { return nil }
            return .play(company)
        default:
            return nil
        }
    }
}

public enum AppLink: Hashable, Sendable {
    case challenge(String)
    case duel(String)
    case result(String)
    case play(Company?) // nil: a quick match
}

// For a challenge you haven't played yet: no score to beat.
public func inviteShareText(_ name: String, _ code: String, _ subject: Subject = .aptitude) -> String {
    switch subject {
    case .english:
        "\(name) challenged you to an English duel on Apticks. Same 5 questions for both of you: vocabulary, grammar and usage. About 3 minutes, no sign-up: \(Links.challenge(code))"
    case .coding:
        "\(name) challenged you to a coding duel on Apticks. Same 5 short programs for both of you: say what each one prints, in C, C++, Java, Python or pseudocode. About 4 minutes, no sign-up: \(Links.challenge(code))"
    case .aptitude:
        "\(name) challenged you to an aptitude duel on Apticks. Same 5 placement questions for both of you, about 3 minutes, no sign-up: \(Links.challenge(code))"
    }
}

// For a live room: the friend joins and you play at the same time.
public func liveInviteText(_ name: String, _ code: String, _ subject: Subject = .aptitude) -> String {
    switch subject {
    case .english:
        "\(name) wants a live English duel with you on Apticks: the same 5 questions at the same time, vocabulary, grammar and usage. About 3 minutes. Join here: \(Links.challenge(code))"
    case .coding:
        "\(name) wants a live coding duel with you on Apticks: the same 5 short programs at the same time, say what each one prints. C, C++, Java, Python or pseudocode, about 4 minutes. Join here: \(Links.challenge(code))"
    case .aptitude:
        "\(name) wants to duel you live on Apticks: the same 5 placement aptitude questions at the same time, about 3 minutes. Join here: \(Links.challenge(code))"
    }
}

public func challengeShareText(_ name: String, _ correct: Int, _ ms: Int, _ code: String, _ subject: Subject = .aptitude) -> String {
    let what = switch subject {
    case .aptitude: "5 placement aptitude questions, 3 minutes"
    case .coding: "5 short programs, say what each one prints, 4 minutes"
    case .english: "5 English questions on vocabulary and grammar, 3 minutes"
    }
    return "\(name) scored \(correct)/5 in \(clock(ms)) on Apticks. Think you can beat that? \(what): \(Links.challenge(code))"
}

// Today's Daily, for WhatsApp: a grid that shows how you did, never which
// questions, so friends can still play the same set.
public func dailyShareText(day: String, correct: Int, totalMs: Int, grid: [Bool], streak: Int, code: String) -> String {
    var lines = ["Apticks Daily · \(shortDay(day))", "\(answerGrid(grid))  \(correct)/5 · \(clock(totalMs))"]
    if streak >= 2 { lines.append("🔥 \(streak)-day streak") }
    lines += ["", "Same 5 placement questions for everyone today. Can you beat me? \(Links.daily(code))"]
    return lines.joined(separator: "\n")
}
