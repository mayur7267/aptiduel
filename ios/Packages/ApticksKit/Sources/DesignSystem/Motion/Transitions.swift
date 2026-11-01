import SwiftUI

// Elements that rise into place one after another when a screen opens.
struct Rise: ViewModifier {
    var delay: Double
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.5).delay(delay)) { shown = true }
            }
    }
}

// Scales in with an overshoot, like the website's `pop`.
struct PopIn: ViewModifier {
    var delay: Double
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduceMotion ? 1 : 0.6)
            .opacity(shown || reduceMotion ? 1 : 0)
            .onAppear {
                withAnimation(.timingCurve(0.34, 1.56, 0.64, 1, duration: 0.5).delay(delay)) { shown = true }
            }
    }
}

extension View {
    public func rise(_ delay: Double = 0) -> some View { modifier(Rise(delay: delay)) }
    public func popIn(_ delay: Double = 0) -> some View { modifier(PopIn(delay: delay)) }
}

extension Animation {
    // The website's `pop` overshoot.
    public static let pop = Animation.timingCurve(0.34, 1.56, 0.64, 1, duration: 0.45)
}
