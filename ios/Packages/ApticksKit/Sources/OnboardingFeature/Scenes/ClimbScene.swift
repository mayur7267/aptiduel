import DesignSystem
import Domain
import SwiftUI
import Tiko
import UIKit

// Rating: a staircase of the six tiers. Tiko hops up one step at a time,
// the rating counting up as it lands, and a trophy pops at the top.
struct ClimbScene: View {
    let start: Date?
    private let size: CGFloat = 46
    private static let stepColors: [Color] = [
        Theme.raised, Theme.lineStrong, Color(hex: "4a4380"), Theme.violetStrong, Theme.violet, Theme.lime,
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = TIERS.count
            let left: CGFloat = 20
            let stepW = (w - left * 2 - 20) / CGFloat(count)
            let stepH = h * 0.105
            let base = h * 0.94
            let x0 = left + 20
            let tops = (0..<count).map { i in
                CGPoint(x: x0 + stepW * (CGFloat(i) + 0.5), y: base - stepH * CGFloat(i + 1))
            }
            let hops = tops.enumerated().map { i, top in
                TikoHop(from: i == 0 ? CGPoint(x: x0 - 26, y: base) : tops[i - 1], to: top,
                        start: 0.55 + Double(i) * 0.5, height: 42, duration: 0.42)
            }
            let landed = hops.last!.touchdown

            SceneTimeline(start: start, length: landed + 2) { t in
                let reached = hops.lastIndex { t >= $0.touchdown }
                ZStack {
                    ForEach(0..<count, id: \.self) { i in
                        step(i, top: tops[i], width: stepW, height: stepH * CGFloat(i + 1), lit: (reached ?? -1) >= i)
                    }
                    ratingBadge(reached.map { TIERS[$0].min } ?? 1_000, tier: reached.map { TIERS[$0].name } ?? "Fresher")
                        .position(x: left + 92, y: h * 0.1)

                    // A trophy pops up over the top step.
                    if t > landed {
                        let k = phase(t, landed + 0.05, landed + 0.45, .bezier(0.34, 1.56, 0.64, 1))
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Theme.lime)
                            .shadow(color: Theme.lime.opacity(0.6), radius: 10)
                            .scaleEffect(k)
                            .position(x: tops[count - 1].x, y: tops[count - 1].y - TikoView.height(for: size) - 26 - 8 * sin(t * 3))
                    }
                    Burst(t: t - landed - 0.1, at: tops[count - 1], count: 26, power: 0.85)
                    TikoActor(pose: pose(t, hops), size: size, play: t > landed + 0.1 ? TikoPlay(move: .boing, key: 1) : nil)
                }
                .frame(width: w, height: h)
            }
            .sceneHaptics(start, hops.indices.map { i -> (Double, UIImpactFeedbackGenerator.FeedbackStyle) in
                (hops[i].touchdown, i == hops.count - 1 ? .heavy : .light)
            })
        }
    }

    private func pose(_ t: Double, _ hops: [TikoHop]) -> TikoPose {
        if t < hops[0].start { return TikoPose(feet: CGPoint(x: hops[0].values(at: 0)[0], y: hops[0].values(at: 0)[1]), mood: .happy) }
        for (i, hop) in hops.enumerated() {
            let next = i + 1 < hops.count ? hops[i + 1].start : .infinity
            if t < hop.end { return .on(hop, at: t, mood: .happy) }
            if t < next { return TikoPose(feet: hop.to, mood: i == hops.count - 1 ? .cheer : .happy, still: i == hops.count - 1 ? false : true) }
        }
        return TikoPose(feet: hops.last!.to, mood: .cheer, still: false)
    }

    private func step(_ i: Int, top: CGPoint, width: CGFloat, height: CGFloat, lit: Bool) -> some View {
        let color = Self.stepColors[i]
        return ZStack(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 2, bottomTrailingRadius: 2, topTrailingRadius: 10, style: .continuous)
                .fill(color.opacity(lit ? 1 : 0.45))
            Text(TIERS[i].name.uppercased())
                .font(.system(size: 7.5, weight: .heavy))
                .tracking(0.3)
                .foregroundStyle(i == TIERS.count - 1 ? Theme.ink : Theme.text.opacity(lit ? 0.95 : 0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 2)
                .padding(.top, 7)
        }
        .frame(width: width - 4, height: height)
        .animation(.easeOut(duration: 0.2), value: lit)
        .position(x: top.x, y: top.y + height / 2)
    }

    private func ratingBadge(_ rating: Int, tier: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.fill").foregroundStyle(Theme.violet)
            VStack(alignment: .leading, spacing: 0) {
                Text(grouped(rating)).font(.mono(18)).foregroundStyle(Theme.text)
                    .contentTransition(.numericText(value: Double(rating)))
                    .animation(.snappy, value: rating)
                Text(tier).font(.ui(11, .semibold)).foregroundStyle(Theme.violet)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .card(14, border: Theme.violet.opacity(0.4))
    }
}
