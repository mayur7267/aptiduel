import SwiftUI

// Arcade press: pushes into its shadow when tapped.
public struct PressableStyle: ButtonStyle {
    var fill: Color
    var foreground: Color
    var pop: Color
    var border: Color?
    var radius: CGFloat
    var height: CGFloat?
    var fullWidth: Bool

    public init(fill: Color, foreground: Color, pop: Color = Theme.pop, border: Color? = nil, radius: CGFloat = 14,
                height: CGFloat? = 48, fullWidth: Bool = true) {
        self.fill = fill
        self.foreground = foreground
        self.pop = pop
        self.border = border
        self.radius = radius
        self.height = height
        self.fullWidth = fullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        configuration.label
            .font(.ui(15, .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: height)
            .background(shape.fill(fill))
            .overlay { if let border { shape.strokeBorder(border, lineWidth: 1) } }
            .offset(x: pressed ? 3 : 0, y: pressed ? 3 : 0)
            .background(shape.fill(pop).offset(x: 4, y: 4))
            .animation(.easeOut(duration: 0.12), value: pressed)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: pressed) { _, now in now }
    }
}

// A whole card as one button: it pushes into its sticker shadow when tapped.
public struct CardPressStyle: ButtonStyle {
    var radius: CGFloat
    var pop: Color

    public init(radius: CGFloat = 22, pop: Color = Theme.pop) {
        self.radius = radius
        self.pop = pop
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .offset(x: pressed ? 3 : 0, y: pressed ? 3 : 0)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(pop).offset(x: 4, y: 4))
            .animation(.easeOut(duration: 0.12), value: pressed)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: pressed) { _, now in now }
    }
}

// Plain filled buttons, for actions that don't need the arcade press.
public struct FilledStyle: ButtonStyle {
    var fill: Color
    var foreground: Color
    var border: Color?
    var radius: CGFloat
    var height: CGFloat

    public init(fill: Color, foreground: Color, border: Color? = nil, radius: CGFloat = 16, height: CGFloat = 48) {
        self.fill = fill
        self.foreground = foreground
        self.border = border
        self.radius = radius
        self.height = height
    }

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        configuration.label
            .font(.ui(15, .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .frame(minHeight: height)
            .background(shape.fill(fill))
            .overlay { if let border { shape.strokeBorder(border, lineWidth: 1) } }
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FilledStyle {
    public static var lime: FilledStyle { FilledStyle(fill: Theme.lime, foreground: Theme.ink) }
    public static var secondary: FilledStyle { FilledStyle(fill: Theme.raised, foreground: Theme.text) }
    public static var outline: FilledStyle { FilledStyle(fill: Theme.surface, foreground: Theme.text, border: Theme.line) }
}
