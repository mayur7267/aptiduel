import Domain
import Foundation
import Networking

// An in-memory Apticks backend: a guest with some history, a bot to duel,
// leaderboards and a friend's challenge. It answers with the same JSON
// shapes as the database and decodes them with the app's own decoder, so
// previews, UI runs (launch with -FakeBackend) and unit tests go through
// the real decoding path without touching production data.
@MainActor
public final class FakeBackend: APIClient, AccountClient {
    public var latency: Duration
    public var timeLimitMs: Int
    public var now: () -> Date
    // Every call fails as if the connection dropped (for tests).
    public var offline = false

    public init(latency: Duration = .milliseconds(250), timeLimitMs: Int = 40_000, now: @escaping () -> Date = Date.init) {
        self.latency = latency
        self.timeLimitMs = timeLimitMs
        self.now = now
    }

    // Starts the pretend player off as someone in particular, for
    // screenshots (see the -FakeName launch argument in AppContainer).
    public func start(as name: String, rating: Int, collegeId: Int?, gradYear: Int?) {
        self.name = name
        self.rating = rating
        self.collegeId = collegeId
        self.gradYear = gradYear
        // Someone with a saved account, not a guest.
        meId = "7c2e9a41-5b08-4d36-9f1a-c3d8e2b60a17"
        guest = false
        email = "\(name.lowercased().replacingOccurrences(of: " ", with: "."))@college.edu"
    }

    // A rating already earned in Coding or English, for screenshots
    // (-FakeCodingRating, -FakeEnglishRating).
    public func setRating(_ subject: Subject, _ value: Int, games: Int) {
        switch subject {
        case .coding: codingRating = value; codingGames = games
        case .english: englishRating = value; englishGames = games
        case .aptitude: rating = value
        }
    }

    // MARK: State

    struct Answer {
        let choice: Int?
        let correct: Bool
        let points: Int
        let ms: Int
    }

    final class Run {
        let id: String
        let code: String
        let mode: DuelMode
        var subject: Subject
        let company: String?
        let isCreator: Bool
        let opponentName: String?
        let opponentIsBot: Bool
        var answers: [Answer] = []
        var openedAt: Date?
        var ratingBefore: Int?
        var ratingAfter: Int?

        init(id: String, code: String, mode: DuelMode, subject: Subject = .aptitude, company: String?, isCreator: Bool, opponentName: String?, opponentIsBot: Bool) {
            self.id = id
            self.code = code
            self.mode = mode
            self.subject = subject
            self.company = company
            self.isCreator = isCreator
            self.opponentName = opponentName
            self.opponentIsBot = opponentIsBot
        }

        var finished: Bool { answers.count >= FakeBackend.questions.count }
    }

    private(set) var runs: [String: Run] = [:]
    private var order: [String] = []
    private var counter = 0
    private var name = "Player 4821"
    private var collegeId: Int?
    private var gradYear: Int?
    private var rating = 1180
    // Coding has its own rating (0022_subjects.sql).
    private var codingRating = 1000
    private var codingGames = 0
    private var englishRating = 1000
    private var englishGames = 0
    private var guest = true
    // The pretend player's id (the number on the Profile card is made from it).
    private var meId = "fake-user"
    private var email: String?
    private var pendingEmail: String?
    private var ownChallengeCode: String?
    // Live rooms, by duel id (see "Live duels" below).
    private var rooms: [String: LiveRoom] = [:]
    // How long the pretend friend takes to join your room, and how fast
    // they answer (a fraction of the bot's times).
    public var friendJoinDelay: TimeInterval = 2
    public var friendPace = 0.25
    static let friendName = "Kavya R"
    // The test you're preparing for, and what you said about it.
    private var driveCompany: String?
    private var driveOn: String?
    private var driveResult: (cleared: String, difficulty: String?)?

    static let colleges: [(Int, String)] = [(1, "VIT Vellore"), (2, "IIT Bombay"), (3, "NIT Trichy"), (4, "BITS Pilani"), (5, "Anna University")]

    struct FakeQuestion {
        let section: String
        let topic: String
        let body: String
        let options: [String]
        let correctIdx: Int
        let explanation: String
        var figure: String? = nil
        var optionFigures: [String]? = nil
        var code: [String: String]? = nil
    }

    static let questions: [FakeQuestion] = [
        FakeQuestion(section: "quant", topic: "Profit & Loss",
                     body: "The cost price of 20 articles equals the selling price of 16. What is the profit percentage?",
                     options: ["20%", "25%", "16%", "30%"], correctIdx: 1,
                     explanation: "CP of 20 = SP of 16, so on 16 articles the profit is the CP of 4. Profit % = 4/16 × 100 = 25%."),
        FakeQuestion(section: "reasoning", topic: "Figure Series", body: "Which figure comes next in the series?",
                     options: ["Figure A", "Figure B", "Figure C", "Figure D"], correctIdx: 0,
                     explanation: "The figure turns 135° anticlockwise at every step. Turning the last figure 135° anticlockwise once more gives option A.",
                     figure: SeedFigures.series, optionFigures: SeedFigures.options),
        FakeQuestion(section: "quant", topic: "Interest",
                     body: "What is the compound interest on ₹10,000 at 10% per annum for 2 years, compounded annually?",
                     options: ["₹3,100", "₹2,100", "₹2,200", "₹2,000"], correctIdx: 1,
                     explanation: "CI = P[(1 + r/100)² − 1] = ₹10,000 × [1.1² − 1] = ₹2,100."),
        FakeQuestion(section: "reasoning", topic: "Odd One Out", body: "Find the odd one out: 42, 56, 84, 71",
                     options: ["84", "56", "42", "71"], correctIdx: 3, explanation: "42, 84, 56 are multiples of 7. 71 is not."),
        FakeQuestion(section: "verbal", topic: "Synonyms", body: "Choose the word closest in meaning to ABUNDANT.",
                     options: ["Scarce", "Plentiful", "Ordinary", "Hidden"], correctIdx: 1,
                     explanation: "Abundant means existing in large quantities: plentiful."),
    ]

