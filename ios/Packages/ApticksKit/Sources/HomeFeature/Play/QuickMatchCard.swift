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

// The main way to play: the whole card is the button.
struct QuickMatchCard: View {
    let rating: Int
    let onFind: () -> Void

    var body: some View {
        let tier = tierFor(rating)
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        Button(action: onFind) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1V1 · RATED")
                        .font(.mono(11))
                        .tracking(1.2)
                        .foregroundStyle(Theme.lime)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.ink))
                        .rotationEffect(.degrees(-3))
                        .padding(.bottom, 2)
                    Text("Quick Match").font(.display(22)).foregroundStyle(Theme.ink)
                    Text("Race someone near your rating · 3 min").font(.ui(13, .medium)).foregroundStyle(Theme.limeInk)
                    Label(tier.next.map { "\(tier.toNext) to \($0.name)" } ?? "\(tier.name), the top tier", systemImage: "shield.fill")
                        .font(.ui(12, .bold))
                        .foregroundStyle(Theme.limeInk.opacity(0.8))
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                VStack(spacing: 2) {
                    Image(systemName: "bolt.fill").font(.system(size: 22, weight: .black))
                    Text("PLAY").font(.display(11))
                }
                .foregroundStyle(Theme.lime)
                .frame(width: 62, height: 62)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.ink))
                .sticker(18, pop: Theme.limePop)
                .rotationEffect(.degrees(6))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Theme.lime))
            .background(Stripes(color: Theme.ink.opacity(0.035)).clipShape(shape))
            .overlay(shape.strokeBorder(Theme.limeEdge, lineWidth: 2))
            .contentShape(shape)
        }
        .buttonStyle(CardPressStyle(pop: Theme.limePop))
        .accessibilityLabel("Quick Match")
        .accessibilityHint("Finds a player near your rating. 5 questions, about 3 minutes.")
    }
}
