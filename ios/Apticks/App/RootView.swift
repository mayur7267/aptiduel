import AppCore
import Companion
import DailyFeature
import DesignSystem
import Domain
import FeedbackFeature
import HomeFeature
import LeaderboardFeature
import OnboardingFeature
import ProfileFeature
import SwiftUI

struct RootView: View {
    let container: AppContainer

    var body: some View {
        let router = container.router
        ZStack {
            GraphPaper()
            Group {
                switch router.tab {
                case .home: HomeView(model: container.home)
                case .daily: DailyView(model: container.daily)
                case .ranks: LeaderboardView(model: container.leaderboard)
                case .profile: ProfileView(profile: container.profile, account: container.account)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottomTrailing) { CompanionView() }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                TabBar(unplayedDaily: container.home.me.map { $0.quests.daily == 0 } ?? false)
            }

            TikoTour()

            // First launch: the intro, over everything.
            if container.onboarding.showing {
                OnboardingView(model: container.intro)
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 1.06))))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: container.onboarding.showing)
        .overlay {
            if container.launch.splashing {
                BrandSplash { container.launch.splashFinished() }
            }
        }
        .feedbackSheet(container.feedback, active: router.flow == nil, model: container.feedbackModel)
        .fullScreenCover(item: Bindable(router).flow) { flow in
            FlowHost(flow: flow, container: container)
                .feedbackSheet(container.feedback, active: true, model: container.feedbackModel)
                .environment(container.feedback)
                .environment(container.review)
                .environment(router)
                .environment(container.companion)
                .environment(container.tour)
                .environment(container.onboarding)
                .environment(container.launch)
                .preferredColorScheme(.dark)
        }
        .environment(router)
        .environment(container.companion)
        .environment(container.tour)
        .environment(container.onboarding)
        .environment(container.launch)
        .environment(container.feedback)
        .environment(container.review)
        // Shake the phone anywhere to report a problem.
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            guard container.feedback.request == nil, !container.launch.splashing else { return }
            container.feedback.open(.bug, context: ["via": "shake", "screen": container.currentScreen])
        }
        // Challenge links: apticks://c/CODE, or the website's link once
        // universal links are set up (see ios/README.md).
        .onOpenURL { router.handle($0) }
    }
}

// The website's sidebar, as a bottom tab bar.
struct TabBar: View {
    @Environment(AppRouter.self) private var router
    var unplayedDaily: Bool = false

    private let items: [(AppTab, String, String)] = [
        (.home, "Home", "house.fill"),
        (.daily, "Daily", "calendar"),
        (.ranks, "Ranks", "chart.bar.fill"),
        (.profile, "Profile", "person.fill"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { tab, label, icon in
                let active = router.tab == tab
                Button {
                    router.tab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .overlay(alignment: .topTrailing) {
                                if tab == .daily && unplayedDaily {
                                    Circle()
                                        .fill(Theme.lime)
                                        .frame(width: 7, height: 7)
                                        .offset(x: 4, y: -2)
                                }
                            }
                        Text(label).font(.ui(11, .semibold))
                    }
                    .foregroundStyle(active ? Theme.lime : Theme.faint)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                .accessibilityAddTraits(active ? .isSelected : [])
                .modifier(TabTarget(tab: tab))
                .sensoryFeedback(.selection, trigger: active) { _, now in now }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background {
            Theme.bar
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

// The tour stops at the Profile tab.
private struct TabTarget: ViewModifier {
    let tab: AppTab

    func body(content: Content) -> some View {
        if tab == .profile { content.tourTarget("profile", outline: false) } else { content }
    }
}

// The full-screen flow: matchmaking, the duel, its result, challenge links.
struct FlowHost: View {
    let flow: FlowSession
    let container: AppContainer

    var body: some View {
        ZStack {
            GraphPaper()
            container.view(for: flow.screen)
                .id(flow.screen)
                .transition(.opacity)
        }
    }
}
