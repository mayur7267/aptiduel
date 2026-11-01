import Foundation

public struct Question: Decodable, Sendable, Hashable {
    public let qIndex: Int
    public let total: Int
    public let section: String
    public let topic: String
    public let companies: [String]?
    public let difficulty: Int
    public let body: String
    public let figure: String? // SVG shown with the question
    public let options: [String]
    public let optionFigures: [String]? // SVG per option for picture questions
    public let timeLimitMs: Int
    public let remainingMs: Int
    public let score: Int
}

// next_question: the next question, or the run's final score.
public enum QuestionView: Decodable, Sendable, Hashable {
    case done(score: Int)
    case question(Question)

    private enum Keys: String, CodingKey { case done, score }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        if try c.decode(Bool.self, forKey: .done) {
            self = .done(score: try c.decodeIfPresent(Int.self, forKey: .score) ?? 0)
        } else {
            self = .question(try Question(from: decoder))
        }
    }
}

public struct AnswerResult: Decodable, Sendable, Hashable {
    public let correct: Bool
    public let correctIdx: Int
    public let points: Int
    public let score: Int
    public let elapsedMs: Int
    public let done: Bool

    // For showing a live duel's answers with the same option buttons.
    public init(correct: Bool, correctIdx: Int, points: Int, score: Int = 0, elapsedMs: Int = 0, done: Bool = false) {
        self.correct = correct
        self.correctIdx = correctIdx
        self.points = points
        self.score = score
        self.elapsedMs = elapsedMs
        self.done = done
    }
}
