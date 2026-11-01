import DesignSystem
import Domain
import SwiftUI
import Tiko

// A static picture of the duel screen, so first-time players know what
// they are about to play.
struct DuelPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Question 1 of 5")
                Spacer()
                Text("0:40").monospacedDigit().padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(Theme.ink))
            }
            .font(.ui(14, .semibold)).foregroundStyle(Theme.text)
            Capsule().fill(Theme.lime).frame(height: 6)
            Text("The cost price of 20 articles equals the selling price of 16. What is the profit percentage?")
                .font(.ui(17, .semibold)).foregroundStyle(Theme.text).lineSpacing(3)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(["20%", "25%", "16%", "30%"].enumerated()), id: \.offset) { i, o in
                    HStack(spacing: 10) {
                        Text(["A", "B", "C", "D"][i]).font(.ui(12, .bold))
                            .foregroundStyle(i == 1 ? Theme.ink : Theme.muted)
                            .frame(width: 26, height: 26)
                            .background(RoundedRectangle(cornerRadius: 8).fill(i == 1 ? Theme.lime : Theme.line))
                        Text(o).font(.ui(15, .semibold)).foregroundStyle(Theme.text)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .card(14, fill: i == 1 ? Theme.limeTint : Theme.raised, border: i == 1 ? Theme.lime : Theme.field)
                }
            }
        }
        .padding(20)
        .card(28, border: Theme.line, width: 2)
        .sticker(28, pop: Theme.limePop)
        .rotationEffect(.degrees(1))
        .accessibilityHidden(true)
    }
}
