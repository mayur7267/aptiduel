import DesignSystem
import Domain
import SwiftUI

// The streak flame's wiggle, from globals.css.
struct Wiggle: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let track = Track(frames: [
        KF(0, [0, 1], .easeInOut), KF(0.7, [0, 1], .easeInOut), KF(0.78, [-12, 1.12], .easeInOut),
        KF(0.86, [10, 1.12], .easeInOut), KF(0.94, [-4, 1.04], .easeInOut), KF(1, [0, 1]),
    ])

    func body(content: Content) -> some View {
        if active && !reduceMotion {
            TimelineView(.animation) { tl in
                let v = Self.track.loop(tl.date.timeIntervalSinceReferenceDate, period: 2.8)
                content.rotationEffect(.degrees(v[0])).scaleEffect(v[1])
            }
        } else {
            content
        }
    }
}
