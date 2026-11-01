import SwiftUI

public struct Spinner: View {
    var label: String

    public init(_ label: String = "Loading") { self.label = label }

    public var body: some View {
        HStack(spacing: 12) {
            ProgressView().tint(Theme.lime)
            Text("\(label)…").font(.ui(14)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .accessibilityElement(children: .combine)
    }
}

public struct ErrorNote: View {
    let message: String
    var onRetry: (() -> Void)?

    public init(_ message: String, onRetry: (() -> Void)? = nil) {
        self.message = message
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message).font(.ui(14)).foregroundStyle(Theme.redSoft)
            if let onRetry {
                Button("Try again", action: onRetry)
                    .buttonStyle(FilledStyle(fill: Theme.raised, foreground: Theme.text, radius: 12, height: 40))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .card(16, fill: Theme.redTint.opacity(0.4), border: Theme.redTint)
    }
}

// Three dots bouncing in turn, for "Thinking" and "Finding an opponent".
public struct BouncingDots: View {
    var color: Color
    var size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(color: Color = Theme.lime, size: CGFloat = 6) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            HStack(spacing: size * 0.6) {
                ForEach(0..<3, id: \.self) { i in
                    // 1.2s cycle, peaking at 40%, like the website's `dot`.
                    let phase = ((t - Double(i) * 0.15) / 1.2).truncatingRemainder(dividingBy: 1)
                    let k = phase < 0.4 ? phase / 0.4 : phase < 0.8 ? 1 - (phase - 0.4) / 0.4 : 0
                    let lift = sin(k * .pi / 2)
                    Circle().fill(color)
                        .frame(width: size, height: size)
                        .opacity(reduceMotion ? 1 : 0.25 + 0.75 * lift)
                        .offset(y: reduceMotion ? 0 : -3 * lift)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
