import DesignSystem
import Domain
import SwiftUI

// Diagonal stripes, like the website's repeating-linear-gradient(135deg).
struct Stripes: View {
    var color: Color
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            let step: CGFloat = 28 * 1.414
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                x += step
            }
            ctx.stroke(p, with: .color(color), lineWidth: 14)
        }
        .allowsHitTesting(false)
    }
}

struct QuickMatchCard: View {
    let onFind: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text("1V1 · RATED")
                    .font(.mono(11))
                    .tracking(1.2)
                    .foregroundStyle(Theme.lime)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.ink))
                    .rotationEffect(.degrees(-3))
                Spacer()
                Text("VS")
                    .font(.display(18))
                    .foregroundStyle(Theme.lime)
                    .frame(width: 56, height: 56)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.ink))
                    .sticker(16, pop: Theme.limePop)
                    .rotationEffect(.degrees(6))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Quick Match").font(.display(24)).foregroundStyle(Theme.ink)
                Text("Race a player near your rating. 5 questions, about 3 minutes.")
                    .font(.ui(14, .medium)).foregroundStyle(Theme.limeInk)
            }
            Button(action: onFind) {
                Label {
                    Text("Find opponent")
                } icon: {
                    Image(systemName: "bolt.fill").foregroundStyle(Theme.lime)
                }
            }
            .buttonStyle(PressableStyle(fill: Theme.ink, foreground: Theme.text, pop: Theme.limePop, fullWidth: false))
            .padding(.top, 8)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.lime))
        .background(Stripes(color: Theme.ink.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.limeEdge, lineWidth: 2))
        .sticker(22, pop: Theme.limePop)
    }
}
