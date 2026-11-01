import AppCore
import DesignSystem
import Domain
import SwiftUI

// Port of web/src/app/(app)/home-client.tsx.
public struct HomeView: View {
    let model: HomeViewModel
    @Environment(AppRouter.self) private var router
    @Environment(CompanionState.self) private var companion
    @Environment(TourState.self) private var tour
    @Environment(OnboardingState.self) private var onboarding
    @Environment(LaunchState.self) private var launch
    @State private var now = Date()

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
            .refreshable { await model.load() }
            .onChange(of: tour.scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.smooth(duration: 0.45)) { proxy.scrollTo(target, anchor: .center) }
            }
        }
        .task(id: router.refresh) { await model.load() }
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

    private func content(_ me: Me) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            header(me)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting(now)).font(.ui(14)).foregroundStyle(Theme.muted)
                    Text(me.name)
                        .font(.display(20))
                        .foregroundStyle(Theme.text)
                        .padding(.bottom, 6)
                        .overlay(alignment: .bottom) {
                            Scribble().stroke(Theme.lime, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(height: 10)
                                .offset(y: 6)
                        }
                }
                RatingCard(rating: me.rating)
            }

            if me.hasGuestName {
                Button { router.tab = .profile } label: {
                    HStack(spacing: 12) {
                        (Text("Add your name and college").bold().foregroundColor(Theme.text)
                            + Text(" so friends know who beat them.").foregroundColor(Theme.muted))
                            .font(.ui(14))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .card(16)
                }
                .buttonStyle(.plain)
            }

            if let error = model.error { ErrorNote(error) }

            QuickMatchCard { router.open(.matchmaking(nil)) }
                .tourTarget("quick")
                .rise()
            ChallengeCard(me: me, latest: model.latestChallenge(now: now), busy: model.busy,
                          onStart: { model.startChallenge() },
                          onPlay: { router.open(.duel($0)) })
                .tourTarget("challenge")
                .rise(0.07)
            DailyCard(me: me, now: now, busy: model.busy) { Task { await model.startDaily() } }
                .tourTarget("daily")
                .rise(0.14)
            DriveCard(model: model.drive)
                .rise(0.17)
            CompanyCard { router.open(.matchmaking($0)) }
                .tourTarget("company")
                .rise(0.2)
            RecentDuels(duels: model.duels) { line in router.open(line.finished ? .result(line.id) : .duel(line.id)) }
            CollegeCard(me: me, board: model.board, addCollege: { router.tab = .profile }, fullBoard: { router.tab = .ranks })
            QuestsCard(me: me, busy: model.busy) { action in
                switch action {
                case "daily": Task { await model.startDaily() }
                case "quick": router.open(.matchmaking(nil))
                default: Task { await model.startChallenge() }
                }
            }
            .tourTarget("goals")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 110) // room for Tiko in the corner
    }

    private func header(_ me: Me) -> some View {
        HStack(spacing: 10) {
            Logo()
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .bold))
                    .modifier(Wiggle(active: me.streak > 0))
                Text(me.streak > 0 ? "\(me.streak)" : "Start a streak")
                    .font(me.streak > 0 ? .mono(14) : .ui(14, .bold))
            }
            .foregroundStyle(Theme.orange)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Capsule().fill(Theme.orangeTint))
            .overlay(Capsule().strokeBorder(Theme.orange.opacity(0.3)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(me.streak > 0 ? "\(me.streak)-day streak" : "No streak yet")
            Button { router.tab = .profile } label: { Avatar(name: me.name, size: 40) }
                .accessibilityLabel("Your profile")
        }
    }
}