    // English: five topics, as on the server (the real ones are made by
    // scripts/generate-verbal.ts).
    static let englishQuestions: [FakeQuestion] = [
        FakeQuestion(section: "verbal", topic: "Synonyms", body: "Choose the word closest in meaning to CANDID.",
                     options: ["Evasive", "Frank", "Guarded", "Fragile"], correctIdx: 1,
                     explanation: "Candid means \"truthful and straightforward\". Frank is the closest in meaning."),
        FakeQuestion(section: "verbal", topic: "Idioms", body: "What does the idiom \"bury the hatchet\" mean?",
                     options: ["Make peace", "Hide a secret", "Give up a fight", "Work very hard"], correctIdx: 0,
                     explanation: "\"Bury the hatchet\" means make peace."),
        FakeQuestion(section: "verbal", topic: "Fill in the blanks", body: "Fill in the blank: Neha is good ___ mathematics and science.",
                     options: ["in", "at", "on", "with"], correctIdx: 1,
                     explanation: "We say \"good at\" a subject or skill."),
        FakeQuestion(section: "verbal", topic: "Active and passive voice", body: "Choose the passive form of this sentence:\n\"Ravi writes a letter.\"",
                     options: ["A letter was written by Ravi.", "A letter is being written by Ravi.", "A letter is written by Ravi.", "A letter has been written by Ravi."],
                     correctIdx: 2, explanation: "The sentence is in the simple present, and so is its passive: \"A letter is written by Ravi.\""),
        FakeQuestion(section: "verbal", topic: "Spelling", body: "Choose the correctly spelt word.",
                     options: ["Accomodate", "Acommodate", "Accommodate", "Accommodete"], correctIdx: 2,
                     explanation: "The correct spelling is \"accommodate\"."),
    ]

    // Coding: "what does this print?", each program in all five languages
    // (the real ones are made by scripts/generate-coding.ts).
    static let codingQuestions: [FakeQuestion] = [
        FakeQuestion(section: "coding", topic: "Loops", body: "What does this code print?",
                     options: ["10", "6", "15", "4"], correctIdx: 0,
                     explanation: "The loop adds i for i = 1 to 4: 1 + 2 + 3 + 4 = 10.",
                     code: ["c": "int s = 0;\nfor (int i = 1; i <= 4; i++) {\n  s += i;\n}\nprintf(\"%d \", s);",
                            "cpp": "int s = 0;\nfor (int i = 1; i <= 4; i++) {\n  s += i;\n}\ncout << s << \" \";",
                            "java": "int s = 0;\nfor (int i = 1; i <= 4; i++) {\n  s += i;\n}\nSystem.out.print(s + \" \");",
                            "python": "s = 0\nfor i in range(1, 5):\n    s += i\nprint(s, end=\" \")",
                            "pseudo": "Integer s = 0\nfor i = 1 to 4\n  s = s + i\nend for\nprint s"]),
        FakeQuestion(section: "coding", topic: "Operators", body: "What does this code print?",
                     options: ["3.4 2", "3 2", "2 3", "4 2"], correctIdx: 1,
                     explanation: "With whole numbers, / drops the fraction and % gives the remainder: 17 = 3 × 5 + 2.",
                     code: ["c": "int a = 17;\nint b = 5;\nprintf(\"%d \", a / b);\nprintf(\"%d \", a % b);",
                            "cpp": "int a = 17;\nint b = 5;\ncout << (a / b) << \" \";\ncout << (a % b) << \" \";",
                            "java": "int a = 17;\nint b = 5;\nSystem.out.print((a / b) + \" \");\nSystem.out.print((a % b) + \" \");",
                            "python": "a = 17\nb = 5\nprint(a // b, end=\" \")\nprint(a % b, end=\" \")",
                            "pseudo": "// \"/\" is integer division: 7 / 2 = 3\n\nInteger a = 17\nInteger b = 5\nprint a / b\nprint a mod b"]),
        FakeQuestion(section: "coding", topic: "Recursion", body: "What does this code print?",
                     options: ["12", "24", "120", "4"], correctIdx: 1,
                     explanation: "f(4) = 4 × f(3) = 4 × 3 × 2 × f(1), and f(1) = 1: 24.",
                     code: ["c": "int f(int n) {\n  if (n <= 1) return 1;\n  return n * f(n - 1);\n}\n\nprintf(\"%d \", f(4));",
                            "cpp": "int f(int n) {\n  if (n <= 1) return 1;\n  return n * f(n - 1);\n}\n\ncout << f(4) << \" \";",
                            "java": "static int f(int n) {\n  if (n <= 1) return 1;\n  return n * f(n - 1);\n}\n\nSystem.out.print(f(4) + \" \");",
                            "python": "def f(n):\n    if n <= 1:\n        return 1\n    return n * f(n - 1)\n\nprint(f(4), end=\" \")",
                            "pseudo": "function f(n)\n  if (n <= 1)\n    return 1\n  end if\n  return n * f(n - 1)\nend function\n\nprint f(4)"]),
        FakeQuestion(section: "coding", topic: "Arrays", body: "What does this code print?",
                     options: ["3", "2", "8", "13"], correctIdx: 2,
                     explanation: "m keeps the largest value seen so far: 3, then 8, and 2 doesn't beat it. It prints 8.",
                     code: ["c": "int a[] = {3, 8, 2};\nint m = a[0];\nfor (int i = 1; i <= 2; i++) {\n  if (a[i] > m) {\n    m = a[i];\n  }\n}\nprintf(\"%d \", m);",
                            "cpp": "int a[] = {3, 8, 2};\nint m = a[0];\nfor (int i = 1; i <= 2; i++) {\n  if (a[i] > m) {\n    m = a[i];\n  }\n}\ncout << m << \" \";",
                            "java": "int[] a = {3, 8, 2};\nint m = a[0];\nfor (int i = 1; i <= 2; i++) {\n  if (a[i] > m) {\n    m = a[i];\n  }\n}\nSystem.out.print(m + \" \");",
                            "python": "a = [3, 8, 2]\nm = a[0]\nfor i in range(1, 3):\n    if a[i] > m:\n        m = a[i]\nprint(m, end=\" \")",
                            "pseudo": "// Arrays start at index 0\n\nInteger a[] = {3, 8, 2}\nInteger m = a[0]\nfor i = 1 to 2\n  if (a[i] > m)\n    m = a[i]\n  end if\nend for\nprint m"]),
        FakeQuestion(section: "coding", topic: "While Loops", body: "What does this code print?",
                     options: ["321", "6", "3", "123"], correctIdx: 1,
                     explanation: "x % 10 is the last digit and x / 10 drops it, so the loop adds the digits: 1 + 2 + 3 = 6.",
                     code: ["c": "int x = 123;\nint s = 0;\nwhile (x > 0) {\n  s += x % 10;\n  x /= 10;\n}\nprintf(\"%d \", s);",
                            "cpp": "int x = 123;\nint s = 0;\nwhile (x > 0) {\n  s += x % 10;\n  x /= 10;\n}\ncout << s << \" \";",
                            "java": "int x = 123;\nint s = 0;\nwhile (x > 0) {\n  s += x % 10;\n  x /= 10;\n}\nSystem.out.print(s + \" \");",
                            "python": "x = 123\ns = 0\nwhile x > 0:\n    s += x % 10\n    x //= 10\nprint(s, end=\" \")",
                            "pseudo": "// \"/\" is integer division: 7 / 2 = 3\n\nInteger x = 123\nInteger s = 0\nwhile (x > 0)\n  s = s + x mod 10\n  x = x / 10\nend while\nprint s"]),
    ]

