import SwiftUI
import UIKit

// The launch animation. The stopwatch is built from its own pieces: the
// lime half and the orange half fly in from either side like two
// duellists and clash in the middle (a flash and a shockwave), the bolt
// cracks down between them, the button drops on top with a bounce, the
// watch ticks once and the name types itself out. Then the logo rushes
// at you while a growing circle opens onto the app underneath.
public struct BrandSplash: View {
    let onFinish: () -> Void
    private let frozen: Date? // a fixed start, for rendering frames in tests
    @State private var began: Date?
    private var start: Date? { frozen ?? began }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        frozen = nil
    }

    // Frozen at a moment, for rendering frames in tests.
    init(at start: Date) {
        onFinish = {}
        frozen = start
    }

    private enum T {
        static let clash = 0.62
        static let crown = 0.82
        static let crownLands = 1.12
        static let tick = 1.3
        static let reveal = 1.75
        static let end = 2.3
    }

    private static let orange = SVGPath.path("M35.66 16.31L27.5 35.5L37 35.5L28.45 58.71A21.5 21.5 0 0 0 35.66 16.31Z")
    private static let bolt = SVGPath.path("M35.66 16.31L27.5 35.5L37 35.5L28.45 58.71")
    private static let disc = Path(ellipseIn: CGRect(x: 10.5, y: 16, width: 43, height: 43))
    private static let lime = disc.subtracting(orange)

    public var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: start == nil)) { tl in
                let t = start.map { tl.date.timeIntervalSince($0) } ?? 0
                let open = reduceMotion ? 0 : stage(t, T.reveal, T.end, 0.5, 0.0, 0.2, 1)
                let radius = hypot(geo.size.width, geo.size.height) * open
                ZStack {
                    Theme.ink
                    shockwave(t)
                    VStack(spacing: 18) {
                        mark(t).frame(width: 132, height: 132)
                        wordmark(t)
                    }
                    .scaleEffect(reduceMotion ? 1 : 1 + 7 * pow(stage(t, T.reveal, T.end, 0.55, 0, 0.75, 1), 2.2))
                    .opacity(reduceMotion ? (t < 0.9 ? 1 : max(0, 1 - (t - 0.9) / 0.4)) : 1 - stage(t, T.reveal + 0.2, T.end, 0.4, 0, 1, 1))
                }
                // The hole that opens onto the app.
                .mask {
                    Rectangle()
                        .overlay(Circle().frame(width: radius * 2, height: radius * 2).blendMode(.destinationOut))
                        .compositingGroup()
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(start.map { Date().timeIntervalSince($0) < T.reveal } ?? true)
        .accessibilityElement()
        .accessibilityLabel("Apticks")
        .task {
            guard frozen == nil else { return }
            began = Date()
            if !reduceMotion {
                try? await Task.sleep(for: .seconds(T.clash))
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                try? await Task.sleep(for: .seconds(T.crownLands - T.clash))
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                try? await Task.sleep(for: .seconds(T.end - T.crownLands))
            } else {
                try? await Task.sleep(for: .seconds(1.3))
            }
            onFinish()
        }
    }

    // 0 → 1 between two times along a cubic-bezier.
    private func stage(_ t: Double, _ from: Double, _ to: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        Ease.bezier(x1, y1, x2, y2)(min(1, max(0, (t - from) / (to - from))))
    }

    private func mark(_ t: Double) -> some View {
        Canvas { ctx, size in
            let s = size.width / 64
            if reduceMotion {
                var c = ctx
                c.scaleBy(x: s, y: s)
                drawCrown(c, drop: 0)
                c.fill(Self.lime, with: .color(Theme.lime))
                c.fill(Self.orange, with: .color(Theme.orange))
                c.stroke(Self.bolt, with: .color(Theme.ink), lineWidth: 3.4)
                return
            }
            // The two halves fly in and overshoot a touch into each other.
            let fly = stage(t, 0.08, T.clash, 0.3, 0.0, 0.25, 1.0)
            let settle = t > T.clash ? sin(min(1, (t - T.clash) / 0.35) * .pi) * exp(-(t - T.clash) * 6) : 0
            // The squash of the impact, and the tick later on.
            let squash = t > T.clash ? exp(-(t - T.clash) * 9) * cos((t - T.clash) * 28) : 0
            let tick = t > T.tick ? exp(-(t - T.tick) * 7) * sin((t - T.tick) * 26) : 0
            var c = ctx
            c.translateBy(x: size.width / 2, y: size.height * 37.5 / 64)
            c.rotate(by: .degrees(-9 * tick))
            c.scaleBy(x: 1 + 0.12 * squash, y: 1 - 0.1 * squash)
            c.translateBy(x: -size.width / 2, y: -size.height * 37.5 / 64)
            c.scaleBy(x: s, y: s)

            let gap = 70 * (1 - fly) - 1.5 * settle
            // Each half spins about the watch's centre as it flies in.
            func half(_ path: Path, _ color: Color, side: Double) {
                var h = c
                h.translateBy(x: side * gap + 32, y: 37.5)
                h.rotate(by: .degrees(side * 25 * (1 - fly)))
                h.translateBy(x: -32, y: -37.5)
                h.fill(path, with: .color(color))
            }
            half(Self.lime, Theme.lime, side: -1)
            half(Self.orange, Theme.orange, side: 1)

            // The crack, drawn down the seam after the clash.
            let crack = stage(t, T.clash, T.clash + 0.22, 0.2, 0, 0.2, 1)
            if crack > 0 {
                c.stroke(Self.bolt.trimmedPath(from: 0, to: crack), with: .color(Theme.ink),
                         style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round))
            }
            // A flash where they meet.
            let flash = t > T.clash ? max(0, 1 - (t - T.clash) / 0.25) : 0
            if flash > 0 {
                var f = c
                f.opacity = flash
                f.fill(Path(ellipseIn: CGRect(x: 32 - 30 * flash, y: 37.5 - 30 * flash, width: 60 * flash, height: 60 * flash)),
                       with: .radialGradient(Gradient(colors: [.white, .white.opacity(0)]), center: CGPoint(x: 32, y: 37.5), startRadius: 0, endRadius: 30))
            }
            // The button falls on top and bounces.
            if t > T.crown {
                drawCrown(c, drop: crownDrop(t - T.crown))
            }
        }
    }

    // Height above its seat (in logo units): a fall, then two small bounces.
    private func crownDrop(_ k: Double) -> Double {
        let fall = T.crownLands - T.crown
        if k < fall { return 26 * (1 - pow(k / fall, 2)) }
        let b = k - fall
        if b < 0.16 { return 4 * sin(b / 0.16 * .pi) }
        if b < 0.26 { return 1.2 * sin((b - 0.16) / 0.1 * .pi) }
        return 0
    }

    private func drawCrown(_ ctx: GraphicsContext, drop: Double) {
        var c = ctx
        c.translateBy(x: 0, y: -drop)
        c.fill(Path(roundedRect: CGRect(x: 26, y: 5, width: 12, height: 6), cornerRadius: 2.5), with: .color(Theme.text))
        c.fill(Path(CGRect(x: 30, y: 10, width: 4, height: 6)), with: .color(Theme.text))
    }

    // A ring that rushes out from the clash.
    private func shockwave(_ t: Double) -> some View {
        let k = t > T.clash ? min(1, (t - T.clash) / 0.6) : 0
        return Circle()
            .strokeBorder(Theme.lime.opacity(0.7 * (1 - k)), lineWidth: 3 * (1 - k) + 1)
            .frame(width: 60 + 360 * Ease.easeOut(k), height: 60 + 360 * Ease.easeOut(k))
            .offset(y: -34)
            .opacity(k > 0 && k < 1 && !reduceMotion ? 1 : 0)
    }

    // "Apticks", one letter at a time; "ticks" in lime.
    private func wordmark(_ t: Double) -> some View {
        HStack(spacing: 0) {
            ForEach(Array("Apticks".enumerated()), id: \.offset) { i, ch in
                let p = reduceMotion ? 1 : stage(t, 0.95 + Double(i) * 0.05, 1.4 + Double(i) * 0.05, 0.22, 1, 0.36, 1)
                Text(String(ch))
                    .font(.display(38))
                    .foregroundStyle(i < 2 ? Theme.text : Theme.lime)
                    .opacity(p)
                    .offset(y: (1 - p) * 18)
                    .blur(radius: (1 - p) * 5)
            }
        }
    }
}
