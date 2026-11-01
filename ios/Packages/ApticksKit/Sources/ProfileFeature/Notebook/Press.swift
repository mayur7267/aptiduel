import DesignSystem
import SwiftUI

// Rows and notes give under the finger: a springy press and a light tap.
struct Press: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: configuration.isPressed) { _, now in now }
    }
}

// A red-pen remark, slightly askew.
struct RedPen: View {
    let text: String
    var size: CGFloat = 16
    var tilt: Double = -3

    var body: some View {
        Text(text)
            .font(.hand(size))
            .foregroundStyle(Theme.redSoft)
            .rotationEffect(.degrees(tilt))
    }
}