    private func questions(for r: Run) -> [FakeQuestion] {
        switch r.subject {
        case .coding: Self.codingQuestions
        case .english: Self.englishQuestions
        case .aptitude: Self.questions
        }
    }

    // How the bot (or a friend) played the same five questions.
    static let opponentRun: [(ms: Int, correct: Bool)] = [(14_000, true), (22_000, false), (18_000, true), (9_000, true), (12_000, false)]

    static func points(correct: Bool, ms: Int, limit: Int) -> Int {
        correct ? 100 + Int((50 * Double(max(0, limit - ms)) / Double(limit)).rounded()) : 0
    }

    // MARK: Helpers

    private func pause() async throws {
        if latency > .zero { try await Task.sleep(for: latency) }
        if offline { throw AppError("You're offline. Check your connection and try again.") }
    }

    private func decode<T: Decodable>(_ json: Any) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: json, options: [.fragmentsAllowed])
        return try Wire.decoder.decode(T.self, from: data)
    }

    private func opt(_ v: Any?) -> Any { v ?? NSNull() }

    private var collegeName: String? {
        Self.colleges.first { $0.0 == collegeId }?.1 ?? (Self.worldColleges + addedColleges).first { $0.id == collegeId }?.name
    }

    private func newRun(_ mode: DuelMode, subject: Subject = .aptitude, company: String? = nil, isCreator: Bool = false,
                        opponent: String?, bot: Bool) -> Run {
        counter += 1
        let run = Run(id: "fake-\(mode.rawValue)-\(counter)", code: "FAKE\(counter)", mode: mode, subject: subject, company: company,
                      isCreator: isCreator, opponentName: opponent, opponentIsBot: bot)
        runs[run.id] = run
        order.insert(run.id, at: 0)
        return run
    }

    private func run(_ id: String) throws -> Run {
        guard let r = runs[id] else { throw AppError("That duel doesn't exist.") }
        return r
    }

    // A question left open past its time counts as unanswered, as on the server.
    private func expire(_ r: Run) {
        guard let opened = r.openedAt, !r.finished else { return }
        if now().timeIntervalSince(opened) * 1000 > Double(timeLimitMs) + 1500 {
            r.answers.append(Answer(choice: nil, correct: false, points: 0, ms: timeLimitMs))
            r.openedAt = nil
            settle(r)
        }
    }

    private func settle(_ r: Run) {
        guard r.finished, r.ratingAfter == nil, r.mode != .daily, r.opponentName != nil else { return }
        // Like the server, a live race settles once both have finished.
        if r.mode == .live, friendAnswers(r.id).count < Self.questions.count { return }
        let mine = r.answers.reduce(0) { $0 + $1.points }
        let theirs = opponentTimeline().reduce(0) { $0 + (($1["points"] as? Int) ?? 0) }
        if r.subject == .coding {
            r.ratingBefore = codingRating
            codingRating += mine >= theirs ? 20 : -14
            codingGames += 1
            r.ratingAfter = codingRating
        } else if r.subject == .english {
            r.ratingBefore = englishRating
            englishRating += mine >= theirs ? 18 : -13
            englishGames += 1
            r.ratingAfter = englishRating
        } else {
            r.ratingBefore = rating
            rating += mine >= theirs ? 16 : -12
            r.ratingAfter = rating
        }
    }

    private func opponentTimeline() -> [[String: Any]] {
        Self.opponentRun.enumerated().map { i, s in
            ["q_index": i, "ms": s.ms, "correct": s.correct, "points": Self.points(correct: s.correct, ms: s.ms, limit: timeLimitMs)]
        }
    }

    private func meJSON() -> [String: Any] {
        let today = (Calendar(identifier: .iso8601).component(.weekday, from: now()) + 5) % 7
        let dailyDone = runs.values.contains { $0.mode == .daily && $0.finished }
        let quickWins = runs.values.filter { $0.mode == .quick && $0.finished && ($0.ratingAfter ?? 0) > ($0.ratingBefore ?? 0) }.count
        return [
            "id": meId, "name": name, "rating": rating, "games_played": 6 + runs.count, "wins": 3,
            "streak": 2, "streak_best": 5, "played_today": runs.values.contains { $0.finished },
            "college_id": opt(collegeId), "college": opt(collegeName), "grad_year": opt(gradYear),
            "college_rank": collegeId == nil ? NSNull() : 4, "today_idx": today,
            "daily_week": (0..<7).map { $0 < today ? $0 % 3 != 2 : $0 == today && dailyDone },
            "quests": ["daily": dailyDone ? 1 : 0, "quick_wins": quickWins, "accepted": 0],
        ]
    }

    private func playerJSON(name: String, rating: Int, college: String?, bot: Bool, answers: [(points: Int, correct: Bool, ms: Int)],
                            finished: Bool, before: Int?, after: Int?, seat: Int) -> [String: Any] {
        [
            "id": bot ? NSNull() : (seat == 1 ? meId : "fake-friend"),
            "seat": seat, "name": name, "rating": rating, "college": opt(college), "is_bot": bot,
            "tagline": bot ? "I never skip leg day. Or quant day." : NSNull(),
            "score": answers.reduce(0) { $0 + $1.points }, "correct": answers.filter(\.correct).count,
            "total_ms": answers.reduce(0) { $0 + $1.ms }, "answered": answers.count, "finished": finished,
            "is_replay": false, "rating_before": opt(before), "rating_after": opt(after),
        ]
    }

    private func duelJSON(_ r: Run) -> [String: Any] {
        let mine = r.answers.map { (points: $0.points, correct: $0.correct, ms: $0.ms) }
        var opponent: Any = NSNull()
        var timeline: Any = NSNull()
        if let opponentName = r.opponentName, r.mode == .live {
            let theirs = friendAnswers(r.id).map { (points: $0.points, correct: $0.correct, ms: $0.ms) }
            opponent = playerJSON(name: opponentName, rating: 1240, college: "NIT Trichy", bot: false,
                                  answers: theirs, finished: theirs.count >= Self.questions.count, before: nil, after: nil, seat: 2)
        } else if let opponentName = r.opponentName {
            let theirs = Self.opponentRun.map { (points: Self.points(correct: $0.correct, ms: $0.ms, limit: timeLimitMs), correct: $0.correct, ms: $0.ms) }
            opponent = playerJSON(name: opponentName, rating: 1205, college: r.opponentIsBot ? nil : "IIT Bombay", bot: r.opponentIsBot,
                                  answers: theirs, finished: true, before: nil, after: nil, seat: 2)
            timeline = opponentTimeline()
        }
        let review: Any = r.finished
            ? questions(for: r).enumerated().map { i, q in
                let a = r.answers[i]
                return [
                    "q_index": i, "section": q.section, "topic": q.topic, "companies": r.company.map { [$0] } ?? [],
                    "body": q.body, "figure": opt(q.figure), "code": opt(q.code), "options": q.options,
                    "option_figures": opt(q.optionFigures), "correct_idx": q.correctIdx, "chosen_idx": opt(a.choice), "is_correct": a.correct, "points": a.points,
                    "ms": a.ms, "explanation": q.explanation,
                    "opp_correct": r.opponentName == nil ? NSNull() : Self.opponentRun[i].correct,
                ] as [String: Any]
            }
            : NSNull()
        return [
            "id": r.id, "code": r.code, "mode": r.mode.rawValue, "subject": r.subject.rawValue, "company": opt(r.company),
            "status": r.finished ? "complete" : "open", "is_creator": r.isCreator,
            "me": playerJSON(name: name, rating: r.subject == .coding ? codingRating : r.subject == .english ? englishRating : rating, college: collegeName, bot: false, answers: mine,
                             finished: r.finished, before: r.ratingBefore, after: r.ratingAfter, seat: 1),
            "opponent": opponent, "opponent_timeline": timeline,
            "my_answers": r.answers.enumerated().map { ["q_index": $0.offset, "correct": $0.element.correct] },
            "review": review,
            "daily": r.mode == .daily && r.finished ? ["rank": 12, "players": 340] : NSNull(),
        ]
    }

    // MARK: APIClient

    public func me() async throws -> Me {
        try await pause()
        return try decode(meJSON())
    }

    public func myDuels(limit: Int) async throws -> [DuelSummary] {
        try await pause()
        let iso = ISO8601DateFormatter()
        var list: [[String: Any]] = order.prefix(limit).compactMap { runs[$0] }.map { r in
            let mine = r.answers
            return [
                "id": r.id, "mode": r.mode.rawValue, "subject": r.subject.rawValue, "company": opt(r.company),
                "status": r.finished ? "complete" : "open",
                "created_at": iso.string(from: now()), "code": r.isCreator ? r.code : NSNull(), "seat": 1, "is_replay": false,
                "score": mine.reduce(0) { $0 + $1.points }, "correct": mine.filter(\.correct).count,
                "total_ms": mine.reduce(0) { $0 + $1.ms }, "finished": r.finished,
                "rating_before": opt(r.ratingBefore), "rating_after": opt(r.ratingAfter),
                "opponent_name": opt(r.opponentName), "opponent_is_bot": r.opponentIsBot, "opponent_college": NSNull(),
                "opponent_is_replay": false, "opponent_score": r.opponentName == nil ? NSNull() : 412,
                "opponent_total_ms": r.opponentName == nil ? NSNull() : 75_000, "opponent_finished": r.opponentName == nil ? NSNull() : true,
            ]
        }
        // Some history from before.
        list.append([
            "id": "fake-history-1", "mode": "quick", "company": NSNull(), "status": "complete",
            "created_at": iso.string(from: now().addingTimeInterval(-86_400)), "code": NSNull(), "seat": 1, "is_replay": false,
            "score": 486, "correct": 4, "total_ms": 96_000, "finished": true, "rating_before": 1164, "rating_after": 1180,
            "opponent_name": "Kavya R", "opponent_is_bot": false, "opponent_college": "NIT Trichy", "opponent_is_replay": false,
            "opponent_score": 371, "opponent_total_ms": 120_000, "opponent_finished": true,
        ])
        return try decode(Array(list.prefix(limit)))
    }

    // Aptitude, as before (tests call it without a subject).
    public func leaderboard(_ scope: BoardScope, limit: Int) async throws -> Board {
        try await leaderboard(scope, limit: limit, subject: .aptitude)
    }

    public func leaderboard(_ scope: BoardScope, limit: Int, subject: Subject) async throws -> Board {
        try await pause()
        if scope == .college && collegeId == nil {
            return try decode(["scope": "college", "subject": subject.rawValue, "college": NSNull(), "players": 0, "rows": [], "me": NSNull()] as [String: Any])
        }
        // Each subject has its own order, and your own rating in it.
        let names = subject == .aptitude
            ? ["Aarav Shah", "Diya Patel", "Kabir Singh", "Ananya Iyer", name, "Ishaan Gupta", "Meera Nair", "Vivaan Rao"]
            : subject == .coding
                ? ["Kabir Singh", "Vivaan Rao", "Aarav Shah", "Meera Nair", name, "Diya Patel"]
                : ["Ananya Iyer", "Meera Nair", "Diya Patel", "Ishaan Gupta", name, "Kabir Singh"]
        let mine = subject == .coding ? codingRating : subject == .english ? englishRating : rating
        let rows: [[String: Any]] = names.enumerated().map { i, n in
            [
                "rank": i + 1, "name": n, "rating": n == name ? mine : 1640 - i * 70,
                "college": scope == .india ? Self.colleges[i % Self.colleges.count].1 : opt(collegeName),
                "grad_year": n == name ? (gradYear ?? 2026) : 2026 + i % 2, "week_delta": [42, 18, -6, 0, 16, -12, 30, 8][i], "is_me": n == name,
            ]
        }
        return try decode([
            "scope": scope.rawValue, "subject": subject.rawValue, "college": scope == .college ? opt(collegeName) : NSNull(),
            "players": scope == .college ? 48 : 12_480, "rows": Array(rows.prefix(limit)), "me": rows[4],
        ] as [String: Any])
    }

    public func colleges() async throws -> [College] {
        try await pause()
        return try decode(Self.colleges.map { ["id": $0.0, "name": $0.1] })
    }

    // A few colleges abroad too, as the real list has (0027).
    static let worldColleges: [College] = [
        College(id: 1, name: "VIT Vellore", city: "Vellore", country: "IN", players: 48),
        College(id: 2, name: "IIT Bombay", city: "Mumbai", country: "IN", players: 12),
        College(id: 3, name: "NIT Trichy", city: "Tiruchirappalli", country: "IN", players: 9),
        College(id: 4, name: "BITS Pilani", city: "Pilani", country: "IN", players: 7),
        College(id: 5, name: "Anna University", city: "Chennai", country: "IN", players: 3),
        College(id: 101, name: "Massachusetts Institute of Technology", city: "Cambridge", country: "US", players: 0),
        College(id: 102, name: "University of Oxford", city: "Oxford", country: "GB", players: 0),
        College(id: 103, name: "University of Lagos", city: "Lagos", country: "NG", players: 0),
        College(id: 104, name: "Technical University of Munich", city: "Munich", country: "DE", players: 0),
    ]
    private var addedColleges: [College] = []

    public func searchColleges(_ query: String, country: String?) async throws -> [College] {
        try await pause()
        let words = query.lowercased().split(separator: " ").map(String.init)
        guard query.trimmingCharacters(in: .whitespaces).count >= 2 else { return [] }
        return (Self.worldColleges + addedColleges).filter { c in
            let text = "\(c.name) \(c.city ?? "")".lowercased()
            return words.allSatisfy { text.contains($0) }
        }
    }

    public func addCollege(name: String, city: String?, country: String) async throws -> Int {
        try await pause()
        guard (3...120).contains(name.count) else { throw AppError("College names are 3 to 120 characters.") }
        let c = College(id: 900 + addedColleges.count, name: name, city: city, country: country, players: 0)
        addedColleges.append(c)
        return c.id
    }

    public func updateProfile(name: String, collegeId: Int?, gradYear: Int?) async throws -> Me {
        try await pause()
        guard (2...24).contains(name.count) else { throw AppError("Names are 2 to 24 characters.") }
        self.name = name
        self.collegeId = collegeId
        self.gradYear = gradYear
        return try decode(meJSON())
    }

    public func collegeCard(_ id: Int) async throws -> CollegeCard? {
        try await pause()
        let known = Self.colleges.first { $0.0 == id }.map { College(id: $0.0, name: $0.1) }
            ?? (Self.worldColleges + addedColleges).first { $0.id == id }
        guard let c = known else { return nil }
        // VIT Vellore has a board; anywhere else is waiting for its first player.
        let top: [CollegeCard.Top] = id == 1 ? [.init(name: "Kabir S.", rating: 1640), .init(name: "Vivaan R.", rating: 1570), .init(name: "Aarav S.", rating: 1508)] : []
        return CollegeCard(id: c.id, name: c.name, city: c.city, country: c.country, players: id == 1 ? 48 : 0, top: top)
    }

    public func joinCollege(_ id: Int) async throws -> Me {
        guard try await collegeCard(id) != nil else { throw AppError("Unknown college.") }
        collegeId = id
        return try decode(meJSON())
    }

    public func myStreak() async throws -> StreakInfo {
        let me = try await me()
        let top: [StreakInfo.Top] = collegeId == nil ? [] : [.init(name: "Kabir S.", streak: 21, isMe: false), .init(name: name, streak: me.streak, isMe: true), .init(name: "Diya P.", streak: 3, isMe: false)]
        return StreakInfo(streak: me.streak, best: max(me.streakBest, me.streak), playedToday: me.playedToday,
                          days: Streak.days(streak: me.streak, playedToday: me.playedToday), college: me.college, collegeTop: top)
    }

    public func quickMatch(_ subject: Subject) async throws -> MatchStart {
        try await pause()
        // As on the server: finish an open quick match (any subject) first.
        if let open = order.compactMap({ runs[$0] }).first(where: { $0.mode == .quick && !$0.finished && !$0.answers.isEmpty }) {
            return try decode(["duel_id": open.id, "resumed": true])
        }
        return try decode(["duel_id": newRun(.quick, subject: subject, opponent: "Bolt", bot: true).id, "resumed": false])
    }

    // Aptitude, as before (tests call it without a subject).
    public func quickMatch() async throws -> MatchStart { try await quickMatch(.aptitude) }

    public func mySubjects() async throws -> SubjectRatings {
        try await pause()
        return try decode([
            "aptitude": ["rating": rating, "games": 6 + runs.count],
            "coding": ["rating": codingRating, "games": codingGames],
            "english": ["rating": englishRating, "games": englishGames],
        ])
    }

    public func companyMatch(_ company: String) async throws -> MatchStart {
        try await pause()
        return try decode(["duel_id": newRun(.quick, company: company, opponent: "Bolt", bot: true).id, "resumed": false])
    }

    public func dailyChallenge() async throws -> DuelRef {
        try await pause()
        let daily = runs.values.first { $0.mode == .daily } ?? newRun(.daily, opponent: nil, bot: false)
        return try decode(["duel_id": daily.id])
    }

    public func duel(_ id: String) async throws -> Duel {
        try await pause()
        let r = try run(id)
        expire(r)
        settle(r)
        return try decode(duelJSON(r))
    }

    public func nextQuestion(_ duelId: String) async throws -> QuestionView {
        try await pause()
        if liveNotStarted(duelId) { throw AppError("The duel hasn't started yet.") }
        let r = try run(duelId)
        expire(r)
        let score = r.answers.reduce(0) { $0 + $1.points }
        if r.finished { return try decode(["done": true, "score": score]) }
        let i = r.answers.count
        let q = questions(for: r)[i]
        if r.openedAt == nil { r.openedAt = now() }
        let elapsed = Int(now().timeIntervalSince(r.openedAt!) * 1000)
        return try decode([
            "done": false, "q_index": i, "total": Self.questions.count, "section": q.section, "topic": q.topic,
            "companies": r.company.map { [$0] } ?? [], "difficulty": 2, "body": q.body, "figure": opt(q.figure),
            "code": opt(q.code), "options": q.options, "option_figures": opt(q.optionFigures), "time_limit_ms": timeLimitMs,
            "remaining_ms": max(0, timeLimitMs - elapsed), "score": score,
        ] as [String: Any])
    }

    public func submitAnswer(_ duelId: String, question: Int, choice: Int?) async throws -> AnswerResult {
        try await pause()
        let r = try run(duelId)
        guard question == r.answers.count, !r.finished else { throw AppError("You already answered this question.") }
        let q = questions(for: r)[question]
        let ms = min(timeLimitMs, Int(now().timeIntervalSince(r.openedAt ?? now()) * 1000))
        let correct = choice == q.correctIdx
        let points = Self.points(correct: correct, ms: ms, limit: timeLimitMs)
        r.answers.append(Answer(choice: choice, correct: correct, points: points, ms: ms))
        r.openedAt = nil
        settle(r)
        return try decode([
            "correct": correct, "correct_idx": q.correctIdx, "points": points,
            "score": r.answers.reduce(0) { $0 + $1.points }, "elapsed_ms": ms, "done": r.finished,
        ] as [String: Any])
    }

    public func createChallenge() async throws -> NewChallenge {
        try await pause()
        let r = newRun(.challenge, isCreator: true, opponent: nil, bot: false)
        ownChallengeCode = r.code
        return try decode(["duel_id": r.id, "code": r.code])
    }

    public func shareCode(_ duelId: String) async throws -> ShareCode {
        try await pause()
        counter += 1
        return try decode(["code": "SHARE\(counter)"])
    }

    public func challenge(_ code: String) async throws -> Challenge? {
        try await pause()
        if let room = rooms.values.first(where: { $0.code == code.uppercased() }) {
            tick(room)
            return try decode(liveChallengeJSON(code: room.code, mine: true, started: room.startsAt != nil, subject: room.subject))
        }
        if code.uppercased().hasPrefix("LIVE") { return try decode(liveChallengeJSON(code: code.uppercased(), mine: false, started: false)) }
        guard code.uppercased().hasPrefix("FRIEND") else { return try decode(NSNull()) }
        return try decode([
            "code": code, "open": true,
            "challenger": ["name": "Rohan Mehta", "rating": 1320, "college": "IIT Bombay", "grad_year": 2026],
            "challenger_finished": true, "score": 412, "correct": 3, "total_ms": 75_000, "accepted_count": 2,
        ] as [String: Any])
    }

    public func challengeStatus(_ code: String) async throws -> ChallengeStatus? {
        try await pause()
        guard code == ownChallengeCode, let r = runs.values.first(where: { $0.code == code }) else { return try decode(NSNull()) }
        let mine = r.answers
        return try decode([
            "duel_id": r.id, "code": code, "open": true,
            "me": ["name": name, "finished": r.finished, "score": mine.reduce(0) { $0 + $1.points },
                   "correct": mine.filter(\.correct).count, "total_ms": mine.reduce(0) { $0 + $1.ms }],
            "friends": [["duel_id": "fake-friend-1", "name": "Kavya R", "college": "NIT Trichy", "finished": true,
                         "score": 371, "correct": 3, "total_ms": 120_000]],
        ] as [String: Any])
    }

    public func joinChallenge(_ code: String) async throws -> DuelRef {
        try await pause()
        guard code.uppercased().hasPrefix("FRIEND") else { throw AppError("This challenge has expired.") }
        return try decode(["duel_id": newRun(.challenge, opponent: "Rohan Mehta", bot: false).id])
    }

    // What's been sent, newest last (for tests and previews).
    public private(set) var feedback: [FeedbackDraft] = []

    public func sendFeedback(_ draft: FeedbackDraft) async throws {
        try await pause()
        guard draft.isSendable else { throw AppError("Tell us a little more.") }
        guard feedback.count < 5 else { throw AppError("Thanks, that's a lot at once! Try again in a little while.") }
        feedback.append(draft)
    }

    public struct LoggedShare: Equatable, Sendable {
        public let kind: ShareKind
        public let channel: ShareChannel
        public let duelId: String?

        public init(kind: ShareKind, channel: ShareChannel, duelId: String?) {
            self.kind = kind
            self.channel = channel
            self.duelId = duelId
        }
    }

    public private(set) var shares: [LoggedShare] = []

    public func logShare(_ kind: ShareKind, _ channel: ShareChannel, duelId: String?) async throws {
        try await pause()
        shares.append(LoggedShare(kind: kind, channel: channel, duelId: duelId))
    }

    // MARK: AccountClient

    public func info() async throws -> AccountInfo {
        try await pause()
        return AccountInfo(guest: guest, email: email)
    }

    public func sendSaveCode(_ email: String) async throws {
        try await pause()
        guard email.contains("@") else { throw AppError("Enter a valid email address.") }
        pendingEmail = email
    }

    // The code is always 123456.
    public func confirmSaveCode(_ email: String, code: String) async throws {
        try await pause()
        guard code == "123456", pendingEmail == email else { throw AppError("That code is wrong or has expired.") }
        guest = false
        self.email = email
    }

    public func sendSignInCode(_ email: String) async throws {
        try await pause()
        pendingEmail = email
    }

    public func confirmSignInCode(_ email: String, code: String) async throws {
        try await confirmSaveCode(email, code: code)
    }

    public func signOut() async throws {
        try await pause()
        reset()
    }

    public func deleteAccount() async throws {
        try await pause()
        reset()
    }

    private func reset() {
        runs = [:]
        order = []
        name = "Player \(Int.random(in: 1000...9999))"
        collegeId = nil
        gradYear = nil
        rating = 1000
        guest = true
        email = nil
    }
}

