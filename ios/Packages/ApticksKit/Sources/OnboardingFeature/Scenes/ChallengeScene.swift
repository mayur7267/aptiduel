import DesignSystem
import SwiftUI
import Tiko

// Challenges: Tiko hops in and points, your link flies along an arc to a
// friend, their "?" flips over to show they've accepted, and a VS stamp
// slams down between you.
struct ChallengeScene: View {
    let start: Date?
    private let size: CGFloat = 66

    private enum T {
        static let fly = 0.95
        static let arrive = 1.85
        static let stamp = 2.45
        static let done = 4.5
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let you = CGPoint(x: w * 0.2, y: h * 0.38)
            let friend = CGPoint(x: w * 0.8, y: h * 0.38)
            let ground = h * 0.9
            let hopIn = TikoHop(from: CGPoint(x: -50, y: ground), to: CGPoint(x: w * 0.5, y: ground), start: 0.1, height: 90)
            let control = CGPoint(x: w * 0.5, y: h * 0.02)

            SceneTimeline(start: start, length: T.done) { t in
                let k = phase(t, T.fly, T.arrive)
                ZStack {
                    // The link's trail.
                    Path { p in
                        p.move(to: CGPoint(x: you.x, y: you.y - 44))
                        p.addQuadCurve(to: CGPoint(x: friend.x, y: friend.y - 44), control: control)
                    }
                    .trim(from: 0, to: k)
                    .stroke(Theme.lime.opacity(0.55), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [6, 7]))

                    player(Avatar(name: "Player You", size: 64), at: you, label: "You", ring: Theme.lime)
                    friendSide(t: t, at: friend)

                    if t > T.fly && t < T.arrive + 0.1 {
                        let p = bezier(CGPoint(x: you.x, y: you.y - 44), control, CGPoint(x: friend.x, y: friend.y - 44), k)
                        let tangent = bezier(CGPoint(x: you.x, y: you.y - 44), control, CGPoint(x: friend.x, y: friend.y - 44), min(1, k + 0.02))
                        linkChip
                            .rotationEffect(.radians(atan2(tangent.y - p.y, tangent.x - p.x) * 0.5))
                            .scaleEffect(0.8 + 0.3 * sin(k * .pi))
                            .position(p)
                    }

                    // VS, slammed on like a stamp.
                    if t > T.stamp {
                        let s = phase(t, T.stamp, T.stamp + 0.35, .bezier(0.34, 1.56, 0.64, 1))
                        Text("VS")
                            .font(.display(26))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.orange))
                            .sticker(10, pop: Color(hex: "6b3415"))
                            .rotationEffect(.degrees(-8))
                            .scaleEffect(2.2 - 1.2 * s)
                            .opacity(min(1, s * 3))
                            .position(x: w * 0.5, y: you.y)
                    }
                    Burst(t: t - T.stamp - 0.25, at: CGPoint(x: w * 0.5, y: you.y), count: 24, power: 0.9)

                    TikoActor(pose: pose(t, hopIn), size: size, play: t > T.stamp + 0.2 ? TikoPlay(move: .boing, key: 1) : nil)
                }
                .frame(width: w, height: h)
            }
            .sceneHaptics(start, [(hopIn.touchdown, .light), (T.arrive, .soft), (T.stamp + 0.3, .heavy)])
        }
    }

    private func pose(_ t: Double, _ hop: TikoHop) -> TikoPose {
        if t < hop.end { return .on(hop, at: t, mood: .happy) }
        if t < T.stamp + 0.2 { return TikoPose(feet: hop.to, mood: .point) }
        return TikoPose(feet: hop.to, mood: .cheer, still: false)
    }

    private var linkChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "link").font(.system(size: 12, weight: .bold))
            Text("apticks.app/c/K3Q9").font(.mono(11, .semibold))
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.lime))
        .shadow(color: Theme.lime.opacity(0.45), radius: 10)
        .fixedSize()
    }

    private func player(_ avatar: some View, at p: CGPoint, label: String, ring: Color) -> some View {
        VStack(spacing: 6) {
            avatar.padding(3).background(Circle().fill(Theme.ink)).padding(3).background(Circle().fill(ring))
            Text(label).font(.ui(13, .bold)).foregroundStyle(Theme.text)
        }
        .position(x: p.x, y: p.y + 14)
    }

    // The friend's side turns over like a card when the link lands.
    private func friendSide(t: Double, at p: CGPoint) -> some View {
        let flip = phase(t, T.arrive, T.arrive + 0.4)
        let revealed = flip > 0.5
        let face = Group {
            if revealed {
                Avatar(name: "Riya Kapoor", size: 64)
            } else {
                Text("?")
                    .font(.display(24))
                    .foregroundStyle(Theme.orange)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Theme.orangeTint))
                    .overlay(Circle().strokeBorder(Theme.orange.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
            }
        }
        return ZStack(alignment: .bottom) {
            player(face.scaleEffect(x: abs(cos(flip * .pi)), y: 1), at: p, label: revealed ? "Riya" : "Friend", ring: revealed ? Theme.orange : Theme.line)
            if t > T.arrive + 0.35 {
                Label("Accepted", systemImage: "checkmark")
                    .font(.ui(11, .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.lime))
                    .scaleEffect(0.6 + 0.4 * phase(t, T.arrive + 0.35, T.arrive + 0.7, .bezier(0.34, 1.56, 0.64, 1)))
                    .position(x: p.x, y: p.y + 58)
            }
        }
    }

    private func bezier(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ k: Double) -> CGPoint {
        let u = 1 - k
        return CGPoint(x: u * u * a.x + 2 * u * k * c.x + k * k * b.x, y: u * u * a.y + 2 * u * k * c.y + k * k * b.y)
    }
}
