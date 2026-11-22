import DesignSystem
import Domain
import SwiftUI
import Tiko

// The Streak Tower moment, full screen (web/src/components/streak-celebration.tsx).
// Today's block drops onto your tower with a thud, a shake and a camera
// punch; the number rolls up; a sticker slams in; Tiko leaps onto the top
// and plants a flag; confetti bursts. Milestones light the floor and flip a
// badge in. A broken streak wobbles and falls, and Tiko starts a new one.
// One clock drives it all; a tap skips to the end. Haptics are hand-made
// (Haptics.swift) and land on the same beats.
public struct StreakCelebrationView: View {
    let c: StreakCelebration
    let onClose: () -> Void
    let onTower: () -> Void
    let onPlay: () -> Void

    @State private var start = Date()
    @State private var skipped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(c: StreakCelebration, onClose: @escaping () -> Void, onTower: @escaping () -> Void, onPlay: @escaping () -> Void) {
        self.c = c
        self.onClose = onClose
        self.onTower = onTower
        self.onPlay = onPlay
    }

    private var up: Bool { if case .up = c { true } else { false } }
    private var from: Int { switch c { case let .up(f, _, _): f; case let .fell(f): f } }
    private var to: Int { switch c { case let .up(_, t, _): t; case .fell: 0 } }
    private var peak: Int { up ? to : from }
    private var milestone: Bool { up && Streak.isMilestone(to) }
    private var end: Double { up ? (milestone ? 4.9 : 3.6) : 3.6 }
    private var foot: Double { up ? (milestone ? 4.3 : 3.0) : 2.9 }