// MARK: - Live duels

// A pretend friend joins your room after friendJoinDelay, the race starts
// 5 s later, and they answer each question at friendPace of the bot's
// times (with a second between questions), as on the server: the first
// question opens for both at the start, then each goes at their own pace.
extension FakeBackend {
    final class LiveRoom {
        let id: String
        let code: String
        let hostIsMe: Bool
        var subject: Subject
        var friendArrives: Date?
        var startsAt: Date?
        var playedNow = false
        var closed = false
        var rematchId: String?

        init(id: String, code: String, hostIsMe: Bool, subject: Subject, friendArrives: Date?) {
            self.id = id
            self.code = code
            self.hostIsMe = hostIsMe
            self.subject = subject
            self.friendArrives = friendArrives
        }
    }

    private func room(_ id: String) throws -> LiveRoom {
        guard let r = rooms[id] else { throw AppError("You are not in this duel.") }
        return r
    }

    private func newRoom(hostIsMe: Bool, subject: Subject = .aptitude, friendArrives: Date?) -> LiveRoom {
        counter += 1
        let r = LiveRoom(id: "fake-live-\(counter)", code: "LIVE\(counter)", hostIsMe: hostIsMe, subject: subject, friendArrives: friendArrives)
        rooms[r.id] = r
        let run = Run(id: r.id, code: r.code, mode: .live, subject: subject, company: nil, isCreator: false,
                      opponentName: hostIsMe ? Self.friendName : "Rohan Mehta", opponentIsBot: false)
        runs[run.id] = run
        order.insert(run.id, at: 0)
        return r
    }

