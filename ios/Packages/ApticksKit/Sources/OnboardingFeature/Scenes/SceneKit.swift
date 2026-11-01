import DesignSystem
import SwiftUI
import Tiko
import UIKit

// The pieces every onboarding scene is built from. A scene is a pure
// function of its time t (seconds since its page came up), so it can
// restart on every visit, and with Reduce Motion it simply shows its last
// frame.

// Runs a scene's clock from `start` until `length` seconds have passed.
struct SceneTimeline<Content: View>: View {
    let start: Date?
    let length: Double
    @ViewBuilder let content: (Double) -> Content
    @State private var finished = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: start == nil || finished || reduceMotion)) { tl in
            content(time(tl.date))
        }
        .task(id: start) {
            finished = false
            guard let start else { return }
            let left = length - Date().timeIntervalSince(start)
            if left > 0 { try? await Task.sleep(for: .seconds(left)) }
            if !Task.isCancelled { finished = true }
        }
    }

    private func time(_ now: Date) -> Double {
        if reduceMotion { return 1_000 }
        guard let start else { return 0 }
        return max(0, finished ? max(length, now.timeIntervalSince(start)) : now.timeIntervalSince(start))
    }
}

// Where Tiko is and how it looks at one instant.
struct TikoPose {
    var feet: CGPoint
    var mood: TikoMood
    var still = true // no idle hopping while a scene moves Tiko
    var sx = 1.0
    var sy = 1.0
    var rotation = 0.0 // degrees, about the middle of the body

    // Standing on a hop's path at time t.
    static func on(_ hop: TikoHop, at t: Double, mood: TikoMood) -> TikoPose {
        let v = hop.values(at: t)
        return TikoPose(feet: CGPoint(x: v[0], y: v[1]), mood: mood, still: true, sx: v[2], sy: v[3])
    }
}

struct TikoActor: View {
    let pose: TikoPose
    let size: CGFloat
    var play: TikoPlay?

    var body: some View {
        let height = TikoView.height(for: size)
        TikoView(mood: pose.mood, size: size, still: pose.still, play: play)
            .scaleEffect(x: pose.sx, y: pose.sy, anchor: .bottom)
            .rotationEffect(.degrees(pose.rotation))
            .position(x: pose.feet.x, y: pose.feet.y - height / 2)
    }
}

// Squash and rebound after touching down at `landed`: [scaleX, scaleY].
enum Landing {
    private static let track = Track(frames: [
        KF(0, [1.2, 0.78], .easeOut), KF(0.32, [0.93, 1.08], .easeInOut), KF(0.68, [1.03, 0.98], .easeInOut), KF(1, [1, 1]),
    ])

    static func squash(_ t: Double, landed: Double, length: Double = 0.34) -> (Double, Double) {
        let k = t - landed
        guard k >= 0, k < length else { return (1, 1) }
        let v = track.at(k / length)
        return (v[0], v[1])
    }
}

// Little puffs kicked up on landing.
struct Dust: View {
    let t: Double // since landing
    let at: CGPoint

    var body: some View {
        Canvas { ctx, _ in
            guard t >= 0, t < 0.5 else { return }
            let k = Ease.easeOut(t / 0.5)
            for side in [-1.0, 1.0] {
                for i in 0..<3 {
                    let r = 3 + 7 * k + Double(i)
                    let x = at.x + side * (10 + Double(i) * 9 + 34 * k)
                    let y = at.y - 3 - Double(i) * 2 - 6 * k
                    var c = ctx
                    c.opacity = 0.55 * (1 - k)
                    c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(Theme.soft))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// A burst of confetti thrown up from a point, falling under gravity.
struct Burst: View {
    let t: Double // since the burst
    let at: CGPoint
    var count = 26
    var power = 1.0

    private static let colors = [Theme.lime, Theme.orange, Theme.violet, Theme.redSoft, Theme.text, Theme.cyan]

    var body: some View {
        Canvas { ctx, _ in
            guard t >= 0, t < 1.7 else { return }
            for i in 0..<count {
                let angle = (-165 + 150 * Double(i) / Double(count - 1) + Double((i * 37) % 11) - 5) * .pi / 180
                let speed = (260 + Double((i * 73) % 240)) * power
                let x = at.x + cos(angle) * speed * t
                let y = at.y + sin(angle) * speed * t + 0.5 * 1_250 * t * t
                var c = ctx
                c.opacity = t < 1.1 ? 1 : max(0, 1 - (t - 1.1) / 0.6)
                c.translateBy(x: x, y: y)
                c.rotate(by: .degrees(Double((i * 97) % 360) + t * Double(240 + (i * 53) % 400)))
                let w: CGFloat = i % 3 == 0 ? 5 : 8
                let h: CGFloat = i % 3 == 0 ? 12 : 8
                c.fill(Path(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), cornerRadius: 1.5),
                       with: .color(Self.colors[i % Self.colors.count]))
            }
        }
        .allowsHitTesting(false)
    }
}

// A small speech bubble above a point.
struct Speech: View {
    let text: String
    var tone = Theme.text

    var body: some View {
        Text(text)
            .font(.ui(13, .heavy))
            .foregroundStyle(tone)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1.5))
            .fixedSize()
    }
}

// Haptic taps at set moments in a scene: landings, catches, stamps.
struct SceneHaptics: ViewModifier {
    let start: Date?
    let beats: [(Double, UIImpactFeedbackGenerator.FeedbackStyle)]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.task(id: start) {
            guard let start, !reduceMotion else { return }
            for (time, style) in beats.sorted(by: { $0.0 < $1.0 }) {
                let wait = time - Date().timeIntervalSince(start)
                if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
                if Task.isCancelled { return }
                UIImpactFeedbackGenerator(style: style).impactOccurred()
            }
        }
    }
}

extension View {
    func sceneHaptics(_ start: Date?, _ beats: [(Double, UIImpactFeedbackGenerator.FeedbackStyle)]) -> some View {
        modifier(SceneHaptics(start: start, beats: beats))
    }
}

// 0 → 1 between two times, eased.
func phase(_ t: Double, _ from: Double, _ to: Double, _ ease: Ease = .easeInOut) -> Double {
    ease(min(1, max(0, (t - from) / (to - from))))
}

func lerp(_ a: CGFloat, _ b: CGFloat, _ k: Double) -> CGFloat { a + (b - a) * k }
