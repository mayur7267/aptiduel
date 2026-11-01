import DesignSystem
import SwiftUI
import UIKit

// Tiko, the Apticks mascot: a little lime alien whose antenna is the
// stopwatch button. Drawn from the same shapes as the website's SVG
// (web/src/components/tiko.tsx) so it looks and moves the same. Idle
// motion (hops, blinking, antenna wiggle) runs off one timeline. Tapping
// Tiko gets a reaction: a physics jump, a flip or a giggle, with a burst
// of stars; five quick taps make it dizzy. Motion is skipped for people
// who turn on Reduce Motion.

public enum TikoMood: String, Sendable {
    case wave, happy, point, think, cheer, sad, confused, sleep, giggle
}

public enum TikoMove: Sendable {
    case boing, flip, giggle, droop
}

// A page asks for a move; a new key plays it again.
public struct TikoPlay: Equatable {
    public var move: TikoMove
    public var key: Int

    public init(move: TikoMove, key: Int) {
        self.move = move
        self.key = key
    }
}

private let INK = Theme.ink
private let LIME = Theme.lime
private let ORANGE = Theme.orange
private let VIOLET = Theme.violet

// Arm shapes, from shoulder to hand.
private enum Arm: String {
    case downL = "M30 80 Q19 86 20 97"
    case downR = "M90 80 Q101 86 100 97"
    case upL = "M30 74 Q16 62 15 46"
    case upR = "M90 74 Q104 62 105 46"
    case pointR = "M90 77 Q104 74 114 70"
    case chinR = "M90 82 Q86 96 72 96"

    var hand: CGPoint {
        let n = rawValue.split(separator: " ").suffix(2).compactMap { Double($0) }
        return CGPoint(x: n[0], y: n[1])
    }
}

// Stars that pop out of a tap, each flying a different way.
private let SPARKS: [(dx: CGFloat, dy: CGFloat, color: Color)] = [
    (-42, -30, Theme.lime), (40, -34, Theme.orange), (-30, -58, Theme.violet), (32, -60, Theme.text), (2, -72, Theme.lime),
]
private let STAR = "M10 0 L12.6 7.4 L20 10 L12.6 12.6 L10 20 L7.4 12.6 L0 10 L7.4 7.4 Z"
private let SPARK_EASE = Ease.bezier(0.22, 1, 0.36, 1)

private struct ActiveMove {
    let kind: TikoMove
    let start: Date
}

public struct TikoView: View {
    var mood: TikoMood
    var size: CGFloat
    var still: Bool // no idle motion, for when something else is moving Tiko
    var interactive: Bool // false inside another button
    var play: TikoPlay?
    var onTap: (() -> Void)? // after Tiko reacts to a tap, e.g. to say something

    @State private var face: TikoMood?
    @State private var active: ActiveMove?
    @State private var burst: Date?
    @State private var busy = false
    @State private var taps: [Date] = []
    @State private var born = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(mood: TikoMood = .happy, size: CGFloat = 96, still: Bool = false, interactive: Bool = true,
                play: TikoPlay? = nil, onTap: (() -> Void)? = nil) {
        self.mood = mood
        self.size = size
        self.still = still
        self.interactive = interactive
        self.play = play
        self.onTap = onTap
    }

    // Tiko's drawing is 120 × 124.
    public static func height(for size: CGFloat) -> CGFloat { size * 124 / 120 }

    private var height: CGFloat { Self.height(for: size) }

