import CoreGraphics
import DesignSystem
import Foundation

// A hop along a real arc: constant sideways speed, a parabola up and down,
// a crouch before take-off and a squash on landing. Points are wherever the
// caller anchors Tiko (its feet, or its top-left corner); times are seconds
// on the caller's clock.
public struct TikoHop: Sendable {
    public let start: Double
    public let duration: Double
    public let to: CGPoint
    private let track: Track

    public init(from: CGPoint, to: CGPoint, start: Double = 0, height: CGFloat? = nil, duration: Double? = nil) {
        let dist = hypot(to.x - from.x, to.y - from.y)
        let height = height ?? min(160, 50 + dist * 0.22)
        var frames = [KF(0, [from.x, from.y, 1, 1]), KF(0.12, [from.x, from.y, 1.12, 0.86])]
        let n = 14
        for i in 1..<n {
            let t = Double(i) / Double(n)
            let x = from.x + (to.x - from.x) * t
            let y = from.y + (to.y - from.y) * t - height * 4 * t * (1 - t)
            frames.append(KF(0.12 + 0.7 * t, [x, y, t < 0.5 ? 0.93 : 0.96, t < 0.5 ? 1.08 : 1.05]))
        }
        frames.append(KF(0.88, [to.x, to.y, 1.14, 0.84]))
        frames.append(KF(0.95, [to.x, to.y, 0.97, 1.03]))
        frames.append(KF(1, [to.x, to.y, 1, 1]))
        track = Track(frames: frames)
        self.start = start
        self.to = to
        self.duration = duration ?? min(1.1, 0.56 + dist * 0.00045)
    }

    public var end: Double { start + duration }
    // Feet touch down a little before the end (the rest is the squash).
    public var touchdown: Double { start + duration * 0.86 }

    // [x, y, scaleX, scaleY] at time t.
    public func values(at t: Double) -> [Double] {
        track.at(min(1, max(0, (t - start) / duration)))
    }
}
