import DesignSystem
import Domain
import SwiftUI
import Tiko

// The streak, in the header. Tapping it opens your Streak Tower. In the
// evening, with no duel yet today, it pulses: the tower falls at midnight.
struct StreakChip: View {
    let streak: Int
    var atRisk = false
    var note: Int? = nil // Tiko's "Day 5 done!" note, back after the day's first duel
    var noteDone: () -> Void = {}
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .bold))
                    .modifier(Wiggle(active: streak > 0))
                Text("\(streak)").font(.mono(14))
            }
            .foregroundStyle(streak > 0 ? Theme.orange : Theme.faint)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Capsule().fill(streak > 0 ? Theme.orangeTint : Theme.raised))
            .overlay(Capsule().strokeBorder(streak > 0 ? Theme.orange.opacity(atRisk ? 1 : 0.3) : Theme.line, lineWidth: atRisk ? 2 : 1))
            .scaleEffect(atRisk && pulse ? 1.08 : 1)
            .animation(atRisk ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: pulse)
            .onAppear { pulse = atRisk }
            .onChange(of: atRisk) { _, now in pulse = now }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if let note { StreakNote(day: note, done: noteDone) }
        }
        .accessibilityLabel(streak > 0 ? "\(streak)-day streak" + (atRisk ? ", play today to keep it" : "") : "No streak yet")
        .accessibilityHint("Opens your Streak Tower")
    }
}

// Your rating, with a ring that fills on the way to the next tier.
struct RatingChip: View {
    let rating: Int
    let action: () -> Void

    var body: some View {
        let tier = tierFor(rating)
        Button(action: action) {
            HStack(spacing: 6) {
                ZStack {
                    Circle().stroke(Theme.violet.opacity(0.25), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: tier.progress)
                        .stroke(Theme.violet, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "shield.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.violet)
                }
                .frame(width: 22, height: 22)
                Text(grouped(rating))
                    .font(.mono(14))
                    .foregroundStyle(Theme.violetSoft)
                    .contentTransition(.numericText(value: Double(rating)))
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .frame(height: 38)
            .background(Capsule().fill(Theme.violetTint))
            .overlay(Capsule().strokeBorder(Theme.violet.opacity(0.3)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rating \(grouped(rating)), \(tier.name)" + (tier.next.map { ", \(tier.toNext) to \($0.name)" } ?? ""))
        .accessibilityHint("Opens your profile")
    }
}

// Tiko drops onto the streak chip with a bounce and a short note, then
// leaves after a few seconds or a tap (web/src/components/streak-note.tsx).
private struct StreakNote: View {
    let day: Int
    let done: () -> Void
    @State private var landed = false
    @State private var bubble = false
    @State private var leaving = false

    var body: some View {
        let words = Streak.homeNote(day: day)
        ZStack(alignment: .topTrailing) {
            TikoView(mood: .cheer, size: 34, still: true, interactive: false)
                .scaleEffect(x: landed ? 1 : 0.6, y: landed ? 1 : 0.6, anchor: .bottom)
                .offset(x: -64, y: landed ? -22 : -110)
                .opacity(landed && !leaving ? 1 : 0)
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 2) {
                Text(words.title).font(.display(15)).foregroundStyle(Theme.ink)
                Text(words.sub).font(.ui(13)).foregroundStyle(Theme.ink.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(width: 236, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white))
            .background(RoundedRectangle(cornerRadius: 16).fill(.black).offset(x: 5, y: 6))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.ink, lineWidth: 3))
            .overlay(alignment: .topTrailing) {
                Rectangle().fill(.white).frame(width: 14, height: 14)
                    .overlay(alignment: .topLeading) { Rectangle().fill(Theme.ink).frame(width: 3) }
                    .overlay(alignment: .topLeading) { Rectangle().fill(Theme.ink).frame(height: 3) }
                    .rotationEffect(.degrees(45))
                    .offset(x: -24, y: -8)
            }
            .scaleEffect(bubble ? 1 : 0.85, anchor: .topTrailing)
            .opacity(bubble && !leaving ? 1 : 0)
            .offset(y: 52)
            .onTapGesture { leave() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)
        }
        .fixedSize()
        .task {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.5).delay(0.25)) { landed = true }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.62).delay(0.8)) { bubble = true }
            try? await Task.sleep(for: .milliseconds(640))
            Haptics.shared.tick(0.5)
            try? await Task.sleep(for: .seconds(5.4))
            leave()
        }
    }

    private func leave() {
        guard !leaving else { return }
        withAnimation(.easeIn(duration: 0.3)) { leaving = true }
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            done()
        }
    }
}