    public var body: some View {
        let shown = face ?? mood
        let idle = !still && face == nil
        TimelineView(.animation(paused: reduceMotion)) { tl in
            let now = tl.date
            let m = moveValues(now)
            drawing(shown, idle: idle, now: now)
                .scaleEffect(x: m[2], y: m[3], anchor: .bottom)
                .rotationEffect(.degrees(m[1]), anchor: .bottom)
                .offset(y: m[0] * height)
        }
        .frame(width: size, height: height)
        .overlay {
            if interactive {
                Color.clear.contentShape(Rectangle()).onTapGesture(perform: react)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(interactive ? "Tiko, the Apticks mascot. Tap to play." : "")
        .accessibilityAddTraits(interactive ? .isButton : [])
        .accessibilityHidden(!interactive)
        .accessibilityAction { react() }
        .onChange(of: play) { _, p in
            guard let p, !reduceMotion else { return }
            active = ActiveMove(kind: p.move, start: Date())
        }
    }

    private func moveValues(_ now: Date) -> [Double] {
        guard let active, !reduceMotion else { return [0, 0, 1, 1] }
        let (track, duration) = Moves.track(active.kind)
        let p = now.timeIntervalSince(active.start) / duration
        return p >= 1 ? [0, 0, 1, 1] : track.at(max(0, p))
    }

    // Drawn on a canvas bigger than Tiko, so hops and stars aren't clipped.
    private func drawing(_ mood: TikoMood, idle: Bool, now: Date) -> some View {
        let mx = size * 0.7
        let my = size * 0.9
        let t = reduceMotion ? nil : now.timeIntervalSince(born)
        let sparkT = burst.map { now.timeIntervalSince($0) }
        return Canvas { ctx, _ in
            var c = ctx
            c.translateBy(x: mx, y: my)
            if let sparkT, sparkT < 0.85 { drawSparks(c, t: sparkT) }
            c.scaleBy(x: size / 120, y: size / 120)
            TikoArt.draw(c, mood: mood, t: t, idle: idle)
        }
        .frame(width: size + 2 * mx, height: height + 2 * my)
        .padding(.horizontal, -mx)
        .padding(.vertical, -my)
        .allowsHitTesting(false)
    }

    private func drawSparks(_ ctx: GraphicsContext, t: Double) {
        let star = SVGPath.path(STAR)
        for (i, s) in SPARKS.enumerated() {
            let p = min(1, max(0, (t - Double(i) * 0.025) / 0.7))
            let k = SPARK_EASE(p)
            let opacity = p < 0.7 ? 1 : 1 - SPARK_EASE((p - 0.7) / 0.3)
            var c = ctx
            c.opacity = opacity
            c.translateBy(x: size / 2 + s.dx * k, y: height * 0.3 + 7 + s.dy * k)
            c.rotate(by: .degrees(140 * k))
            let scale = (0.3 + 0.7 * k) * 14 / 20
            c.scaleBy(x: scale, y: scale)
            c.translateBy(x: -10, y: -10)
            c.fill(star, with: .color(s.color))
        }
    }

    private func react() {
        if busy { return }
        busy = true
        onTap?()
        let now = Date()
        taps = taps.filter { now.timeIntervalSince($0) < 3 } + [now]
        let dizzy = taps.count >= 5
        if dizzy { taps = [] }

        let pick: TikoMove = dizzy ? .flip : [.boing, .flip, .giggle].randomElement()!
        face = dizzy ? .confused : .giggle
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        var wait = 0.6
        if !reduceMotion {
            burst = now
            active = ActiveMove(kind: pick, start: now)
            wait = Moves.track(pick).duration
        }
        Task {
            try? await Task.sleep(for: .seconds(wait))
            busy = false
            try? await Task.sleep(for: .seconds(dizzy ? 0.9 : 0.25))
            face = nil
        }
    }
}

// The drawing itself, in the website's 120 × 124 viewBox.
enum TikoArt {
    private static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry))
    }

    private static func line(_ c: GraphicsContext, _ d: String, _ width: CGFloat, _ color: Color = INK) {
        c.stroke(SVGPath.path(d), with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private static func blob(_ c: GraphicsContext, _ p: Path, fill: Color, stroke: CGFloat) {
        c.fill(p, with: .color(fill))
        c.stroke(p, with: .color(INK), lineWidth: stroke)
    }

    private static func around(_ c: GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ body: (inout GraphicsContext) -> Void) -> GraphicsContext {
        var c = c
        c.translateBy(x: x, y: y)
        body(&c)
        c.translateBy(x: -x, y: -y)
        return c
    }

    private static func arm(_ c: GraphicsContext, _ a: Arm, rotate: Double = 0) {
        let c = rotate == 0 ? c : around(c, 90, 74) { $0.rotate(by: .degrees(rotate)) }
        line(c, a.rawValue, 10)
        line(c, a.rawValue, 4.5, LIME)
        let h = a.hand
        blob(c, ellipse(h.x, h.y, 5.5, 5.5), fill: LIME, stroke: 3)
    }

    // t is seconds since Tiko appeared, or nil for no motion at all.
    static func draw(_ ctx: GraphicsContext, mood: TikoMood, t: Double?, idle: Bool) {
        var body = ctx
        if let t, idle {
            let v: [Double]
            switch mood {
            case .wave, .happy, .point: v = Idle.hop.loop(t, period: 3.6)
            case .cheer, .giggle: v = Idle.bounce.loop(t, period: 0.95)
            default: v = Idle.breathe.loop(t, period: 3.4)
            }
            body = around(ctx, 60, 115) { c in
                c.translateBy(x: 0, y: v[0])
                c.scaleBy(x: v[1], y: v[2])
            }
        }

        // Antenna: the stopwatch button.
        let tilt = t.map { Idle.antenna.loop($0, period: 2.6)[0] } ?? 0
        let antenna = around(body, 60, 36) { $0.rotate(by: .degrees(tilt)) }
        line(antenna, "M60 36 Q57 22 64 12", 3.5)
        blob(antenna, ellipse(64, 11, 6.5, 6.5), fill: ORANGE, stroke: 3)

        // Feet, then arms, behind the body.
        blob(body, ellipse(46, 109, 10, 6.5), fill: LIME, stroke: 3)
        blob(body, ellipse(74, 109, 10, 6.5), fill: LIME, stroke: 3)

        let waveAngle = t.map { Idle.wave.loop($0, period: 1.2)[0] } ?? 0
        func arms() {
            switch mood {
            case .cheer, .giggle: arm(body, .upL); arm(body, .upR)
            case .wave: arm(body, .downL); arm(body, .upR, rotate: waveAngle)
            case .point: arm(body, .downL); arm(body, .pointR)
            case .think: arm(body, .downL); arm(body, .chinR)
            default: arm(body, .downL); arm(body, .downR)
            }
        }
        if mood != .think { arms() }

        blob(body, ellipse(60, 71, 36, 35), fill: LIME, stroke: 3.5)
        var shine = around(body, 45, 50) { $0.rotate(by: .degrees(-25)) }
        shine.opacity = 0.35
        shine.fill(ellipse(45, 50, 11, 6), with: .color(.white))
        var cheeks = body
        cheeks.opacity = mood == .giggle ? 0.9 : 0.55
        cheeks.fill(ellipse(34, 81, 5.5, 3.2), with: .color(ORANGE))
        cheeks.fill(ellipse(86, 81, 5.5, 3.2), with: .color(ORANGE))

        eyes(body, mood, t: t)
        brows(body, mood)
        mouth(body, mood)
        if mood == .think { arms() }

        // Floating marks sit outside the hop, like on the website.
        let float = t.map { Idle.float.loop($0, period: 2.2) } ?? [0, 1]
        var mark = ctx
        mark.opacity = float[1]
        if mood == .confused {
            mark.draw(Text("?").font(.system(size: 26, weight: .heavy)).foregroundColor(VIOLET),
                      at: CGPoint(x: 96, y: 30 + float[0]), anchor: UnitPoint(x: 0, y: 0.8))
        } else if mood == .sleep {
            mark.draw(Text("z z").font(.system(size: 16, weight: .heavy)).foregroundColor(VIOLET),
                      at: CGPoint(x: 88, y: 34 + float[0]), anchor: UnitPoint(x: 0, y: 0.8))
        }
    }

    private static func eyes(_ c: GraphicsContext, _ mood: TikoMood, t: Double?) {
        switch mood {
        case .sleep:
            line(c, "M39 68 Q47 74 55 68", 3.5)
            line(c, "M65 68 Q73 74 81 68", 3.5)
        case .giggle:
            // Squeezed-shut happy eyes: ^ ^
            line(c, "M39 70 Q47 58 55 70", 3.5)
            line(c, "M65 70 Q73 58 81 70", 3.5)
        default:
            // Where the pupils look.
            let look: (CGFloat, CGFloat) = switch mood {
            case .think: (3, -3)
            case .sad: (0, 3)
            case .point: (3, 0)
            default: (1, 1)
            }
            let blink = t.map { Idle.blink.loop($0, period: 4.6)[0] } ?? 1
            let e = around(c, 60, 66) { $0.scaleBy(x: 1, y: blink) }
            for cx: CGFloat in [47, 73] {
                blob(e, ellipse(cx, 66, 9.5, 11.5), fill: .white, stroke: 3)
                e.fill(ellipse(cx + look.0, 66 + look.1, 5, 5), with: .color(INK))
                e.fill(ellipse(cx + look.0 + 1.8, 66 + look.1 - 2, 1.6, 1.6), with: .color(.white))
            }
        }
    }

    private static func brows(_ c: GraphicsContext, _ mood: TikoMood) {
        switch mood {
        case .sad:
            line(c, "M39 52 L52 49", 3)
            line(c, "M68 49 L81 52", 3)
        case .think, .confused:
            line(c, "M66 50 Q73 45 81 49", 3)
        default:
            break
        }
    }

    private static func mouth(_ c: GraphicsContext, _ mood: TikoMood) {
        switch mood {
        case .cheer, .giggle:
            let open = SVGPath.path("M48 83 Q60 101 72 83 Z")
            c.fill(open, with: .color(INK))
            c.stroke(open, with: .color(INK), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
            c.fill(SVGPath.path("M53 92 Q60 97 67 92 Q60 89 53 92 Z"), with: .color(ORANGE))
        case .sad: line(c, "M51 91 Q60 84 69 91", 3.5)
        case .think: line(c, "M54 89 Q60 87 66 89", 3.5)
        case .confused: line(c, "M49 89 q5.5 -5 11 0 t11 0", 3.5)
        case .sleep: c.fill(ellipse(60, 88, 3.5, 4), with: .color(INK))
        default: line(c, "M49 84 Q60 95 71 84", 3.5)
        }
    }
}
