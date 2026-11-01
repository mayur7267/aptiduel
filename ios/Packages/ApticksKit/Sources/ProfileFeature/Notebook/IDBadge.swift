import DesignSystem
import Domain
import SwiftUI
import Tiko
import UIKit

// Your player card, hung on a lanyard. It swings as a damped pendulum:
// it settles towards real "down" as you tilt the phone, a light breeze
// keeps it moving, a tap flicks it and a finger can push it sideways. A holographic
// seal and a sheen of light move with the swing.
struct IDBadge: View {
    let me: Me
    let saved: Bool
    let tilt: Tilt
    let onEdit: () -> Void

    @State private var swing = Swing()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let pivotY: CGFloat = 50
    private static let cardHeight: CGFloat = 238

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width - 40, 320)
            let pivot = CGPoint(x: geo.size.width / 2, y: Self.pivotY)
            TimelineView(.animation) { tl in
                let theta = swing.step(to: tl.date, rest: -tilt.x * 0.38, calm: reduceMotion)
                ZStack {
                    Lanyard(pivot: pivot)
                    card(width: width, theta: theta)
                        .rotationEffect(.radians(theta), anchor: .top)
                        .position(x: pivot.x, y: pivot.y + Self.cardHeight / 2)
                }
            }
        }
        .frame(height: Self.pivotY + Self.cardHeight + 30)
        .overlay(alignment: .bottom) {
            Button(action: onEdit) {
                Label("Edit profile", systemImage: "pencil")
                    .font(.ui(13, .bold))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(Capsule().fill(Theme.surface))
                    .overlay(Capsule().strokeBorder(Theme.line))
            }
            .buttonStyle(Press())
            .offset(y: 26)
        }
        .padding(.bottom, 30)
        .simultaneousGesture(
            DragGesture(minimumDistance: 6)
                .onChanged { swing.push(offset: $0.translation.width) }
                .onEnded { swing.release(velocity: $0.velocity.width) }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Player card: \(me.name), \(tierFor(me.rating).name), rating \(me.rating)")
        .accessibilityAction(named: "Swing the card") { swing.flick() }
    }

    private func card(width: CGFloat, theta: Double) -> some View {
        let tier = tierFor(me.rating)
        return VStack(spacing: 0) {
            HStack(spacing: 7) {
                Mark(size: 18)
                Text("APTICKS").font(.mono(12)).tracking(2.4)
                Spacer()
                Text("PLAYER CARD").font(.mono(10, .semibold)).tracking(1.4).opacity(0.7)
            }
            .foregroundStyle(Theme.lime)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Theme.ink)

            HStack(alignment: .top, spacing: 14) {
                photo
                VStack(alignment: .leading, spacing: 7) {
                    field("NAME", me.hasGuestName ? "—" : me.name)
                    field("COLLEGE", me.college ?? "—")
                    HStack(spacing: 18) {
                        field("BATCH", me.gradYear.map { "’\(String(String($0).suffix(2)))" } ?? "—")
                        field("TIER", tier.name)
                    }
                    field("RATING", grouped(me.rating), big: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            Spacer(minLength: 0)

            HStack(alignment: .bottom) {
                Barcode(seed: me.id).frame(width: 120, height: 26)
                Text(playerNumber).font(.mono(10, .semibold)).foregroundStyle(Theme.ink.opacity(0.6))
                Spacer()
                Hologram(phase: theta * 3 + tilt.x * 1.5).frame(width: 40, height: 40)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .frame(width: width, height: Self.cardHeight)
        .background(Theme.text)
        // A sheen sliding across the laminate as it swings.
        .overlay {
            LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: width * 0.45)
                .rotationEffect(.degrees(20))
                .offset(x: CGFloat(theta * 420 + tilt.x * 60))
                .blendMode(.softLight)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            Stamp(text: saved ? "VERIFIED" : "GUEST", color: saved ? Theme.violetStrong : Theme.red)
                .padding(.top, 58)
                .padding(.trailing, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .top) { clip }
        // Tiko rides on top of the card.
        .overlay(alignment: .topTrailing) {
            TikoView(mood: .wave, size: 54) { swing.flick() }
                .offset(x: -26, y: -TikoView.height(for: 54) + 6)
        }
        .shadow(color: .black.opacity(0.45), radius: 18, y: 12)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            swing.flick()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private var photo: some View {
        Avatar(name: me.name, size: 64)
            .frame(width: 80, height: 98)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.raised))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.ink.opacity(0.15), lineWidth: 1))
            .overlay(alignment: .bottom) {
                Text("PHOTO").font(.mono(7, .bold)).tracking(1.5).foregroundStyle(Theme.muted).padding(.bottom, 4)
            }
    }

    private func field(_ label: String, _ value: String, big: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.mono(8, .bold)).tracking(1.4).foregroundStyle(Theme.ink.opacity(0.45))
            Text(value)
                .font(big ? .mono(20) : .ui(14, .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // The metal clip the card hangs from.
    private var clip: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(LinearGradient(colors: [Color(hex: "e8ecf3"), Color(hex: "8b93a7"), Color(hex: "d5dae4")], startPoint: .top, endPoint: .bottom))
                .frame(width: 46, height: 22)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.ink.opacity(0.35), lineWidth: 1))
            Capsule().fill(Theme.ink.opacity(0.55)).frame(width: 24, height: 5)
        }
        .offset(y: -10)
    }

    private var playerNumber: String {
        "No. " + String(me.id.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
    }
}

