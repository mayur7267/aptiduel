import DesignSystem
import Domain
import SwiftUI
import UIKit

// Achievements as die-cut stickers. Earned ones peel up and wobble back
// when tapped; the rest are dashed outlines waiting to be filled.
struct Achievement: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let color: Color
    let earned: Bool

    static func all(for me: Me, saved: Bool) -> [Achievement] {
        [
            Achievement(id: "first", title: "First duel", icon: "bolt.fill", color: Theme.lime, earned: me.gamesPlayed >= 1),
            Achievement(id: "win", title: "First win", icon: "trophy.fill", color: Theme.orange, earned: me.wins >= 1),
            Achievement(id: "streak3", title: "3-day streak", icon: "flame.fill", color: Theme.redSoft, earned: me.streakBest >= 3),
            Achievement(id: "analyst", title: "Analyst", icon: "shield.fill", color: Theme.violet, earned: me.rating >= 1100),
            Achievement(id: "college", title: "College top 3", icon: "building.columns.fill", color: Theme.cyan,
                        earned: (me.collegeRank ?? .max) <= 3),
            Achievement(id: "week", title: "7-day streak", icon: "calendar", color: Theme.lime, earned: me.streakBest >= 7),
            Achievement(id: "saved", title: "Account saved", icon: "lock.fill", color: Theme.violetSoft, earned: saved),
            Achievement(id: "consultant", title: "Consultant", icon: "star.fill", color: Theme.orange, earned: me.rating >= 1300),
        ]
    }
}

struct StickerBook: View {
    let stickers: [Achievement]

    var body: some View {
        let earned = stickers.filter(\.earned).count
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("STICKER BOOK").font(.mono(12)).tracking(2.4).foregroundStyle(Theme.muted)
                Spacer()
                Text("\(earned)/\(stickers.count)").font(.mono(12)).foregroundStyle(Theme.faint)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(Array(stickers.enumerated()), id: \.element.id) { i, s in
                        StickerView(sticker: s, tilt: Double((i * 5) % 11) - 5)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
        }
        .padding(16)
        .card(20)
    }
}

private struct StickerView: View {
    let sticker: Achievement
    let tilt: Double
    @State private var peel = 0.0

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if sticker.earned {
                    Circle().fill(.white)
                    Circle().fill(sticker.color).padding(4)
                    Image(systemName: sticker.icon).font(.system(size: 24, weight: .black)).foregroundStyle(Theme.ink)
                } else {
                    Circle().strokeBorder(Theme.lineStrong, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    Image(systemName: "questionmark").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.faint)
                }
            }
            .frame(width: 64, height: 64)
            // Lifted off the page as it peels.
            .shadow(color: .black.opacity(sticker.earned ? 0.35 + 0.25 * peel : 0), radius: 3 + 8 * peel, x: 2, y: 2 + 6 * peel)
            .rotation3DEffect(.degrees(-38 * peel), axis: (x: 1, y: -1, z: 0), anchor: .bottomTrailing, perspective: 0.6)
            .rotationEffect(.degrees(tilt))
            Text(sticker.title)
                .font(.ui(11, .bold))
                .foregroundStyle(sticker.earned ? Theme.soft : Theme.faint)
                .lineLimit(1)
                .fixedSize()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard sticker.earned else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { peel = 1 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.45).delay(0.28)) { peel = 0 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(sticker.title): \(sticker.earned ? "earned" : "not earned yet")")
    }
}

// Two sticky notes, taped on: report a problem, suggest an idea.
struct StickyNotes: View {
    let onReport: () -> Void
    let onIdea: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            note("Found a bug?", "Tell us what broke", color: Theme.lime, tilt: -3, action: onReport)
            note("Got an idea?", "We read every one", color: Theme.violet, tilt: 2.5, action: onIdea)
        }
        .padding(.top, 8)
    }

    private func note(_ title: String, _ line: String, color: Color, tilt: Double, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.hand(19)).foregroundStyle(Theme.ink)
                Text(line).font(.ui(12, .semibold)).foregroundStyle(Theme.ink.opacity(0.7))
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Image(systemName: "arrow.right").font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.ink)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(
                // A slightly curled corner: the note's own shadow, darker at the bottom right.
                UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 3, bottomTrailingRadius: 14, topTrailingRadius: 3)
                    .fill(color)
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 3, y: 5)
            )
            .overlay(alignment: .top) {
                // A strip of tape holding it on.
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 54, height: 18)
                    .rotationEffect(.degrees(-tilt * 1.5))
                    .offset(y: -9)
            }
            .rotationEffect(.degrees(tilt))
        }
        .buttonStyle(Press())
        .accessibilityLabel(title)
    }
}
