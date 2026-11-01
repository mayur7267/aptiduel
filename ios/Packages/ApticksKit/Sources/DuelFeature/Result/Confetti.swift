import DesignSystem
import Domain
import SwiftUI
import Tiko

private let CONFETTI_COLORS = [Theme.lime, Theme.orange, Theme.violet, Theme.redSoft, Theme.text, Theme.cyan]

// A one-off burst for wins.
struct Confetti: View {
    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSince(start)
                Canvas { ctx, size in
                    let ease = Ease.bezier(0.2, 0.6, 0.4, 1)
                    for i in 0..<36 {
                        let p = (t - Double(i % 9) * 0.07) / 2.6
                        guard p < 1 else { continue }
                        let k = ease(max(0, p))
                        let w: CGFloat = i % 3 == 0 ? 6 : 9
                        let h: CGFloat = i % 3 == 0 ? 14 : 9
                        let drift = CGFloat((i * 53) % 160 - 80)
                        let spin = Double(360 + (i * 97) % 540)
                        var c = ctx
                        c.opacity = 1 - k
                        c.translateBy(x: size.width * CGFloat((i * 37 + 7) % 100) / 100 + drift * k, y: -20 + 540 * k)
                        c.rotate(by: .degrees(spin * k))
                        c.fill(Path(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), cornerRadius: 2),
                               with: .color(CONFETTI_COLORS[i % CONFETTI_COLORS.count]))
                    }
                }
            }
            .frame(height: 600)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .ignoresSafeArea()
        }
    }
}
