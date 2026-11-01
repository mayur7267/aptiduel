import SwiftUI

// Sticker depth: a solid offset shadow in `pop`.
struct Sticker: ViewModifier {
    var radius: CGFloat
    var pop: Color
    var offset: CGFloat

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(pop).offset(x: offset, y: offset)
        )
    }
}

extension View {
    public func sticker(_ radius: CGFloat, pop: Color = Theme.pop, offset: CGFloat = 4) -> some View {
        modifier(Sticker(radius: radius, pop: pop, offset: offset))
    }

    // A rounded card: fill and border.
    public func card(_ radius: CGFloat = 20, fill: Color = Theme.surface, border: Color = Theme.line, width: CGFloat = 1) -> some View {
        background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(border, lineWidth: width))
    }
}

// Graph paper: a fine 28pt grid with a stronger line every 5 squares,
// fading out away from the top of the screen.
public struct GraphPaper: View {
    public init() {}

    public var body: some View {
        Canvas { ctx, size in
            func grid(_ step: CGFloat, _ alpha: Double) {
                var p = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    p.addRect(CGRect(x: x, y: 0, width: 1, height: size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y <= size.height {
                    p.addRect(CGRect(x: 0, y: y, width: size.width, height: 1))
                    y += step
                }
                ctx.fill(p, with: .color(.white.opacity(alpha)))
            }
            grid(28, 0.035)
            grid(140, 0.07)
            let fade = Gradient(stops: [.init(color: Theme.ink.opacity(0), location: 0.35), .init(color: Theme.ink, location: 1)])
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(fade, center: CGPoint(x: size.width / 2, y: 0), startRadius: 0,
                                           endRadius: max(size.width, size.height) * 1.1))
        }
        .background(Theme.ink)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
