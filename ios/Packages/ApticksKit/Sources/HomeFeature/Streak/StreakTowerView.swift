import AppCore
import DesignSystem
import Domain
import Networking
import SwiftUI
import Tiko

// Your Streak Tower (web/src/app/(app)/streak): the tower Tiko stands on,
// the next badge, the badge shelf, the days you played and your college's
// longest streaks. Opened from the streak chip on Home.
@MainActor
@Observable
public final class StreakTowerViewModel {
    public enum Load: Equatable {
        case loading
        case failed(String)
        case loaded(StreakInfo)
    }

    public private(set) var load: Load = .loading
    public var replay: StreakCelebration?

    private let api: any APIClient
    private let router: AppRouter?

    public init(api: any APIClient, router: AppRouter? = nil) {
        self.api = api
        self.router = router
    }

    public func fetch() async {
        do {
            load = .loaded(try await api.myStreak())
        } catch {
            if !error.isCancellation { load = .failed(error.localizedDescription) }
        }
    }

    public func replayToday() {
        guard case let .loaded(s) = load, s.streak > 0 else { return }
        replay = .up(from: s.streak - 1, to: s.streak, fresh: s.streak == 1)
    }

    public func play() { router?.open(.matchmaking(nil)) }
    public func close() { router?.close() }
}

public struct StreakTowerView: View {
    @State private var model: StreakTowerViewModel

