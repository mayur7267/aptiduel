import Foundation

// Who won: more points, or the same points in less time.
public enum DuelOutcome: Sendable, Hashable {
    case win, loss, draw

    public init(myScore: Int, myMs: Int, theirScore: Int, theirMs: Int) {
        if myScore == theirScore && myMs == theirMs {
            self = .draw
        } else if myScore > theirScore || (myScore == theirScore && myMs < theirMs) {
            self = .win
        } else {
            self = .loss
        }
    }

    // The same result from the other side.
    public var flipped: DuelOutcome { self == .win ? .loss : self == .loss ? .win : .draw }
}

// A question's result in a run.
public enum AnswerMark: Sendable, Hashable {
    case right, wrong
    case unknown // answered, but not revealed yet
}

// A finished opponent's run, replayed against the question you're on.
// They "answer" once your time on the question passes theirs, but whether
// they were right stays hidden until you've answered too.
public struct OpponentReplay: Sendable, Hashable {
    public var marks: [AnswerMark] = []
    public var score = 0
    public var answeredHere = false

    public init(timeline: [TimelineStep], question: Int, elapsedMs: Int, revealed: Bool) {
        for step in timeline {
            if step.qIndex < question || (step.qIndex == question && revealed) {
                score += step.points
                marks.append(step.correct ? .right : .wrong)
            } else if step.qIndex == question && step.ms <= elapsedMs {
                answeredHere = true
                marks.append(.unknown)
            }
        }
    }
}
