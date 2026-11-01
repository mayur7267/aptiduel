import DesignSystem
import SwiftUI
import Tiko

// Hello: Tiko swings in on a trapeze, lets go at the top of a forward
// swing, backflips through the air and lands on a platform with a squash
// and a puff of dust. The swing is a real damped pendulum, and the flight a
// rigid body thrown with the speed it had when it let go.
struct SwingScene: View {
    let start: Date?
    private let size: CGFloat = 104

    var body: some View {
        GeometryReader { geo in
            let rig = SwingRig.make(for: geo.size, tiko: size)
            SceneTimeline(start: start, length: rig.landAt + 1.2) { t in
                ZStack {
                    Canvas { ctx, _ in rig.drawRig(ctx, at: t) }
                    // The platform Tiko lands on.
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Theme.lime)
                        .frame(width: size * 1.35, height: 18)
                        .sticker(9, pop: Theme.limePop)
                        .position(x: rig.landFeet.x, y: rig.ground + 9)
                    Dust(t: t - rig.landAt, at: rig.landFeet)
                    TikoActor(pose: rig.pose(at: t), size: size)
                    if t > rig.hold + 0.25 && t < rig.releaseAt {
                        let p = rig.pose(at: t).feet
                        let side: CGFloat = p.x > geo.size.width * 0.55 ? -1 : 1
                        Speech(text: "Wheee!", tone: Theme.lime)
                            .position(x: p.x + side * size * 0.75, y: p.y - size * 1.25)
                            .transition(.scale)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .sceneHaptics(start, [(rig.releaseAt, .light), (rig.landAt, .medium)])
        }
    }
}

@MainActor
struct SwingRig {
    let anchor: CGPoint
    let length: CGFloat
    let ground: CGFloat
    let tiko: CGFloat
    let hold = 0.2 // a beat before the swing starts
    let releaseAt: Double
    let landAt: Double
    let landFeet: CGPoint

    private let swing: [Double] // rope angle, 120 a second, until release
    private let after: [Double] // the empty trapeze swinging on
    private let launch: CGPoint // body centre at release
    private let velocity: CGVector
    private let spinFrom: Double // degrees
    private let flightTime: Double

    private static let rate = 120.0
    private static let g = 2_600.0
    private static var cache: [String: SwingRig] = [:]

    static func make(for size: CGSize, tiko: CGFloat) -> SwingRig {
        let key = "\(Int(size.width))x\(Int(size.height))"
        if let hit = cache[key] { return hit }
        let rig = SwingRig(size: size, tiko: tiko)
        cache[key] = rig
        return rig
    }

    private var tikoHeight: CGFloat { TikoView.height(for: tiko) }
    // Hands (arms up, holding the bar) to the middle of the body, upright.
    private var handsToCentre: CGFloat { tikoHeight * (62.0 - 46.0) / 124.0 }

    private init(size: CGSize, tiko: CGFloat) {
        let anchor = CGPoint(x: size.width * 0.36, y: -30)
        let length = size.height * 0.5
        let ground = size.height * 0.9
        self.tiko = tiko
        self.anchor = anchor
        self.length = length
        self.ground = ground
        let hold = 0.2
        let tikoHeight = TikoView.height(for: tiko)
        let reach = tikoHeight * (62.0 - 46.0) / 124.0

        // θ'' = −(g/L)·sin θ − c·θ', from far back on the left.
        func simulate(theta: Double, omega: Double, seconds: Double, damping: Double, stopAtRelease: Bool) -> (angles: [Double], omega: Double) {
            var theta = theta
            var omega = omega
            var angles: [Double] = []
            var crossings = 0
            let dt = 1 / (Self.rate * 4)
            var step = 0
            while Double(step) * dt < seconds {
                if step % 4 == 0 { angles.append(theta) }
                let before = theta
                omega += (-(Self.g / Double(length)) * sin(theta) - damping * omega) * dt
                theta += omega * dt
                step += 1
                // Let go the second time it swings up past ~18° going forward.
                if stopAtRelease && before < 0.32 && theta >= 0.32 && omega > 0 {
                    crossings += 1
                    if crossings == 2 {
                        angles.append(theta)
                        return (angles, omega)
                    }
                }
            }
            return (angles, omega)
        }

        let (swing, omega) = simulate(theta: -1.02, omega: 0, seconds: 4, damping: 0.3, stopAtRelease: true)
        self.swing = swing
        let theta = swing.last ?? 0
        let releaseAt = hold + Double(swing.count - 1) / Self.rate
        self.releaseAt = releaseAt
        after = simulate(theta: theta, omega: omega, seconds: 2, damping: 0.9, stopAtRelease: false).angles

        // Where the body was at release and how fast it was going.
        func centre(_ theta: Double) -> CGPoint {
            let bar = CGPoint(x: anchor.x + length * sin(theta), y: anchor.y + length * cos(theta))
            let phi = -theta
            return CGPoint(x: bar.x - reach * sin(phi), y: bar.y + reach * cos(phi))
        }
        let c1 = centre(theta)
        let c0 = centre(swing.count > 1 ? swing[swing.count - 2] : theta)
        launch = c1
        let vy = Double(c1.y - c0.y) * Self.rate
        spinFrom = -theta * 180 / .pi

        // Fall to the ground: ½g·τ² + vy·τ − drop = 0.
        let drop = Double(ground - tikoHeight / 2 - c1.y)
        let tau = (-vy + sqrt(vy * vy + 2 * Self.g * drop)) / Self.g
        flightTime = tau
        // Land on the platform's spot, whatever the screen width.
        let target = size.width * 0.7
        velocity = CGVector(dx: Double(target - c1.x) / tau, dy: vy)
        landAt = releaseAt + tau
        landFeet = CGPoint(x: target, y: ground)
    }

    func pose(at t: Double) -> TikoPose {
        if t < releaseAt {
            let i = min(swing.count - 1, max(0, Int(((t - hold) * Self.rate).rounded())))
            let theta = t < hold ? swing[0] : swing[i]
            let bar = CGPoint(x: anchor.x + length * sin(theta), y: anchor.y + length * cos(theta))
            let phi = -theta
            let centre = CGPoint(x: bar.x - handsToCentre * sin(phi), y: bar.y + handsToCentre * cos(phi))
            return TikoPose(feet: CGPoint(x: centre.x, y: centre.y + tikoHeight / 2), mood: .cheer, rotation: phi * 180 / .pi)
        }
        if t < landAt {
            let tau = t - releaseAt
            let centre = CGPoint(x: launch.x + velocity.dx * tau, y: launch.y + velocity.dy * tau + 0.5 * Self.g * tau * tau)
            // A backflip, finishing upright just before touchdown.
            let spin = spinFrom + (-360 - spinFrom) * Ease.bezier(0.3, 0.6, 0.4, 1)(min(1, tau / (flightTime * 0.92)))
            return TikoPose(feet: CGPoint(x: centre.x, y: centre.y + tikoHeight / 2), mood: .giggle, sx: 0.95, sy: 1.06, rotation: spin)
        }
        let (sx, sy) = Landing.squash(t, landed: landAt)
        return TikoPose(feet: landFeet, mood: t > landAt + 0.35 ? .wave : .cheer, still: t < landAt + 0.4, sx: sx, sy: sy)
    }

    // The ropes and bar, swinging with Tiko and then on their own.
    func drawRig(_ ctx: GraphicsContext, at t: Double) {
        let theta: Double
        var c = ctx
        if t < releaseAt {
            let i = min(swing.count - 1, max(0, Int(((t - hold) * Self.rate).rounded())))
            theta = t < hold ? swing[0] : swing[i]
        } else {
            let i = min(after.count - 1, Int(((t - releaseAt) * Self.rate).rounded()))
            theta = after[max(0, i)]
            c.opacity = max(0, 1 - (t - releaseAt) / 1.1)
        }
        guard c.opacity > 0 else { return }
        let bar = CGPoint(x: anchor.x + length * sin(theta), y: anchor.y + length * cos(theta))
        let half = tiko * 0.42
        let along = CGVector(dx: cos(theta), dy: -sin(theta))
        let left = CGPoint(x: bar.x - along.dx * half, y: bar.y - along.dy * half)
        let right = CGPoint(x: bar.x + along.dx * half, y: bar.y + along.dy * half)
        var ropes = Path()
        ropes.move(to: CGPoint(x: anchor.x - 10, y: anchor.y))
        ropes.addLine(to: left)
        ropes.move(to: CGPoint(x: anchor.x + 10, y: anchor.y))
        ropes.addLine(to: right)
        c.stroke(ropes, with: .color(Theme.soft.opacity(0.75)), lineWidth: 2)
        var stick = Path()
        stick.move(to: left)
        stick.addLine(to: right)
        c.stroke(stick, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        c.stroke(stick, with: .color(Theme.orange), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
    }
}
