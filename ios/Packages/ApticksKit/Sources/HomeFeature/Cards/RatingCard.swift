import DesignSystem
import Domain
import SwiftUI

struct RatingCard: View {
    let rating: Int

    var body: some View {
        let tier = tierFor(rating)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your rating").font(.ui(13, .medium)).foregroundStyle(Theme.muted)
                    Text(grouped(rating)).font(.mono(36)).foregroundStyle(Theme.text)
                        .contentTransition(.numericText(value: Double(rating)))
                }
                Spacer()
                TierBadge(rating: rating)
            }
            VStack(spacing: 8) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.line)
                        Capsule().fill(Theme.violet).frame(width: g.size.width * tier.progress)
                    }
                }
                .frame(height: 8)
                HStack {
                    Text("\(tier.name) · ") + Text(grouped(tier.min)).font(.mono(12, .regular))
                    Spacer()
                    Text(tier.next.map { "\(tier.toNext) to \($0.name)" } ?? "Top tier")
                }
                .font(.ui(12))
                .foregroundStyle(Theme.muted)
            }
        }
        .padding(18)
        .card(20)
        .sticker(20)
    }
}
