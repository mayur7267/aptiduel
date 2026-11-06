import DesignSystem
import Domain
import SwiftUI

// "You vs ?" shows what a friend duel is before reading any text.
struct VersusBadge: View {
    let name: String
    var size: CGFloat = 42

    var body: some View {
        HStack(spacing: -size * 0.2) {
            Avatar(name: name, size: size).overlay(Circle().strokeBorder(Theme.surface, lineWidth: 3))
            Text("VS")
                .font(.display(size * 0.26))
                .foregroundStyle(Theme.ink)
                .fixedSize()
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.orange))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.surface, lineWidth: 2.5))
                .rotationEffect(.degrees(-6))
                .zIndex(1)
            Text("?")
                .font(.display(size * 0.38))
                .foregroundStyle(Theme.orange)
                .frame(width: size, height: size)
                .background(Circle().fill(Theme.orangeTint))
                .overlay(Circle().strokeBorder(Theme.orange.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
        }
        .accessibilityHidden(true)
    }
}

// A live duel with a friend: tapping opens the room and its link.
struct FriendTile: View {
    let me: Me
    let busy: HomeAction?
    let onStart: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        Button(action: onStart) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 4) {
                    VersusBadge(name: me.name, size: 32)
                    Spacer(minLength: 0)
                    Label("LIVE", systemImage: "circle.fill")
                        .labelStyle(LiveTag())
                        .font(.mono(10))
                        .tracking(1)
                        .foregroundStyle(Theme.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.orange.opacity(0.4)))
                        .fixedSize()
                        .rotationEffect(.degrees(3))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Duel a friend").font(.display(15)).foregroundStyle(Theme.text).lineLimit(1).minimumScaleFactor(0.8)
                    Text("Send a link, race live").font(.ui(12)).foregroundStyle(Theme.muted)
                }
                .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                ZStack {
                    Theme.surface
                    RadialGradient(colors: [Theme.orange.opacity(0.2), .clear], center: .topTrailing, startRadius: 0, endRadius: 180)
                }
                .clipShape(shape)
            )
            .overlay(shape.strokeBorder(Theme.orange.opacity(0.35), lineWidth: 2))
            .contentShape(shape)
        }
        .buttonStyle(CardPressStyle(radius: 20, pop: Color(hex: "4a2612")))
        .disabled(busy != nil)
        .accessibilityLabel("Duel a friend")
        .accessibilityHint("Starts a live duel and gives you a link to send")
    }
}

// A pulsing dot before the label.
private struct LiveTag: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.font(.system(size: 5)).symbolEffect(.pulse)
            configuration.title
        }
    }
}