    public var body: some View {
        GeometryReader { geo in
            let L = Layout(size: geo.size, peak: peak, safeBottom: geo.safeAreaInsets.bottom, safeTop: geo.safeAreaInsets.top)
            TimelineView(.animation) { tl in
                let t = min(end + 2, max(0, tl.date.timeIntervalSince(start)))
                scene(t, L)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { skip() }
        .onAppear { if reduceMotion { start = Date().addingTimeInterval(-end) } }
        .task { await haptics() }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func skip() {
        guard Date().timeIntervalSince(start) < end else { return }
        skipped = true
        start = Date().addingTimeInterval(-end)
    }

    // MARK: Layout

    struct Layout {
        let W, H, cx, bw, bh, nf, numberTop, stickerTop, baseY, tikoSize, towerTop: CGFloat
        let shown: Int
        let days: [Int] // bottom → top

        init(size: CGSize, peak: Int, safeBottom: CGFloat, safeTop: CGFloat) {
            W = size.width
            H = size.height
            cx = W / 2
            bw = min(250, max(160, W * 0.46))
            bh = (bw * 0.34).rounded()
            nf = min(140, max(84, W * 0.22)).rounded()
            numberTop = max(36, H * 0.06) + safeTop * 0.6
            stickerTop = numberTop + nf * 1.02
            baseY = H - 190 - safeBottom
            tikoSize = (bh * 1.55).rounded()
            let room = Int(((baseY - (stickerTop + 64 + tikoSize)) / bh).rounded(.down))
            let n = max(1, min(room, min(max(peak, 1), 6)))
            shown = n
            days = (0..<n).map { peak - n + 1 + $0 }
            towerTop = baseY - CGFloat(n) * bh
        }
    }

    // MARK: The scene at time t

    @ViewBuilder
    private func scene(_ t: Double, _ L: Layout) -> some View {
        let diag = hypot(L.W, L.H)
        // The screen shakes and the camera punches in when the block lands.
        let shakeP = seg(t, 1.25, 1.6)
        let amp = up && shakeP > 0 && shakeP < 1 ? 11 * (1 - shakeP) : 0
        let punch = up ? max(0, wobble(t - 1.25, 9, 5)) * 0.045 : 0
        let dimStage = milestone ? 1 - 0.55 * seg(t, 3.5, 3.8) : 1

        ZStack(alignment: .topLeading) {
            Circle().fill(Theme.ink)
                .frame(width: diag * 2.1, height: diag * 2.1)
                .scaleEffect(out(seg(t, 0, 0.45)))
                .position(x: L.cx, y: L.H / 2)

            Rays(color: up ? Theme.lime : Theme.violet)
                .frame(width: diag * 2, height: diag * 2)
                .rotationEffect(.degrees(t * 10))
                .opacity(0.9 * seg(t, 0.3, 1.1))
                .position(x: L.cx, y: L.towerTop)

            ZStack(alignment: .topLeading) {
                number(t, L)
                sparkles(t, L)
                sticker(t, L)
                ForEach(Array(L.days.enumerated()), id: \.offset) { i, d in block(i, d, t, L) }
                dust(t, L)
                if up { flag(t, L) }
                tiko(t, L)
            }
            .frame(width: L.W, height: L.H, alignment: .topLeading)
            .scaleEffect(1 + punch)
            .offset(x: sin(t * 95) * amp, y: cos(t * 77) * amp * 0.6)
            .opacity(dimStage)

            if milestone { badge(t, L) }
            Confetti(t: t, bits: bits(L))
                .frame(width: L.W, height: L.H)
                .allowsHitTesting(false)
            footer(t, L)
        }
        .frame(width: L.W, height: L.H, alignment: .topLeading)
    }

    // The tower's blocks: the new one drops and squashes, the old ones rise
    // into place and take the hit (or wobble and fly off when it falls).
    @ViewBuilder
    private func block(_ i: Int, _ day: Int, _ t: Double, _ L: Layout) -> some View {
        let finalTop = L.baseY - CGFloat(i + 1) * L.bh
        let isNew = up && i == L.shown - 1 && to > from
        let weekday = Streak.weekday(daysAgo: peak - day + (up ? 0 : 1))
        let flash = milestone ? sin(.pi * seg(t, 3.0 + Double(i) * 0.09, 3.3 + Double(i) * 0.09)) : 0
        let view = StreakBlockView(day: day, weekday: weekday, width: L.bw, height: L.bh)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white).opacity(flash * 0.85))
        if isNew {
            let p = seg(t, 0.85, 1.25) * seg(t, 0.85, 1.25)
            let y = lerp(-finalTop - L.bh * 2, 0, p)
            let w = max(0, wobble(t - 1.25, 16, 7))
            view.scaleEffect(x: 1 + 0.16 * w, y: 1 - 0.24 * w, anchor: .bottom)
                .position(x: L.cx, y: finalTop + L.bh / 2 + y)
                .opacity(t >= 0.85 ? 1 : 0)
        } else if up || t < 1.8 {
            let p = back(seg(t, 0.25 + Double(i) * 0.07, 0.8 + Double(i) * 0.07))
            let hit = up ? max(0, wobble(t - 1.25, 13, 8)) * 5 * Double(i + 1) / Double(L.shown) : 0
            let tilt = up ? 0 : sin(t * 22 + Double(i)) * Double(i + 1) * 1.6 * seg(t, 0.9, 1.8)
            view.scaleEffect(1 + 0.06 * flash)
                .rotationEffect(.degrees(tilt), anchor: .bottom)
                .position(x: L.cx, y: finalTop + L.bh / 2 + (1 - p) * (L.H - finalTop + 40) + hit)
        } else {
            // Falls, top first: each block flies off with its own spin.
            let r = Rand(seed: UInt64(i + 1) * 7919)
            let vx = (r.next() - 0.5) * 900, vy = -300 - r.next() * 500, vr = (r.next() - 0.5) * 9
            let tau = max(0, t - 1.8 - Double(L.shown - 1 - i) * 0.06)
            view.rotationEffect(.radians(vr * tau))
                .position(x: L.cx + vx * tau, y: finalTop + L.bh / 2 + vy * tau + 0.5 * 2600 * tau * tau)
                .opacity(1 - seg(tau, 0.7, 1.1))
        }
    }

    // Dust puffs either side of the landing.
    private func dust(_ t: Double, _ L: Layout) -> some View {
        let p = seg(t, 1.25, 1.85)
        return ForEach(0..<6, id: \.self) { k in
            let side: CGFloat = k % 2 == 0 ? -1 : 1, n = CGFloat(k / 2)
            Circle().fill(Color(hex: "e7e2d4"))
                .frame(width: 18, height: 18)
                .scaleEffect(0.4 + out(p) * (1 + n * 0.3))
                .position(x: L.cx + side * (L.bw / 2 + out(p) * (30 + n * 22)), y: L.towerTop - out(p) * (10 + n * 8))
                .opacity(up && p > 0 && p < 1 ? (1 - p) * 0.9 : 0)
        }
    }

    // The number rolls from yesterday's to today's, then pops.
    private func number(_ t: Double, _ L: Layout) -> some View {
        let p = up ? back(seg(t, 1.35, 1.85)) : 0
        let appear = seg(t, 0.4, 0.7)
        let pop = up ? 1 + 0.16 * sin(.pi * seg(t, 1.8, 2.15)) : 1
        let scale = (0.6 + 0.4 * back(seg(t, 0.4, 0.9))) * pop
        let digits = String(max(peak, from)).count
        return ZStack {
            Text("\(from)")
                .foregroundStyle(.white)
                .offset(y: -1.15 * L.nf * p)
                .opacity(1 - p)
            if up {
                Text("\(to)")
                    .foregroundStyle(Theme.lime)
                    .offset(y: 1.15 * L.nf * (1 - p))
            }
        }
        .font(.display(L.nf))
        .frame(width: L.nf * (1.05 * CGFloat(digits) + 0.4), height: L.nf * 1.1)
        .clipped()
        .scaleEffect(scale)
        .rotationEffect(.degrees(up ? 0 : -8 * out(seg(t, 1.9, 2.2))))
        .opacity(appear * (up ? 1 : 1 - 0.6 * seg(t, 1.9, 2.3)))
        .position(x: L.cx, y: L.numberTop + L.nf * 0.51)
    }

    private func sparkles(_ t: Double, _ L: Layout) -> some View {
        let spots: [(CGFloat, CGFloat)] = [(-0.62, 0.18), (0.66, 0.08), (-0.45, 0.86), (0.52, 0.92), (0.02, -0.12), (0.86, 0.5)]
        let colors = [Theme.lime, Theme.orange, Theme.violet, .white, Color(hex: "7fd3ff"), Theme.lime]
        return ForEach(0..<spots.count, id: \.self) { k in
            let p = seg(t, 1.8 + Double(k) * 0.05, 2.5 + Double(k) * 0.05)
            Sparkle()
                .fill(colors[k])
                .overlay(Sparkle().stroke(Theme.ink, lineWidth: 1.4))
                .frame(width: L.nf * 0.26, height: L.nf * 0.26)
                .scaleEffect(back(min(1, p * 1.6)))
                .rotationEffect(.degrees(p * 90))
                .position(x: L.cx + spots[k].0 * L.nf * 1.1 + L.nf * 0.13, y: L.numberTop + spots[k].1 * L.nf + L.nf * 0.13)
                .opacity(up && p > 0 && p < 1 ? sin(.pi * p) : 0)
        }
    }

    private func sticker(_ t: Double, _ L: Layout) -> some View {
        let sp = out(seg(t, up ? 1.75 : 2.15, up ? 2.1 : 2.5))
        let label = up ? (to == 1 ? "🔥 DAY 1!" : "🔥 DAY STREAK!") : "💥 TOWER DOWN"
        return Text(label)
            .font(.display(min(28, max(18, L.W * 0.05))))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 16).fill(up ? Theme.orange : Theme.violet))
            .background(RoundedRectangle(cornerRadius: 16).fill(.black).offset(x: 6, y: 7))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.ink, lineWidth: 4))
            .scaleEffect(lerp(2.6, 1, sp))
            .rotationEffect(.degrees(lerp(-18, -4, sp)))
            .opacity(sp > 0 ? 1 : 0)
            .position(x: L.cx, y: L.stickerTop + 24)
    }

    // The flag, planted on the top block.
    private func flag(_ t: Double, _ L: Layout) -> some View {
        let poleH = L.bh * 1.75
        let x = L.cx - L.bw * 0.32
        return ZStack(alignment: .bottomLeading) {
            Capsule().fill(.white)
                .frame(width: 5, height: poleH)
                .scaleEffect(x: 1, y: back(seg(t, 2.55, 2.9)), anchor: .bottom)
            Text("\(to)")
                .font(.display(L.bh * 0.34))
                .foregroundStyle(Theme.ink)
                .frame(width: L.bh * 1.05, height: L.bh * 0.62)
                .background(Theme.orange)
                .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: 3))
                .scaleEffect(x: back(seg(t, 2.8, 3.05)), y: 1, anchor: .leading)
                .transformEffect(CGAffineTransform(a: 1, b: tan(sin(t * 7) * 5 * .pi / 180), c: 0, d: 1, tx: 0, ty: 0))
                .offset(x: 5, y: -poleH + L.bh * 0.62)
        }
        .frame(width: L.bh * 1.2, height: poleH, alignment: .bottomLeading)
        .position(x: x + L.bh * 0.6, y: L.towerTop - poleH / 2)
    }

    // Tiko leaps onto the top block (or walks in sad and picks up a block).
    @ViewBuilder
    private func tiko(_ t: Double, _ L: Layout) -> some View {
        let tikoX = L.cx + L.bw * 0.04, tikoY = L.towerTop - L.tikoSize * 0.9
        if up {
            let p = inOut(seg(t, 1.95, 2.55)), land = max(0, wobble(t - 2.55, 14, 8))
            let x = lerp(L.W + 40, tikoX, p), y = lerp(tikoY + 60, tikoY, p) - sin(.pi * p) * L.H * 0.22
            TikoView(mood: .cheer, size: L.tikoSize, still: true, interactive: false)
                .scaleEffect(x: 1 + 0.12 * land, y: 1 - 0.16 * land, anchor: .bottom)
                .rotationEffect(.degrees((1 - p) * -25))
                .position(x: x + L.tikoSize / 2, y: y + L.tikoSize / 2)
                .opacity(t >= 1.95 ? 1 : 0)
        } else {
            let p = back(seg(t, 2.1, 2.5))
            VStack(spacing: 2) {
                StreakBlockView(day: 1, weekday: Streak.weekday(daysAgo: -1), width: L.bw * 0.55, height: L.bh * 0.55)
                    .scaleEffect(back(seg(t, 2.6, 2.9)))
                TikoView(mood: t >= 2.6 ? .happy : .sad, size: L.tikoSize, still: true, interactive: false)
            }
            .scaleEffect(p)
            .opacity(min(1, p * 3))
            .position(x: L.cx, y: L.baseY - L.tikoSize / 2 - L.bh * 0.3)
        }
    }

    // A milestone's badge flips in over the tower.
    private func badge(_ t: Double, _ L: Layout) -> some View {
        let p = back(seg(t, 3.55, 4.15))
        return VStack(spacing: 12) {
            VStack(spacing: 0) {
                Text("\(to)").font(.display(64)).foregroundStyle(Theme.ink)
                Text("DAYS").font(.mono(13)).tracking(2.4).foregroundStyle(Theme.ink)
            }
            .frame(width: 168, height: 168)
            .background(Circle().fill(StreakBlockView.fill(to)))
            .background(Circle().fill(.black).offset(x: 10, y: 12))
            .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 6))
            Text(Streak.title(to))
                .font(.display(18))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                .background(RoundedRectangle(cornerRadius: 12).fill(.black).offset(x: 6, y: 7))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.ink, lineWidth: 4))
        }
        .rotation3DEffect(.degrees((1 - p) * 100), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .scaleEffect(0.6 + 0.4 * p)
        .offset(y: sin(t * 2.4) * 4)
        .opacity(seg(t, 3.55, 3.7))
        .position(x: L.cx, y: L.H * 0.42)
    }

    private func footer(_ t: Double, _ L: Layout) -> some View {
        let fp = out(seg(t, foot, foot + 0.45))
        let next = up ? Streak.next(after: to) : nil
        let (title, sub): (String, String) = {
            if !up { return ("Your \(from)-day tower fell", "One duel starts a new one. Tiko's already stacking.") }
            if milestone {
                return ("\(to)-day streak!", next.map { "Badge unlocked. The next one is at \($0) days. Come back tomorrow for day \(to + 1)." } ?? "The tallest tower on Apticks. Keep stacking.")
            }
            if to == 1 { return (from == 0 ? "A new tower begins!" : "Day 1 of your tower!", "Play tomorrow to stack day 2 on top.") }
            return ("\(to)-day streak!", "Come back tomorrow to make it \(to + 1).")
        }()
        return VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(title).font(.display(22)).foregroundStyle(.white)
                Text(sub).font(.ui(15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            }
            HStack(spacing: 12) {
                Button(up ? "Keep going" : "Play a duel") { up ? onClose() : onPlay() }
                    .buttonStyle(PressableStyle(fill: Theme.lime, foreground: Theme.ink, pop: Color(hex: "5f7710"), height: 56))
                Button(up ? "See your tower" : "Not now") { up ? onTower() : onClose() }
                    .buttonStyle(FilledStyle(fill: Theme.surface, foreground: Theme.text, border: Theme.line, height: 56))
            }
        }
        .padding(.horizontal, 24)
        .frame(width: L.W)
        .position(x: L.cx, y: L.H - 110)
        .opacity(fp)
        .offset(y: (1 - fp) * 30)
        .allowsHitTesting(t >= foot + 0.2)
    }

    // MARK: Haptics, on the animation's beats

    private func haptics() async {
        guard !reduceMotion else { return }
        let h = Haptics.shared
        var beats: [(Double, () -> Void)] = up
            ? [(1.25, { h.thud() }), (1.5, { h.tick(0.4) }), (1.8, { h.slam() }), (2.55, { h.tick(0.7) })]
            : [(1.8, { h.rumble() }), (2.6, { h.tick(0.5) })]
        if milestone {
            beats += (0..<6).map { i in (3.0 + Double(i) * 0.09, { h.tick(0.3 + Float(i) * 0.1) }) }
            beats.append((3.9, { h.fanfare() }))
        }
        for (at, fire) in beats.sorted(by: { $0.0 < $1.0 }) {
            let wait = at - Date().timeIntervalSince(start)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            if Task.isCancelled || skipped { return }
            fire()
        }
    }

    // MARK: Confetti

    private func bits(_ L: Layout) -> [Bit] {
        guard up else { return [] }
        var all = Bit.burst(x: L.cx + L.bw * 0.04 + L.tikoSize / 2, y: L.towerTop, n: 110, spread: 2.4, speed: 700...1400, born: 2.6, seed: 11)
        if milestone { all += Bit.burst(x: L.cx, y: L.H * 0.42, n: 160, spread: .pi * 2, speed: 500...1300, born: 3.9, seed: 29) }
        return all
    }
}

