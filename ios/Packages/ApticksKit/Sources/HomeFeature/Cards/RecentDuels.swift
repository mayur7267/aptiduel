import DesignSystem
import Domain
import SwiftUI

// The last few duels; three until you ask for more.
struct RecentDuels: View {
    let duels: [DuelSummary]
    let onOpen: (DuelLine) -> Void
    @State private var showAll = false

    var body: some View {
        let all = duels.map(DuelLine.init)
        let rows = showAll ? all : Array(all.prefix(3))
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Recent duels").font(.ui(17, .bold)).foregroundStyle(Theme.text)
                Spacer()
                if all.count > 3 {
                    Button(showAll ? "Show fewer" : "Show all \(all.count)") { withAnimation(.snappy) { showAll.toggle() } }
                        .font(.ui(13, .semibold))
                        .foregroundStyle(Theme.lime)
                }
            }
            .padding(.bottom, 8)
            if rows.isEmpty {
                Text("No duels yet. A Quick Match takes about 3 minutes.").font(.ui(14)).foregroundStyle(Theme.muted)
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                if i > 0 { Rectangle().fill(Theme.line).frame(height: 1) }
                Button { onOpen(r) } label: {
                    HStack(spacing: 12) {
                        if r.daily {
                            Image(systemName: "calendar").font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.violet)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Theme.violetTint))
                        } else {
                            PlayerAvatar(name: r.hasOpponent ? r.who : "?", bot: r.bot, size: 32)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(r.who).font(.ui(14, .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                                if r.bot { BotTag() }
                            }
                            HStack(spacing: 8) {
                                Chip(r.status.text, fg: r.status.fg, bg: r.status.bg, size: 11)
                                Text(r.score).font(.mono(12, .regular)).foregroundStyle(Theme.muted)
                            }
                        }
                        Spacer(minLength: 0)
                        Delta(r.delta)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(22)
    }
}
