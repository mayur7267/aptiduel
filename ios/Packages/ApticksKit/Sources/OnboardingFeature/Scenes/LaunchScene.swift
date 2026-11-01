import DesignSystem
import SwiftUI
import Tiko

// Ready: Tiko crouches on a launch pad, rockets off the top of the screen
// trailing stars, and falls back down for a confetti landing. One real
// ballistic arc; the stretch follows its speed, the squash its landing.
struct LaunchScene: View {
    let start: Date?
    private let size: CGFloat = 96

    private enum T {
        static let crouch = 0.35
        static let launch = 0.8
        static let speed = 1_750.0 // pt/s up
        static let g = 2_600.0
        static var land: Double { launch + 2 * speed / g }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pad = CGPoint(x: w / 2, y: h * 0.86)

            SceneTimeline(start: start, length: T.land + 1.8) { t in
                ZStack {
                    // The pad, glowing as it charges.
                    let charge = phase(t, T.crouch, T.launch) * (t < T.launch + 0.2 ? 1 : max(0, 1 - (t - T.launch - 0.2) * 2))
                    Capsule()
                        .fill(Theme.lime.opacity(0.25 + 0.5 * charge))
                        .frame(width: size * 1.6, height: 14)
                        .blur(radius: 8 * charge)
                        .position(x: pad.x, y: pad.y + 7)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.lime, lineWidth: 2))
                        .frame(width: size * 1.4, height: 16)
                        .sticker(8, pop: Theme.limePop)
                        .position(x: pad.x, y: pad.y + 8)

                    Canvas { ctx, _ in trail(ctx, t: t, pad: pad) }
                    Dust(t: t - T.land, at: pad)
                    Burst(t: t - T.land - 0.05, at: CGPoint(x: pad.x, y: pad.y - 40), count: 34, power: 1.15)
                    TikoActor(pose: pose(t, pad: pad), size: size, play: t > T.land + 0.3 ? TikoPlay(move: .boing, key: 1) : nil)
                }
                .frame(width: w, height: h)
            }
            .sceneHaptics(start, [(T.launch, .rigid), (T.land, .heavy)])
        }
    }

    private func pose(_ t: Double, pad: CGPoint) -> TikoPose {
        if t < T.crouch { return TikoPose(feet: pad, mood: .happy, still: false) }
        if t < T.launch {
            // Anticipation: a deep squat.
            let k = phase(t, T.crouch, T.launch, .easeIn)
            return TikoPose(feet: pad, mood: .think, sx: 1 + 0.2 * k, sy: 1 - 0.28 * k)
        }
        if t < T.land {
            let tau = t - T.launch
            let v = T.speed - T.g * tau
            let y = pad.y - T.speed * tau + 0.5 * T.g * tau * tau
            // Stretch with speed (keeping volume), snapping out of the squat.
            let stretch = 1 + 0.3 * abs(v) / T.speed
            let unsquat = min(1, tau / 0.06)
            let sy = 0.72 + (stretch - 0.72) * unsquat
            return TikoPose(feet: CGPoint(x: pad.x, y: y), mood: .giggle, sx: 1 / sqrt(sy), sy: sy, rotation: 360 * phase(tau, 0.25, 1.1))
        }
        let (sx, sy) = Landing.squash(t, landed: T.land, length: 0.42)
        return TikoPose(feet: pad, mood: .cheer, still: t < T.land + 0.45, sx: sx, sy: sy)
    }

    // Stars shed from Tiko's feet on the way up, drifting and fading.
    private func trail(_ ctx: GraphicsContext, t: Double, pad: CGPoint) {
        let star = SVGPath.path("M10 0 L12.6 7.4 L20 10 L12.6 12.6 L10 20 L7.4 12.6 L0 10 L7.4 7.4 Z")
        let colors = [Theme.lime, Theme.orange, Theme.violet, Theme.text]
        for j in 0..<14 {
            let born = T.launch + Double(j) * 0.028
            let age = t - born
            guard age >= 0, age < 0.7 else { continue }
            let tau = born - T.launch
            let y = pad.y - T.speed * tau + 0.5 * T.g * tau * tau
            let drift = Double((j * 37) % 30) - 15
            var c = ctx
            c.opacity = 1 - age / 0.7
            c.translateBy(x: pad.x + drift * (1 + age * 2), y: y + 40 * age)
            c.rotate(by: .degrees(age * 300))
            let s = 0.6 + 0.5 * (1 - age / 0.7)
            c.scaleBy(x: s, y: s)
            c.translateBy(x: -10, y: -10)
            c.fill(star, with: .color(colors[j % colors.count]))
        }
    }
}
