import AppCore
import DesignSystem
import Domain
import SwiftUI
import Tiko

struct AnswerDots: View {
    let review: [ReviewItem]

    var body: some View {
        HStack {
            Text("Your answers").font(.ui(13)).foregroundStyle(Theme.muted)
            Spacer()
            HStack(spacing: 8) {
                ForEach(review) { r in
                    Image(systemName: r.isCorrect ? "checkmark" : "xmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(r.isCorrect ? Theme.ink : Theme.red)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(r.isCorrect ? Theme.lime : Theme.redTint))
                        .accessibilityLabel("Question \(r.qIndex + 1) \(r.isCorrect ? "correct" : "wrong")")
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

struct Review: View {
    let duelId: String
    let items: [ReviewItem]
    let opponentName: String?
    @Environment(FeedbackState.self) private var feedback

    var body: some View {
        VStack(spacing: 12) {
            ForEach(items) { r in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        (Text("Q\(r.qIndex + 1) · \(r.topic)").foregroundColor(Theme.muted)
                            + Text(r.companies.map { $0.isEmpty ? "" : " · \($0.joined(separator: ", ")) pattern" } ?? "").foregroundColor(Theme.violet))
                            .font(.ui(12, .semibold))
                        Spacer()
                        Text(r.isCorrect ? "+\(r.points) · \(clock(r.ms))" : r.chosenIdx == nil ? "Time ran out" : "Wrong")
                            .font(.ui(12, .bold))
                            .foregroundStyle(r.isCorrect ? Theme.lime : Theme.redSoft)
                    }
                    Text(r.body).font(.ui(15, .semibold)).foregroundStyle(Theme.text).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if let figure = r.figure {
                        SVGFigure(svg: figure).frame(maxWidth: 420, maxHeight: 200).padding(8).card(12)
                    }
                    if let figures = r.optionFigures, figures.count == r.options.count {
                        HStack(spacing: 8) {
                            ForEach(figures.indices, id: \.self) { i in
                                VStack(spacing: 4) {
                                    Text(KEYS_ABCD[i]).font(.ui(11, .bold)).foregroundStyle(Theme.muted)
                                    SVGFigure(svg: figures[i]).aspectRatio(1, contentMode: .fit)
                                }
                                .padding(6)
                                .frame(maxWidth: .infinity)
                                .card(12, fill: tone(r, i).0, border: tone(r, i).1)
                            }
                        }
                    } else {
                        VStack(spacing: 6) {
                            ForEach(r.options.indices, id: \.self) { i in
                                HStack {
                                    Text(r.options[i]).font(.ui(14)).foregroundStyle(Theme.text)
                                    Spacer()
                                    Text(i == r.correctIdx ? "Correct answer" : i == r.chosenIdx ? "Your answer" : "")
                                        .font(.ui(12, .semibold)).foregroundStyle(Theme.muted)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .card(12, fill: tone(r, i).0, border: tone(r, i).1)
                            }
                        }
                    }
                    Text(r.explanation).font(.ui(14)).foregroundStyle(Theme.soft).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        if let opponentName, let oc = r.oppCorrect {
                            Text("\(opponentName): \(oc ? "got it right" : "got it wrong")").font(.ui(12)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Button("Report this question") {
                            feedback.open(.question, context: [
                                "duel": duelId, "question": "\(r.qIndex + 1)", "topic": r.topic, "body": String(r.body.prefix(240)),
                            ])
                        }
                        .font(.ui(12, .semibold))
                        .foregroundStyle(Theme.muted)
                    }
                }
                .padding(16)
                .card(20)
            }
        }
    }

    private func tone(_ r: ReviewItem, _ i: Int) -> (Color, Color) {
        i == r.correctIdx ? (Theme.limeTint, Theme.lime) : i == r.chosenIdx ? (Theme.redTint, Theme.red) : (.clear, Theme.line)
    }
}

private let KEYS_ABCD = ["A", "B", "C", "D"]
