import DesignSystem
import Foundation

// Idle motion, from globals.css. Values are [translateY, scaleX, scaleY]
// in Tiko's 120-unit drawing, around the feet (60, 115).
nonisolated enum Idle {
    static let hop = Track(frames: [
        KF(0, [0, 1, 1], .easeInOut),
        KF(0.05, [0, 1.1, 0.88], .rise),
        KF(0.15, [-16, 0.97, 1.05], .fall),
        KF(0.24, [0, 0.94, 1.08], .easeOut),
        KF(0.28, [0, 1.12, 0.86], .easeOut),
        KF(0.33, [0, 0.98, 1.02], .easeOut),
        KF(0.38, [0, 1, 1], .ease),
        KF(1, [0, 1, 1]),
    ])
    static let bounce = Track(frames: [
        KF(0, [0, 1.1, 0.88], .rise),
        KF(0.40, [-14, 0.96, 1.06], .fall),
        KF(0.78, [0, 0.95, 1.06], .easeOut),
        KF(0.88, [0, 1.12, 0.86], .easeOut),
        KF(1, [0, 1.1, 0.88]),
    ])
    static let breathe = Track(frames: [
        KF(0, [0, 1, 1], .easeInOut),
        KF(0.5, [0, 1.03, 0.97], .easeInOut),
        KF(1, [0, 1, 1]),
    ])
    static let blink = Track(frames: [KF(0, [1], .ease), KF(0.93, [1], .ease), KF(0.96, [0.1], .ease), KF(1, [1])])
    static let antenna = Track(frames: [KF(0, [-6], .easeInOut), KF(0.5, [7], .easeInOut), KF(1, [-6])])
    static let wave = Track(frames: [KF(0, [0], .easeInOut), KF(0.5, [-24], .easeInOut), KF(1, [0])])
    static let float = Track(frames: [KF(0, [0, 1], .easeInOut), KF(0.5, [-5, 0.7], .easeInOut), KF(1, [0, 1])])
}

// Whole-body moves, from tiko.tsx: [translateY (fraction of height),
// rotation in degrees, scaleX, scaleY], around the bottom centre.
// Crouch, launch (slowing as it rises), fall (speeding up), squash on
// landing, rebound.
nonisolated enum Moves {
    static func track(_ move: TikoMove) -> (track: Track, duration: Double) {
        switch move {
        case .boing:
            (Track(frames: [
                KF(0, [0, 0, 1, 1], .easeOut),
                KF(0.14, [0, 0, 1.18, 0.78], .rise),
                KF(0.42, [-0.46, 0, 0.9, 1.14], .fall),
                KF(0.70, [0, 0, 0.92, 1.1], .easeOut),
                KF(0.80, [0, 0, 1.2, 0.8], .easeOut),
                KF(0.90, [0, 0, 0.96, 1.04]),
                KF(1, [0, 0, 1, 1]),
            ]), 0.82)
        case .flip:
            (Track(frames: [
                KF(0, [0, 0, 1, 1], .easeOut),
                KF(0.12, [0, 0, 1.15, 0.82], .rise),
                KF(0.42, [-0.52, -180, 1, 1], .fall),
                KF(0.72, [0, -360, 0.94, 1.08], .easeOut),
                KF(0.82, [0, -360, 1.16, 0.84], .easeOut),
                KF(1, [0, -360, 1, 1]),
            ]), 0.95)
        // A wrong answer: sag down, shake the head, perk back up.
        case .droop:
            (Track(frames: [
                KF(0, [0, 0, 1, 1], .easeOut),
                KF(0.25, [0.06, 0, 1.08, 0.88]),
                KF(0.45, [0.04, -6, 1.04, 0.92]),
                KF(0.65, [0.04, 6, 1.04, 0.92]),
                KF(0.82, [0.02, -2, 1.02, 0.97]),
                KF(1, [0, 0, 1, 1]),
            ]), 0.9)
        case .giggle:
            (Track(frames: [
                KF(0, [0, 0, 1, 1]),
                KF(0.15, [0, -10, 1.06, 0.94]),
                KF(0.32, [0, 9, 0.96, 1.04]),
                KF(0.50, [0, -7, 1.04, 0.96]),
                KF(0.68, [0, 5, 0.98, 1.02]),
                KF(0.85, [0, -2, 1, 1]),
                KF(1, [0, 0, 1, 1]),
            ]), 0.72)
        }
    }
}
