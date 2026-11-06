import DesignSystem
import Domain
import SwiftUI

// The streak, in the header. Tapping it turns the Today deck to the
// Daily Challenge, which is what keeps it going.
struct StreakChip: View {
    let streak: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .bold))
                    .modifier(Wiggle(active: streak > 0))
                Text("\(streak)").font(.mono(14))
            }
            .foregroundStyle(streak > 0 ? Theme.orange : Theme.faint)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Capsule().fill(streak > 0 ? Theme.orangeTint : Theme.raised))
            .overlay(Capsule().strokeBorder(streak > 0 ? Theme.orange.opacity(0.3) : Theme.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(streak > 0 ? "\(streak)-day streak" : "No streak yet")
        .accessibilityHint("Shows the Daily Challenge")
    }
}

// Your rating, with a ring that fills on the way to the next tier.
struct RatingChip: View {
    let rating: Int
    let action: () -> Void

    var body: some View {
        let tier = tierFor(rating)
        Button(action: action) {
            HStack(spacing: 6) {
                ZStack {
                    Circle().stroke(Theme.violet.opacity(0.25), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: tier.progress)
                        .stroke(Theme.violet, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "shield.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.violet)
                }
                .frame(width: 22, height: 22)
                Text(grouped(rating))
                    .font(.mono(14))
                    .foregroundStyle(Theme.violetSoft)
                    .contentTransition(.numericText(value: Double(rating)))
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .frame(height: 38)
            .background(Capsule().fill(Theme.violetTint))
            .overlay(Capsule().strokeBorder(Theme.violet.opacity(0.3)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rating \(grouped(rating)), \(tier.name)" + (tier.next.map { ", \(tier.toNext) to \($0.name)" } ?? ""))
        .accessibilityHint("Opens your profile")
    }
}