    private func ms(_ d: Date?) -> Any { d.map { Int(($0.timeIntervalSince1970 * 1000).rounded()) } ?? NSNull() }

    private func tick(_ room: LiveRoom) {
        if room.startsAt == nil, !room.playedNow, !room.closed, let arrives = room.friendArrives, now() >= arrives {
            room.startsAt = arrives.addingTimeInterval(5)
        }
    }

    // A live duel opened before its countdown ended.
    func liveNotStarted(_ id: String) -> Bool {
        guard let room = rooms[id], !room.playedNow else { return false }
        tick(room)
        guard let start = room.startsAt, now() >= start else { return true }
        // The first question opened for both at the start.
        if let r = runs[id], r.answers.isEmpty, r.openedAt == nil { r.openedAt = start }
        return false
    }

    // The pretend friend's answers so far.
    func friendAnswers(_ id: String) -> [Answer] {
        guard let room = rooms[id], let start = room.startsAt else { return [] }
        var at = start
        var done: [Answer] = []
        let qs = runs[id].map { questions(for: $0) } ?? Self.questions
        for (k, step) in Self.opponentRun.enumerated() {
            let ms = Int(Double(step.ms) * friendPace)
            at = at.addingTimeInterval(Double(ms) / 1000)
            guard now() >= at else { break }
            let q = qs[k]
            done.append(Answer(choice: step.correct ? q.correctIdx : (q.correctIdx + 1) % 4, correct: step.correct,
                               points: Self.points(correct: step.correct, ms: ms, limit: timeLimitMs), ms: ms))
            at = at.addingTimeInterval(1)
        }
        return done
    }