// The pendulum: θ'' = −k·sin(θ − rest) − c·θ'. A reference type stepped
// from the timeline, so the physics runs every frame without re-rendering
// anything else.
final class Swing {
    private(set) var theta = 0.3 // hung up a little off-centre, so it swings in
    private var omega = 0.0
    private var last: Date?
    private var held: Double? // angle while a finger is pushing it
    private var previousHeld: Double?
    private var heldVelocity = 0.0
    private var calm = false

    private let k = 16.0 // stiffness: about a 1.6 s swing
    private let damping = 0.9

    // With Reduce Motion on (calm), it hangs straight and only swings when
    // tapped or pushed: no breeze or tilt, and it settles quickly.
    func step(to now: Date, rest: Double, calm: Bool) -> Double {
        defer { last = now }
        self.calm = calm
        guard let last else {
            if calm { theta = 0 }
            return theta
        }
        let dt = min(1.0 / 30, now.timeIntervalSince(last))
        if let held {
            if let previousHeld, dt > 0 { heldVelocity = (held - previousHeld) / dt }
            previousHeld = held
            theta = held
            omega = heldVelocity
            return theta
        }
        // A slow breeze, so it never hangs perfectly still.
        let t = now.timeIntervalSinceReferenceDate
        let rest = calm ? 0 : rest + 0.04 * sin(t * 0.9) + 0.015 * sin(t * 2.3 + 1)
        let damping = calm ? 3 : self.damping
        let n = 4
        let h = dt / Double(n)
        for _ in 0..<n {
            omega += (-k * sin(theta - rest) - damping * omega) * h
            theta += omega * h
        }
        return theta
    }

    // A finger pushing the bottom of the card sideways.
    func push(offset: CGFloat) {
        held = max(-0.9, min(0.9, -Double(offset) / 220))
    }

    func release(velocity: CGFloat) {
        held = nil
        previousHeld = nil
        omega = max(-6, min(6, heldVelocity - Double(velocity) / 600))
    }

    func flick() {
        omega += (theta >= 0 ? 1 : -1) * (calm ? 2 : 3)
    }
}

// Two straps from above meeting at the clip.
private struct Lanyard: View {
    let pivot: CGPoint

    var body: some View {
        Canvas { ctx, _ in
            for side in [-1.0, 1.0] {
                var strap = Path()
                strap.move(to: CGPoint(x: pivot.x + side * 70, y: -20))
                strap.addLine(to: CGPoint(x: pivot.x + side * 7, y: pivot.y - 8))
                ctx.stroke(strap, with: .color(Theme.limeEdge), style: StrokeStyle(lineWidth: 11, lineCap: .round))
                ctx.stroke(strap, with: .color(Theme.ink.opacity(0.35)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: pivot.x - 9, y: pivot.y - 16, width: 18, height: 18)),
                     with: .color(Color(hex: "c3c9d6")))
            ctx.stroke(Path(ellipseIn: CGRect(x: pivot.x - 9, y: pivot.y - 16, width: 18, height: 18)),
                       with: .color(Theme.ink.opacity(0.5)), lineWidth: 2)
        }
        .allowsHitTesting(false)
    }
}

// Bars from the player id, like the code on a hall ticket.
private struct Barcode: View {
    let seed: String

    var body: some View {
        Canvas { ctx, size in
            var h: UInt64 = 1_469_598_103_934_665_603
            var x: CGFloat = 0
            for byte in seed.utf8.cycled(to: 48) {
                h = (h ^ UInt64(byte)) &* 1_099_511_628_211
                let w = CGFloat(1 + h % 3)
                if x + w > size.width { break }
                if h % 5 != 0 { ctx.fill(Path(CGRect(x: x, y: 0, width: w, height: size.height)), with: .color(Theme.ink)) }
                x += w + CGFloat(1 + (h >> 7) % 2)
            }
        }
        .accessibilityHidden(true)
    }
}

private extension String.UTF8View {
    func cycled(to count: Int) -> [UInt8] {
        let bytes = Array(self)
        guard !bytes.isEmpty else { return [] }
        return (0..<count).map { bytes[$0 % bytes.count] }
    }
}

// A holographic seal whose rainbow turns as the card moves.
private struct Hologram: View {
    let phase: Double

    var body: some View {
        ZStack {
            Circle().fill(AngularGradient(colors: [Theme.lime, Theme.cyan, Theme.violet, Theme.redSoft, Theme.orange, Theme.lime],
                                          center: .center, angle: .radians(phase)))
            Circle().fill(RadialGradient(colors: [.white.opacity(0.7), .clear], center: UnitPoint(x: 0.35 + 0.1 * sin(phase), y: 0.3),
                                         startRadius: 0, endRadius: 22))
            Mark(size: 22).opacity(0.85)
        }
        .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5))
        .accessibilityHidden(true)
    }
}

// A rubber stamp, slammed on when the card appears.
private struct Stamp: View {
    let text: String
    let color: Color
    @State private var landed = false

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .black).width(.expanded))
            .tracking(2)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(color, lineWidth: 2.5))
            .padding(2)
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(color.opacity(0.7), lineWidth: 1))
            .opacity(landed ? 0.85 : 0)
            .scaleEffect(landed ? 1 : 2.4)
            .rotationEffect(.degrees(-14))
            .onAppear {
                withAnimation(.timingCurve(0.34, 1.56, 0.64, 1, duration: 0.45).delay(0.6)) { landed = true }
            }
    }
}
