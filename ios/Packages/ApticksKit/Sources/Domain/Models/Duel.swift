import Foundation

public struct Duel: Decodable, Sendable, Hashable {
    public let id: String
    public let code: String
    public let mode: DuelMode
    public let company: String? // set on company practice duels (and challenges made from them)
    public let status: String
    public let isCreator: Bool
    public let me: Player
    public let opponent: Player?
    // The opponent's run, question by question, once it's finished. Used to
    // replay them racing you during the duel.
    public let opponentTimeline: [TimelineStep]?
    // Your own results so far (no answers revealed), for restoring a duel.
    public let myAnswers: [MyAnswer]?
    public let review: [ReviewItem]?
    public let daily: DailyRank?

    // Final result, once both sides have finished.
    public var outcome: DuelOutcome? {
        guard let opponent, opponent.finished else { return nil }
        return DuelOutcome(myScore: me.score, myMs: me.totalMs, theirScore: opponent.score, theirMs: opponent.totalMs)
    }

    // Whether an opponent can still arrive or finish: a friend accepting
    // your challenge, or a live opponent still playing.
    public var awaitingOpponent: Bool {
        mode == .challenge ? opponent?.finished != true : opponent.map { !$0.finished } ?? false
    }
}

public enum DuelMode: String, Decodable, Sendable, Hashable {
    case challenge, quick, daily, live
}

public struct TimelineStep: Decodable, Sendable, Hashable {
    public let qIndex: Int
    public let ms: Int
    public let correct: Bool
    public let points: Int
}

public struct MyAnswer: Decodable, Sendable, Hashable {
    public let qIndex: Int
    public let correct: Bool
}

public struct DailyRank: Decodable, Sendable, Hashable {
    public let rank: Int
    public let players: Int
}

// A question after the duel, with the answer and explanation.
public struct ReviewItem: Decodable, Sendable, Hashable, Identifiable {
    public let qIndex: Int
    public let section: String
    public let topic: String
    public let companies: [String]? // company test patterns this topic is on
    public let body: String
    public let figure: String?
    public let options: [String]
    public let optionFigures: [String]?
    public let correctIdx: Int
    public let chosenIdx: Int?
    public let isCorrect: Bool
    public let points: Int
    public let ms: Int
    public let explanation: String
    public let oppCorrect: Bool?

    public var id: Int { qIndex }
}

// A duel in the recent-duels list.
public struct DuelSummary: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let mode: DuelMode
    public let company: String?
    public let status: String
    public let createdAt: String
    public let code: String? // set on challenges you started
    public let seat: Int
    public let isReplay: Bool
    public let score: Int
    public let correct: Int
    public let totalMs: Int
    public let finished: Bool
    public let ratingBefore: Int?
    public let ratingAfter: Int?
    public let opponentName: String?
    public let opponentIsBot: Bool?
    public let opponentCollege: String?
    public let opponentIsReplay: Bool?
    public let opponentScore: Int?
    public let opponentTotalMs: Int?
    public let opponentFinished: Bool?

    public var created: Date? { parseTimestamp(createdAt) }
}