    private func liveChallengeJSON(code: String, mine: Bool, started: Bool, subject: Subject = .aptitude) -> [String: Any] {
        [
            "code": code, "open": true, "live": true, "started": started, "full": started, "my_seat": mine ? 1 : NSNull(),
            "subject": subject.rawValue,
            "challenger": mine
                ? ["name": name, "rating": rating, "college": opt(collegeName), "grad_year": opt(gradYear)] as [String: Any]
                : ["name": "Rohan Mehta", "rating": 1320, "college": "IIT Bombay", "grad_year": 2026],
            "challenger_finished": false, "score": 0, "correct": 0, "total_ms": 0, "accepted_count": started ? 1 : 0,
        ]
    }

    private func progressJSON(id: String, seat: Int, name: String, rating: Int, college: String?, answers: [Answer]) -> [String: Any] {
        [
            "id": id, "seat": seat, "name": name, "rating": rating, "college": opt(college), "present": true,
            "answered": answers.count, "correct": answers.filter(\.correct).count, "score": answers.reduce(0) { $0 + $1.points },
            "finished": answers.count >= Self.questions.count, "marks": answers.map(\.correct),
        ]
    }

    private func liveJSON(_ room: LiveRoom) -> [String: Any] {
        tick(room)
        let mine = runs[room.id]?.answers ?? []
        let theirs = friendAnswers(room.id)
        let done = mine.count >= 5 && theirs.count >= 5
        let status = room.playedNow ? "async" : room.closed ? "closed" : room.startsAt == nil ? "waiting"
            : now() < room.startsAt! ? "starting" : done ? "done" : "playing"
        let arrived = room.friendArrives.map { now() >= $0 } ?? false
        let opponent: Any = arrived
            ? progressJSON(id: "fake-friend", seat: room.hostIsMe ? 2 : 1, name: room.hostIsMe ? Self.friendName : "Rohan Mehta",
                           rating: 1240, college: "NIT Trichy", answers: theirs)
            : NSNull()
        return [
            "id": room.id, "code": room.code, "status": status, "is_host": room.hostIsMe,
            "now_ms": ms(now()), "starts_at_ms": ms(room.startsAt),
            "me": progressJSON(id: meId, seat: room.hostIsMe ? 1 : 2, name: name, rating: rating, college: collegeName, answers: mine),
            "opponent": opponent, "rematch_id": opt(room.rematchId), "subject": room.subject.rawValue,
        ]
    }

