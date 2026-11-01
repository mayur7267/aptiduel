import DesignSystem
import Domain
import SwiftUI
import Tiko

private let PEP = [
    "Read it carefully. You've got this.",
    "Speed bonus: answer fast for up to +50.",
    "Halfway there!",
    "Trust your first instinct.",
    "Last one, make it count!",
]
private let CHEERS = ["Nice!", "Brilliant!", "Too easy!", "Nailed it!", "Yes!"]

// Tiko reads along with you, gets nervous when time runs low, then jumps
// for a right answer or droops at a wrong one.
struct DuelBuddy: View {
    let q: Question
    let phase: DuelPhase
    let result: AnswerResult?
    let chosen: Int?
    let urgent: Bool
    let waitingFor: String?

    var body: some View {
        var mood: TikoMood = .think
        var line = q.qIndex < PEP.count ? PEP[q.qIndex] : PEP[0]
        var tone = Theme.soft
        var play: TikoPlay?
        if phase == .submitting {
            line = "Checking…"
        } else if phase == .reveal, let result {
            let right = KEYS[result.correctIdx]
            if result.correct {
                mood = .cheer
                line = "+\(result.points) points! \(CHEERS[q.qIndex % CHEERS.count])"
                tone = Theme.lime
                play = TikoPlay(move: .boing, key: q.qIndex)
            } else {
                mood = .sad
                line = chosen == nil ? "Time's up! It was \(right)." : "Not quite. It's \(right)."
                tone = Theme.redSoft
                play = TikoPlay(move: .droop, key: q.qIndex)
            }
        } else if urgent {
            mood = .confused
            line = "Quick! Pick your best guess."
            tone = Theme.orangeSoft
        }

        return HStack(alignment: .bottom, spacing: 10) {
            TikoView(mood: mood, size: 68, play: play)
            VStack(alignment: .leading, spacing: 2) {
                Text(line).font(.ui(14, .bold)).foregroundStyle(tone)
                if let waitingFor {
                    Text("Waiting for \(waitingFor)…").font(.ui(12)).foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(16, border: Theme.line, width: 2)
            .overlay(alignment: .bottomLeading) { BubbleTail(edge: .leading).offset(x: -7, y: -12) }
            .sticker(16)
            .padding(.bottom, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
