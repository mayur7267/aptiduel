import DesignSystem
import Domain
import SwiftUI

// "You vs ?" shows what a challenge is before reading any text.
struct VersusBadge: View {
    let name: String
    var body: some View {
        HStack(spacing: -8) {
            Avatar(name: name, size: 42).overlay(Circle().strokeBorder(Theme.surface, lineWidth: 3))
            Text("VS")
                .font(.display(11))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.orange))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.surface, lineWidth: 3))
                .rotationEffect(.degrees(-6))
                .zIndex(1)
            Text("?")
                .font(.display(16))
                .foregroundStyle(Theme.orange)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Theme.orangeTint))
                .overlay(Circle().strokeBorder(Theme.orange.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
        }
        .accessibilityHidden(true)
    }
}

struct ChallengeCard: View {
    let me: Me
    let latest: DuelSummary?
    let busy: HomeAction?
    let onStart: () -> Void
    let onPlay: (String) -> Void

    private var orangeButton: PressableStyle {
        PressableStyle(fill: Theme.orangeTint, foreground: Theme.orange, pop: Color(hex: "6b3415"), border: Theme.orange.opacity(0.4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VersusBadge(name: me.name)
                Spacer()
                Label("LIVE", systemImage: "circle.fill")
                    .labelStyle(LiveTag())
                    .font(.mono(11))
                    .tracking(1.2)
                    .foregroundStyle(Theme.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.orange.opacity(0.4)))
                    .rotationEffect(.degrees(3))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Duel a friend").font(.display(20)).foregroundStyle(Theme.text)
                Text("Send a link. When your friend joins, you race through the same 5 questions, starting together, and see each other's progress live.")
                    .font(.ui(14)).foregroundStyle(Theme.muted)
            }
            VStack(alignment: .leading, spacing: 10) {
                Button("Start a live duel", action: onStart)
                    .buttonStyle(orangeButton)
                    .disabled(busy != nil)
                // A challenge from before, or one a friend didn't join live.
                if let latest, !latest.finished {
                    Button { onPlay(latest.id) } label: {
                        HStack(spacing: 4) { Text("Play your turn in your last challenge"); Image(systemName: "chevron.right") }
                    }
                    .font(.ui(14, .semibold))
                    .foregroundStyle(Theme.lime)
                }
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Theme.surface
                RadialGradient(colors: [Theme.orange.opacity(0.18), .clear], center: .topTrailing, startRadius: 0, endRadius: 240)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.orange.opacity(0.35), lineWidth: 2))
        .sticker(22, pop: Color(hex: "4a2612"))
    }
}

// A pulsing dot before the label.
private struct LiveTag: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.font(.system(size: 6)).symbolEffect(.pulse)
            configuration.title
        }
    }
}
