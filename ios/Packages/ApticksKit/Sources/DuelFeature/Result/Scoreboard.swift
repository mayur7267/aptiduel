import DesignSystem
import Domain
import SwiftUI
import Tiko

// Final scores side by side, with the winner called out.
struct Scoreboard: View {
    let me: Player
    let opp: Player
    let outcome: DuelOutcome
    var onOpponent: ((String) -> Void)? // opens their profile

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ScoreSide(player: me, label: "You", outcome: outcome)
            Text("VS").font(.display(12)).foregroundStyle(Theme.soft)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.raised))
                .rotationEffect(.degrees(-6))
            ScoreSide(player: opp, label: nil, outcome: outcome.flipped)
                .onTapGesture { if let id = opp.id, !opp.isBot { onOpponent?(id) } }
                .accessibilityAddTraits(opp.id != nil && !opp.isBot ? .isButton : [])
                .accessibilityHint(opp.id != nil && !opp.isBot ? "Opens their profile" : "")
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .card(20)
        .sticker(20)
    }
}

// A rubber stamp, slammed on at an angle.
struct Stamp: View {
    let text: String
    let color: Color
    let tilt: Double
    @State private var landed = false

    var body: some View {
        Text(text)
            .font(.display(10))
            .tracking(1.5)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(color, lineWidth: 3))
            .opacity(landed ? 0.9 : 0)
            .scaleEffect(landed ? 1 : 2.2)
            .rotationEffect(.degrees(tilt))
            .onAppear {
                withAnimation(.timingCurve(0.34, 1.56, 0.64, 1, duration: 0.45).delay(0.3)) { landed = true }
            }
    }
}

struct ScoreSide: View {
    let player: Player
    let label: String?
    let outcome: DuelOutcome

    var body: some View {
        let won = outcome == .win
        VStack(spacing: 4) {
            PlayerAvatar(name: player.name, bot: player.isBot, size: 52)
            HStack(spacing: 4) {
                Text(label ?? player.name).lineLimit(1)
                if player.isBot { BotTag() }
            }
            .font(.ui(14, .semibold)).foregroundStyle(Theme.text).padding(.top, 4)
            Text("\(player.score)").font(.mono(40)).foregroundStyle(won ? Theme.lime : Theme.text)
            Text("points").font(.ui(12)).foregroundStyle(Theme.muted)
            Text("\(player.correct)/5 · \(clock(player.totalMs))").font(.mono(12, .regular)).foregroundStyle(Theme.soft).padding(.top, 4)
            if won {
                Label("WINNER", systemImage: "trophy.fill")
                    .font(.ui(11, .bold)).tracking(1)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.lime))
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 40)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .card(16, fill: won ? Theme.limeTint : Theme.raised.opacity(0.6), border: won ? Theme.lime : .clear, width: 2)
        .overlay(alignment: .topTrailing) {
            switch outcome {
            case .win: Stamp(text: "CLEARED", color: Theme.lime, tilt: 12).padding(6)
            case .loss: Stamp(text: "RETRY", color: Theme.redSoft, tilt: -10).padding(6)
            case .draw: Stamp(text: "TIE", color: Theme.soft, tilt: 8).padding(6)
            }
        }
    }
}
