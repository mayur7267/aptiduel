import DesignSystem
import SwiftUI

// Behind the pages: a slow aurora that changes colour with the page, and
// maths symbols floating at different depths. The symbols move with the
// swipe (parallax) and with the phone's tilt (gyroscope).

let PAGE_GLOW: [Color] = [Theme.lime, Theme.lime, Theme.orange, Theme.violet, Theme.violet, Theme.lime]

struct Backdrop: View {
    let progress: CGFloat // the page, fractional while swiping
    let tilt: Tilt
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let glyphs = ["%", "÷", "√", "π", "×", "+", "?", "∑", "∞", "=", "Δ", "½", "∠", "≈"]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { tl in
            let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack {
                    Theme.ink
                    aurora(t: t, size: geo.size)
                    Canvas { ctx, size in symbols(ctx, size: size, t: t) }
                    // Keep the bottom calm for the buttons.
                    LinearGradient(colors: [.clear, Theme.ink.opacity(0.85)], startPoint: UnitPoint(x: 0.5, y: 0.55), endPoint: .bottom)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func glow(at p: CGFloat) -> (Color, Color, Double) {
        let i = max(0, min(PAGE_GLOW.count - 1, Int(p.rounded(.down))))
        let j = min(PAGE_GLOW.count - 1, i + 1)
        return (PAGE_GLOW[i], PAGE_GLOW[j], Double(max(0, min(1, p - CGFloat(i)))))
    }

    @ViewBuilder
    private func aurora(t: Double, size: CGSize) -> some View {
        let (a, b, k) = glow(at: progress)
        if #available(iOS 18.0, *) {
            let c = a.mix(with: b, by: k)
            let s = { (phase: Double, amount: Double) in Float(sin(t * 0.35 + phase) * amount) }
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5 + s(0, 0.12), 0], [1, 0],
                    [0, 0.45 + s(1.3, 0.1)], [0.5 + s(2.1, 0.18), 0.4 + s(0.7, 0.12)], [1, 0.5 + s(2.9, 0.1)],
                    [0, 1], [0.5 + s(1.7, 0.15), 1], [1, 1],
                ],
                colors: [
                    c.opacity(0.32), Theme.ink, Theme.violet.opacity(0.18),
                    Theme.ink, c.opacity(0.22), Theme.ink,
                    Theme.ink, Theme.ink, Theme.ink,
                ]
            )
        } else {
            ZStack {
                RadialGradient(colors: [a.opacity(0.28 * (1 - k)), .clear], center: UnitPoint(x: 0.3, y: 0.15), startRadius: 0, endRadius: size.width)
                RadialGradient(colors: [b.opacity(0.28 * k), .clear], center: UnitPoint(x: 0.3, y: 0.15), startRadius: 0, endRadius: size.width)
                RadialGradient(colors: [Theme.violet.opacity(0.14), .clear], center: UnitPoint(x: 0.9, y: 0.05), startRadius: 0, endRadius: size.width * 0.8)
            }
        }
    }

    private func symbols(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let pages = CGFloat(PAGE_GLOW.count)
        for i in 0..<30 {
            // Fixed pseudo-random layout, so it's the same every launch.
            let fx = (Double(i) * 0.618_034).truncatingRemainder(dividingBy: 1)
            let fy = (Double(i) * 0.381_966 + 0.11).truncatingRemainder(dividingBy: 1)
            let depth = 0.15 + (Double(i * 7 % 10) / 10) * 0.55 // near ones move more
            let span = size.width * (1 + (pages - 1) * depth)
            var x = fx * span - progress * size.width * depth
            x += tilt.x * 26 * depth * 2
            let y = fy * size.height * 0.75 + sin(t * (0.4 + depth) + Double(i)) * 7 + tilt.y * 20 * depth * 2
            guard x > -40, x < size.width + 40 else { continue }
            let fontSize = 14 + depth * 30
            let color = [Theme.lime, Theme.violet, Theme.orange, Theme.text][i % 4]
            var c = ctx
            c.opacity = 0.08 + depth * 0.22
            c.translateBy(x: x, y: y)
            c.rotate(by: .degrees(sin(t * 0.3 + Double(i)) * 14))
            c.draw(Text(Self.glyphs[i % Self.glyphs.count]).font(.system(size: fontSize, weight: .heavy, design: .rounded)).foregroundColor(color),
                   at: .zero)
        }
    }
}

// A title that arrives word by word: each word springs up and sharpens.
struct KineticText: View {
    let text: String
    let start: Date?
    var font: Font = .display(28)
    var color: Color = Theme.text

    var body: some View {
        let words = text.split(separator: " ").map(String.init)
        SceneTimeline(start: start, length: 0.25 + Double(words.count) * 0.07 + 0.6) { t in
            WordFlow(spacing: 8, lineSpacing: 2) {
                ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                    let p = phase(t, 0.12 + Double(i) * 0.07, 0.62 + Double(i) * 0.07, .bezier(0.22, 1, 0.36, 1))
                    Text(word)
                        .font(font)
                        .foregroundStyle(color)
                        .opacity(p)
                        .offset(y: (1 - p) * 22)
                        .blur(radius: (1 - p) * 6)
                        .scaleEffect(0.9 + 0.1 * p, anchor: .bottomLeading)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

// Lays words out left to right, wrapping onto new lines.
struct WordFlow: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews) {
            var x = bounds.minX
            for i in row.items {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + row.height - s.height), proposal: .unspecified)
                x += s.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for (i, view) in subviews.enumerated() {
            let s = view.sizeThatFits(.unspecified)
            if !rows[rows.count - 1].items.isEmpty && rows[rows.count - 1].width + spacing + s.width > width {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width += (row.items.isEmpty ? 0 : spacing) + s.width
            row.height = max(row.height, s.height)
            row.items.append(i)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