    public func createRoom(_ subject: Subject) async throws -> RoomRef {
        try await pause()
        guard !guest else { throw AppError("Sign in to duel friends.") }
        let r = newRoom(hostIsMe: true, subject: subject, friendArrives: now().addingTimeInterval(friendJoinDelay))
        return try decode(["duel_id": r.id, "code": r.code])
    }

    // Aptitude, as before (tests call it without a subject).
    public func createRoom() async throws -> RoomRef { try await createRoom(.aptitude) }

    // As on the server: only the host, and only until the friend is in.
    public func setRoomSubject(_ duelId: String, _ subject: Subject) async throws {
        try await pause()
        let r = try room(duelId)
        tick(r)
        guard r.hostIsMe else { throw AppError("Only the player who opened the room can change it.") }
        if r.startsAt != nil || r.closed || r.playedNow || (r.friendArrives.map { now() >= $0 } ?? false) {
            throw AppError("Your friend is already in, so the subject is set.")
        }
        r.subject = subject
        runs[r.id]?.subject = subject
    }

    public func joinRoom(_ code: String) async throws -> JoinedRoom {
        try await pause()
        guard !guest else { throw AppError("Sign in to duel friends.") }
        let code = code.uppercased()
        if let own = rooms.values.first(where: { $0.code == code }) {
            return try decode(["duel_id": own.id, "mode": own.playedNow ? "challenge" : "live"])
        }
        if code.hasPrefix("LIVE") {
            // A friend's room: they're already waiting in it.
            let r = newRoom(hostIsMe: false, friendArrives: now())
            return try decode(["duel_id": r.id, "mode": "live"])
        }
        let joined = try await joinChallenge(code)
        return try decode(["duel_id": joined.duelId, "mode": "challenge"])
    }

