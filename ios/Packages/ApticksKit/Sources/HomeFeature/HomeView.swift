import AppCore
import DesignSystem
import Domain
import SwiftUI

// Port of web/src/app/(app)/home-client.tsx, laid out for a phone:
// every way to play fits on the first screen, one tap each, and today's
// Daily Challenge, goals and placement test share one swipeable deck.
public struct HomeView: View {
    let model: HomeViewModel
    @Environment(AppRouter.self) private var router
    @Environment(CompanionState.self) private var companion
    @Environment(TourState.self) private var tour
    @Environment(OnboardingState.self) private var onboarding
    @Environment(LaunchState.self) private var launch
    @State private var now = Date()
    // The deck page you turned to; until then, the suggested one.
    @State private var page: TodayPage?
    @State private var choosingCompany = false
    @State private var pickedCompany: Company?
    @State private var showingCalendar = false
    @State private var playFromCalendar = false

    public init(model: HomeViewModel) { self.model = model }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if let me = model.me {
                    content(me)
                } else {
                    VStack(alignment: .leading, spacing: 24) {
                        Logo()
                        if let error = model.error {
                            ErrorNote(error) { Task { await model.load() } }
                        } else {
                            Spinner("Loading")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .scrollIndicators(.hidden)
            .background(alignment: .top) { glow }
            .refreshable {
                // Stay on the page you're looking at.
                page = page ?? model.suggestedPage
                await model.load()
            }
            .onChange(of: tour.scrollTarget) { _, target in
                guard let target else { return }
                // Daily and goals are pages of the deck: turn to them.
                let deckPage = TodayPage(rawValue: target)
                if let deckPage { withAnimation(.snappy) { page = deckPage } }
                // Only as far as needed; usually it's all on screen already.
                withAnimation(.smooth(duration: 0.45)) { proxy.scrollTo(deckPage == nil ? target : "today") }
            }
        }
        .task(id: router.refresh) {
            // Back from a duel: show whatever is next.
            page = nil
            await model.load()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                now = Date()
            }
        }
        .onChange(of: model.me, initial: true) { companion.pages[.home] = model.nudge }
        // First visit (or a replay from Profile): the tour, once home has loaded.
        .task(id: [model.me != nil, tour.replayRequested, onboarding.showing, launch.splashing]) {
            guard model.me != nil, tour.shouldStart, router.flow == nil, !onboarding.showing, !launch.splashing else { return }
            try? await Task.sleep(for: .milliseconds(700))
            if Task.isCancelled || router.tab != .home { return }
            tour.start()
        }
        // A sheet has to close before the duel's full-screen flow opens.
        .sheet(isPresented: $choosingCompany, onDismiss: {
            if let c = pickedCompany {
                pickedCompany = nil
                router.open(.matchmaking(c))
            }
        }) {
            CompanySheet(test: model.drive.drive?.company) { c in
                pickedCompany = c
                choosingCompany = false
            }
        }
    }

    private var glow: some View {
        ZStack {
            RadialGradient(colors: [Theme.lime.opacity(0.07), .clear], center: UnitPoint(x: 0.2, y: -0.2), startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Theme.violet.opacity(0.08), .clear], center: UnitPoint(x: 0.95, y: -0.15), startRadius: 0, endRadius: 360)
        }
        .frame(height: 420)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var deckPage: Binding<TodayPage?> {
        Binding(get: { page ?? model.suggestedPage }, set: { if let p = $0 { page = p } })
    }

    private func content(_ me: Me) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            header(me)

            if me.hasGuestName {
                Button { router.tab = .profile } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.plus").foregroundStyle(Theme.lime)
                        (Text("Add your name and college").bold().foregroundColor(Theme.text)
                            + Text(" for your college board").foregroundColor(Theme.muted))
                            .font(.ui(13))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .card(14)
                }
                .buttonStyle(.plain)
            }

            if let error = model.error { ErrorNote(error) }

            TodayDeck(me: me, now: now, busy: model.busy, drive: model.drive, page: deckPage,
                      onDaily: { Task { await model.startDaily() } },
                      onCalendar: { showingCalendar = true },
                      onGoal: { goal in
                          switch goal {
                          case .daily: Task { await model.startDaily() }
                          case .quick: router.open(.matchmaking(nil))
                          case .friend: model.startChallenge()
                          }
                      })
                .id("today")
                .rise()
                .sheet(isPresented: $showingCalendar, onDismiss: {
                    if playFromCalendar {
                        playFromCalendar = false
                        Task { await model.startDaily() }
                    }
                }) {
                    DailyCalendarSheet(model: model.calendar, me: me, busy: model.busy) {
                        playFromCalendar = true
                        showingCalendar = false
                    }
                }

            VStack(alignment: .leading, spacing: 10) {
                Text("PLAY").font(.mono(12)).tracking(1.6).foregroundStyle(Theme.faint)
                QuickMatchCard(rating: me.rating) { router.open(.matchmaking(nil)) }
                    .tourTarget("quick")
                HStack(spacing: 12) {
                    FriendTile(me: me, busy: model.busy) { model.startChallenge() }
                        .tourTarget("challenge")
                    CompanyTile(test: model.drive.drive?.company) { choosingCompany = true }
                        .tourTarget("company")
                }
                .fixedSize(horizontal: false, vertical: true)
                // A challenge from before, or one a friend didn't join live.
                if let latest = model.latestChallenge(now: now), !latest.finished {
                    yourTurn(latest)
                }
            }
            .rise(0.07)

            RecentDuels(duels: model.duels) { line in router.open(line.finished ? .result(line.id) : .duel(line.id)) }
                .padding(.top, 8)
            CollegeCard(me: me, board: model.board, addCollege: { router.tab = .profile }, fullBoard: { router.tab = .ranks })
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 110) // room for Tiko in the corner
    }

    private func header(_ me: Me) -> some View {
        HStack(spacing: 10) {
            Button { router.tab = .profile } label: { Avatar(name: me.name, size: 44) }
                .accessibilityLabel("Your profile")
            VStack(alignment: .leading, spacing: 1) {
                Text(greeting(now)).font(.ui(13)).foregroundStyle(Theme.muted)
                Text(me.name)
                    .font(.display(17))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .padding(.bottom, 4)
                    .overlay(alignment: .bottom) {
                        Scribble().stroke(Theme.lime, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(height: 8)
                            .offset(y: 5)
                    }
            }
            .layoutPriority(-1)
            Spacer(minLength: 4)
            StreakChip(streak: me.streak) { withAnimation(.snappy) { page = .daily } }
            RatingChip(rating: me.rating) { router.tab = .profile }
        }
    }

    private func yourTurn(_ duel: DuelSummary) -> some View {
        Button { router.open(.duel(duel.id)) } label: {
            HStack(spacing: 12) {
                Image(systemName: "hourglass").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.orange)
                    .frame(width: 34, height: 34).background(Circle().fill(Theme.orangeTint))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your last challenge is waiting").font(.ui(14, .bold)).foregroundStyle(Theme.text)
                    Text("Play your turn before it expires").font(.ui(12)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.orange)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .card(16, border: Theme.orange.opacity(0.35))
        }
        .buttonStyle(.plain)
    }
}
