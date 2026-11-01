import Foundation

// CSS-style keyframe tracks, so motion matches the website exactly:
// each keyframe carries the timing function for the segment that starts
// at it (rising eases out as gravity slows it, falling eases in).

public nonisolated enum Ease: Sendable {
    case linear, ease, easeIn, easeOut, easeInOut
    case bezier(Double, Double, Double, Double)

    public static let rise = Ease.bezier(0.25, 0.46, 0.45, 0.94)
    public static let fall = Ease.bezier(0.55, 0.085, 0.68, 0.53)

    public func callAsFunction(_ x: Double) -> Double {
        switch self {
        case .linear: x
        case .ease: Self.cubic(0.25, 0.1, 0.25, 1, x)
        case .easeIn: Self.cubic(0.42, 0, 1, 1, x)
        case .easeOut: Self.cubic(0, 0, 0.58, 1, x)
        case .easeInOut: Self.cubic(0.42, 0, 0.58, 1, x)
        case let .bezier(a, b, c, d): Self.cubic(a, b, c, d, x)
        }
    }

    // y for a given x on a CSS cubic-bezier(x1, y1, x2, y2).
    private static func cubic(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ x: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        func bx(_ t: Double) -> Double { 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t }
        func by(_ t: Double) -> Double { 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t }
        func dx(_ t: Double) -> Double { 3 * (1 - t) * (1 - t) * x1 + 6 * (1 - t) * t * (x2 - x1) + 3 * t * t * (1 - x2) }
        var t = x
        for _ in 0..<6 {
            let err = bx(t) - x
            if abs(err) < 1e-5 { return by(t) }
            let d = dx(t)
            if abs(d) < 1e-6 { break }
            t -= err / d
        }
        var lo = 0.0, hi = 1.0
        t = x
        for _ in 0..<30 {
            let v = bx(t)
            if abs(v - x) < 1e-5 { break }
            if v < x { lo = t } else { hi = t }
            t = (lo + hi) / 2
        }
        return by(t)
    }
}

public nonisolated struct KF: Sendable {
    public let at: Double
    public let v: [Double]
    public let ease: Ease
    public init(_ at: Double, _ v: [Double], _ ease: Ease = .linear) {
        self.at = at
        self.v = v
        self.ease = ease
    }
}

public nonisolated struct Track: Sendable {
    public let frames: [KF]

    public init(frames: [KF]) { self.frames = frames }

    // Values at progress p (0...1).
    public func at(_ p: Double) -> [Double] {
        guard let first = frames.first, let last = frames.last else { return [] }
        if p <= first.at { return first.v }
        if p >= last.at { return last.v }
        var i = 0
        while i < frames.count - 2 && p > frames[i + 1].at { i += 1 }
        let a = frames[i], b = frames[i + 1]
        let k = a.ease((p - a.at) / max(b.at - a.at, 1e-9))
        return zip(a.v, b.v).map { $0 + ($1 - $0) * k }
    }

    // A looping track with a period in seconds.
    public func loop(_ t: Double, period: Double) -> [Double] {
        at((t / period).truncatingRemainder(dividingBy: 1))
    }
}