    public func liveState(_ duelId: String) async throws -> LiveState {
        try await pause()
        return try decode(liveJSON(try room(duelId)))
    }

    public func livePlayNow(_ duelId: String) async throws -> DuelRef {
        try await pause()
        let r = try room(duelId)
        tick(r)
        guard r.startsAt == nil else { throw AppError("This duel has already started.") }
        r.playedNow = true
        let run = Run(id: r.id, code: r.code, mode: .challenge, company: nil, isCreator: r.hostIsMe, opponentName: nil, opponentIsBot: false)
        runs[run.id] = run
        return try decode(["duel_id": r.id])
    }

    public func liveCancel(_ duelId: String) async throws {
        try await pause()
        try room(duelId).closed = true
    }

    public func liveRematch(_ duelId: String) async throws -> RoomRef {
        try await pause()
        let old = try room(duelId)
        if let id = old.rematchId, let r = rooms[id] { return try decode(["duel_id": r.id, "code": r.code]) }
        guard (runs[duelId]?.finished ?? false), friendAnswers(duelId).count >= 5 else { throw AppError("Finish the duel first.") }
        let r = newRoom(hostIsMe: true, subject: old.subject, friendArrives: now())
        old.rematchId = r.id
        return try decode(["duel_id": r.id, "code": r.code])
    }

    public func profile(_ id: String) async throws -> PublicProfile? {
        try await pause()
        if id == "missing" { return try decode(NSNull()) }
        let mine = id == meId
        return try decode([
            "id": id, "name": mine ? name : Self.friendName, "college": mine ? opt(collegeName) : "NIT Trichy",
            "grad_year": mine ? opt(gradYear) : 2026, "rating": mine ? rating : 1240, "games_played": 24, "wins": 15,
            "streak": 3, "streak_best": 7, "is_bot": false, "tagline": NSNull(), "is_me": mine,
            "joined": "2026-09-14T10:00:00Z", "college_rank": 2, "recent": ["W", "W", "L", "W", "D", "W", "L"],
            "vs_me": mine ? NSNull() : ["played": 3, "wins": 1, "losses": 2],
            "subjects": mine
                ? ["aptitude": ["rating": rating, "games": 6], "coding": ["rating": codingRating, "games": codingGames],
                   "english": ["rating": englishRating, "games": englishGames]]
                : ["aptitude": ["rating": 1240, "games": 18], "coding": ["rating": 1312, "games": 5],
                   "english": ["rating": 1000, "games": 0]],
        ] as [String: Any])
    }
}

// MARK: - Daily calendar

extension FakeBackend {
    // The week's pattern on the Daily card carried back six weeks, and
    // today once its Daily is done. IST days, like the server.
    public func dailyDays() async throws -> [String] {
        try await pause()
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withFullDate]
        format.timeZone = cal.timeZone
        let today = cal.startOfDay(for: now())
        let dailyDone = runs.values.contains { $0.mode == .daily && $0.finished }
        return (0...42).reversed().compactMap { back in
            guard let day = cal.date(byAdding: .day, value: -back, to: today) else { return nil }
            let monday0 = (cal.component(.weekday, from: day) + 5) % 7
            let done = back == 0 ? dailyDone : monday0 % 3 != 2
            return done ? format.string(from: day) : nil
        }
    }
}

// MARK: - Drives

extension FakeBackend {
    private func daysLeft(_ day: String) -> Int {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: now())
        let target = cal.startOfDay(for: ISO8601DateFormatter.day.date(from: day) ?? today)
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }

    private func driveJSON() -> [String: Any] {
        guard let driveCompany, let driveOn else { return ["company": NSNull()] }
        return [
            "company": driveCompany, "drive_on": driveOn, "days_left": daysLeft(driveOn),
            "answered": driveResult != nil, "cleared": opt(driveResult?.cleared),
            "practised": 18, "accuracy": 72, "weak_topics": ["Probability", "Syllogisms"],
        ]
    }

    public func myDrive() async throws -> Drive {
        try await pause()
        return try decode(driveJSON())
    }

    public func setDrive(company: String?, on day: String?) async throws -> Drive {
        try await pause()
        guard let company, !company.trimmingCharacters(in: .whitespaces).isEmpty else {
            driveCompany = nil
            driveOn = nil
            driveResult = nil
            return try decode(driveJSON())
        }
        guard let day, (-30...400).contains(daysLeft(day)) else { throw AppError("Pick a date within the next year.") }
        driveCompany = company
        driveOn = day
        driveResult = nil
        return try decode(driveJSON())
    }

    public func submitDriveResult(cleared: String, difficulty: String?) async throws -> Drive {
        try await pause()
        guard let driveOn, daysLeft(driveOn) <= 0 else { throw AppError("Tell us after your test.") }
        driveResult = (cleared, cleared == "skipped" ? nil : difficulty)
        return try decode(driveJSON())
    }
}

private extension ISO8601DateFormatter {
    static var day: ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = .current
        return f
    }
}
