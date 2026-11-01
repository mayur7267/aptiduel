import SwiftUI

// The Apticks stopwatch: a bolt splits its face into your half (lime) and
// your opponent's (orange).
public struct Mark: View {
    var size: CGFloat

    public init(size: CGFloat = 34) { self.size = size }

    public var body: some View {
        Canvas { ctx, s in
            ctx.scaleBy(x: s.width / 64, y: s.height / 64)
            ctx.fill(Path(roundedRect: CGRect(x: 26, y: 5, width: 12, height: 6), cornerRadius: 2.5), with: .color(Theme.text))
            ctx.fill(Path(CGRect(x: 30, y: 10, width: 4, height: 6)), with: .color(Theme.text))
            ctx.fill(Path(ellipseIn: CGRect(x: 10.5, y: 16, width: 43, height: 43)), with: .color(Theme.lime))
            ctx.fill(SVGPath.path("M35.66 16.31L27.5 35.5L37 35.5L28.45 58.71A21.5 21.5 0 0 0 35.66 16.31Z"), with: .color(Theme.orange))
            ctx.stroke(SVGPath.path("M35.66 16.31L27.5 35.5L37 35.5L28.45 58.71"), with: .color(Theme.ink), lineWidth: 3.4)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

public struct Logo: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            Mark(size: 34)
            (Text("Ap").foregroundColor(Theme.text) + Text("ticks").foregroundColor(Theme.lime))
                .font(.display(18))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Apticks")
    }
}

// Marker-pen squiggle under a word.
public nonisolated struct Scribble: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        SVGPath.path("M3 8C28 3 50 10 78 6S128 2 158 7 188 6 197 4")
            .applying(CGAffineTransform(scaleX: rect.width / 200, y: rect.height / 12))
    }
}