// MARK: - Pieces

struct Bit {
    let x, y, vx, vy, spin, w, h, born: Double
    let color: Color
    let round: Bool

    static let colors = [Theme.lime, Theme.violet, Theme.orange, .white, Color(hex: "7fd3ff")]

    static func burst(x: Double, y: Double, n: Int, spread: Double, speed: ClosedRange<Double>, born: Double, seed: UInt64) -> [Bit] {
        let r = Rand(seed: seed)
        return (0..<n).map { i in
            let a = -Double.pi / 2 + (r.next() - 0.5) * spread, s = speed.lowerBound + r.next() * (speed.upperBound - speed.lowerBound)
            let round = r.next() < 0.3
            return Bit(x: x, y: y, vx: cos(a) * s, vy: sin(a) * s, spin: (r.next() - 0.5) * 14,
                       w: round ? 9 : 7 + r.next() * 7, h: round ? 9 : 12 + r.next() * 10, born: born,
                       color: colors[i % colors.count], round: round)
        }
    }
}

// Confetti by formula (no state), so a skipped or reduced-motion start
// still draws the right frame: gravity, a little drag, spin and flutter.
struct Confetti: View {
    let t: Double
    let bits: [Bit]

    var body: some View {
        Canvas { g, _ in
            for b in bits {
                let tau = t - b.born
                guard tau > 0, tau < 2.8 else { continue }
                let drag = 1 - min(tau, 1.6) * 0.32
                let x = b.x + b.vx * tau * drag, y = b.y + b.vy * tau * drag + 0.5 * 1700 * tau * tau
                var ctx = g
                ctx.opacity = max(0, min(1, 1 - (tau - 1.8) / 0.8))
                ctx.translateBy(x: x, y: y)
                ctx.rotate(by: .radians(b.spin * tau))
                if b.round {
                    ctx.fill(Path(ellipseIn: CGRect(x: -b.w / 2, y: -b.w / 2, width: b.w, height: b.w)), with: .color(b.color))
                } else {
                    ctx.scaleBy(x: 1, y: cos(b.spin * tau * 1.7))
                    ctx.fill(Path(CGRect(x: -b.w / 2, y: -b.h / 2, width: b.w, height: b.h)), with: .color(b.color))
                }
            }
        }
    }
}