    public init(model: StreakTowerViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton("Back to home") { model.close() }
                Spacer()
                Logo()
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                Group {
                    switch model.load {
                    case .loading: Spinner("Stacking your tower").padding(.top, 80)
                    case let .failed(message): ErrorNote(message) { Task { await model.fetch() } }
                    case let .loaded(s): content(s)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .task { await model.fetch() }
        .overlay {
            if let c = model.replay {
                StreakCelebrationView(c: c, onClose: { model.replay = nil }, onTower: { model.replay = nil }, onPlay: { model.replay = nil; model.play() })
                    .transition(.opacity)
            }
        }
    }

    private func content(_ s: StreakInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            hero(s)
            badges(s)
            calendar(s)
            if let college = s.college { collegeTop(s, college) }
        }
    }

    private func hero(_ s: StreakInfo) -> some View {
        let next = Streak.next(after: s.streak)
        let prev = Streak.milestones.last { $0 <= s.streak } ?? 0
        let shown = min(s.streak, 8)
        let share = "🔥 I'm on a \(s.streak)-day streak on Apticks, quick 1v1 aptitude, coding and English duels. Can you build a taller tower? \(Links.site)"
        return VStack(alignment: .leading, spacing: 14) {
            Chip("🔥 Your Streak Tower", fg: Theme.orange, bg: Theme.orangeTint)
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(s.streak)").font(.display(84)).foregroundStyle(Theme.lime)
                        Text(s.streak == 1 ? "day" : "days").font(.display(22)).foregroundStyle(Theme.text)
                    }
                    Text(s.streak == 0 ? "No tower yet. One duel today lays the first block."
                         : s.playedToday ? "Today's block is on. Come back tomorrow for day \(s.streak + 1)."
                         : "Play one duel today to stack day \(s.streak + 1), or the tower falls at midnight.")
                        .font(.ui(14)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Chip("Best: \(s.best) days", fg: Theme.text, bg: Theme.raised)
                        if s.best > s.streak { Chip("\(s.best - s.streak) to beat it", fg: Theme.muted, bg: Theme.raised) }
                    }
                }
                Spacer(minLength: 0)
            }
            // The tower, newest block on top, Tiko standing on it.
            VStack(spacing: 0) {
                TikoView(mood: s.streak > 0 ? .cheer : .think, size: 80).padding(.bottom, -4)
                if s.streak == 0 {
                    Text("Day 1 goes here").font(.ui(14, .semibold)).foregroundStyle(Theme.muted)
                        .frame(width: 210, height: 66)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
                } else {
                    ForEach(0..<shown, id: \.self) { i in
                        let day = s.streak - i
                        StreakBlockView(day: day, weekday: Streak.weekday(daysAgo: s.streak - day + (s.playedToday ? 0 : 1)), width: 210, height: 66)
                            .opacity(1 - Double(max(0, i - 5)) * 0.25)
                            .padding(.bottom, 8)
                    }
                }
                if s.streak > shown { Text("+\(s.streak - shown) more below").font(.ui(12)).foregroundStyle(Theme.muted).padding(.top, 4) }
            }
            .frame(maxWidth: .infinity)
            if let next {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Next badge: \(Streak.title(next))").font(.ui(13, .semibold)).foregroundStyle(Theme.text)
                        Spacer()
                        Text("\(s.streak)/\(next)").font(.mono(12)).foregroundStyle(Theme.muted)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.raised)
                            Capsule().fill(Theme.lime).frame(width: max(12, g.size.width * CGFloat(s.streak - prev) / CGFloat(max(1, next - prev))))
                        }
                        .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
                    }
                    .frame(height: 16)
                }
            }
            HStack(spacing: 10) {
                if !s.playedToday {
                    Button { model.play() } label: { Label("Play a duel", systemImage: "bolt.fill").frame(maxWidth: .infinity) }
                        .buttonStyle(.lime)
                }
                if s.streak > 0 {
                    Button("🎉 Replay") { model.replayToday() }
                        .buttonStyle(FilledStyle(fill: Theme.raised, foreground: Theme.text, border: Theme.line))
                }
                if s.streak > 1 {
                    ShareLink(item: share) { Label("Share", systemImage: "square.and.arrow.up") }
                        .buttonStyle(FilledStyle(fill: Theme.raised, foreground: Theme.text, border: Theme.line))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(22)
    }

    private func badges(_ s: StreakInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Badges").font(.ui(17, .bold)).foregroundStyle(Theme.text)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 14) {
                ForEach(Streak.milestones, id: \.self) { m in
                    let got = s.best >= m
                    VStack(spacing: 6) {
                        ZStack {
                            if got {
                                Circle().fill(.black).offset(x: 4, y: 5)
                                Circle().fill(StreakBlockView.fill(m))
                                Circle().strokeBorder(Theme.ink, lineWidth: 3)
                                Text("\(m)").font(.display(18)).foregroundStyle(Theme.ink)
                            } else {
                                Circle().strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                                Image(systemName: "lock.fill").font(.system(size: 14)).foregroundStyle(Theme.faint)
                            }
                        }
                        .frame(width: 54, height: 54)
                        Text("\(m) days").font(.ui(11, .semibold)).foregroundStyle(got ? Theme.text : Theme.faint)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(Streak.title(m)) \(got ? "earned" : "locked")")
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(20)
    }

    // The last eight weeks, Monday to Sunday: a brick for every day you played.
    private func calendar(_ s: StreakInfo) -> some View {
        let played = Set(s.days), today = Streak.istDay(.now), dow = Streak.weekdayIndex()
        let cells: [(String, Int)] = (0..<56).map { i in
            let back = 55 - i - (6 - dow)
            return (Streak.istDay(Date.now.addingTimeInterval(-Double(back) * 86_400)), back)
        }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Days you played").font(.ui(17, .bold)).foregroundStyle(Theme.text)
                Spacer()
                Text("\(s.days.count) in the last 120 days").font(.ui(12)).foregroundStyle(Theme.muted)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, d in
                    Text(d).font(.mono(11)).foregroundStyle(Theme.faint)
                }
                ForEach(cells, id: \.0) { day, back in
                    let on = played.contains(day)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(on ? Theme.lime : back < 0 ? Color.clear : Theme.raised)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(on ? Theme.ink : back < 0 ? Color.clear : Theme.line, lineWidth: on ? 2 : 1))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(day == today ? Theme.lime : .clear, lineWidth: 2).padding(-3))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(20)
    }

    private func collegeTop(_ s: StreakInfo, _ college: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Longest streaks at \(college)").font(.ui(17, .bold)).foregroundStyle(Theme.text)
            if s.collegeTop.isEmpty {
                Text("No live streaks here yet. Yours could be the first.").font(.ui(14)).foregroundStyle(Theme.muted)
            } else {
                ForEach(Array(s.collegeTop.enumerated()), id: \.offset) { i, r in
                    HStack(spacing: 12) {
                        Text("\(i + 1)").font(.mono(14)).foregroundStyle(Theme.muted).frame(width: 18)
                        Text(r.isMe ? "You" : r.name).font(.ui(15, .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                        Spacer()
                        Label("\(r.streak)", systemImage: "flame.fill").font(.mono(14)).foregroundStyle(Theme.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .card(14, fill: r.isMe ? Theme.limeTint : Theme.raised, border: r.isMe ? Theme.lime.opacity(0.5) : Theme.line)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(20)
    }
}