// Flat rays turning behind the tower.
struct Rays: View {
    let color: Color
    var body: some View {
        Canvas { g, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2), r = size.width / 2
            for i in 0..<18 {
                let a0 = Double(i) * 20 * .pi / 180, a1 = (Double(i) * 20 + 10) * .pi / 180
                var p = Path()
                p.move(to: c)
                p.addLine(to: CGPoint(x: c.x + r * cos(a0), y: c.y + r * sin(a0)))
                p.addLine(to: CGPoint(x: c.x + r * cos(a1), y: c.y + r * sin(a1)))
                p.closeSubpath()
                g.fill(p, with: .color(color.opacity(0.07)))
            }
        }
    }
}

// A four-point star.
nonisolated struct Sparkle: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY), w = r.width / 2, h = r.height / 2
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - h))
        p.addCurve(to: CGPoint(x: c.x + w, y: c.y), control1: CGPoint(x: c.x + w * 0.1, y: c.y - h * 0.2), control2: CGPoint(x: c.x + w * 0.2, y: c.y - h * 0.1))
        p.addCurve(to: CGPoint(x: c.x, y: c.y + h), control1: CGPoint(x: c.x + w * 0.2, y: c.y + h * 0.1), control2: CGPoint(x: c.x + w * 0.1, y: c.y + h * 0.2))
        p.addCurve(to: CGPoint(x: c.x - w, y: c.y), control1: CGPoint(x: c.x - w * 0.1, y: c.y + h * 0.2), control2: CGPoint(x: c.x - w * 0.2, y: c.y + h * 0.1))
        p.addCurve(to: CGPoint(x: c.x, y: c.y - h), control1: CGPoint(x: c.x - w * 0.2, y: c.y - h * 0.1), control2: CGPoint(x: c.x - w * 0.1, y: c.y - h * 0.2))
        return p
    }
}

// A small seeded random source, so the confetti and the falling blocks are
// the same on every frame.
final class Rand {
    private var s: UInt64
    init(seed: UInt64) { s = seed &* 0x9E37_79B9_7F4A_7C15 }
    func next() -> Double {
        s = s &+ 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
}

// MARK: - Timing

private func clamp(_ v: Double, _ a: Double = 0, _ b: Double = 1) -> Double { min(b, max(a, v)) }
private func seg(_ t: Double, _ a: Double, _ b: Double) -> Double { clamp((t - a) / (b - a)) }
private func lerp(_ a: Double, _ b: Double, _ x: Double) -> Double { a + (b - a) * x }
private func out(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
private func inOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
private func back(_ x: Double) -> Double { 1 + 2.6 * pow(x - 1, 3) + 1.6 * pow(x - 1, 2) }
// A damped wobble after an impact: 1 at the hit, settling to 0.
private func wobble(_ tau: Double, _ freq: Double = 13, _ damp: Double = 7) -> Double { tau < 0 ? 0 : exp(-damp * tau) * cos(freq * tau) }
