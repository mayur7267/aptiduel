import AppCore
import ChallengeFeature
import DailyFeature
import DuelFeature
import Domain
import FeedbackFeature
import Foundation
import HomeFeature
import LeaderboardFeature
import Networking
import NetworkingFakes
import NetworkingLive
import OnboardingFeature
import ProfileFeature
import SwiftUI

// The composition root: builds the backend, the shared state and every
// view model, and hands each feature only what it needs.
@MainActor
final class AppContainer {
    let dependencies: Dependencies
    let router = AppRouter()
    let companion = CompanionState()
    let tour = TourState()
    let onboarding = OnboardingState()
    let launch = LaunchState()
    let feedback = FeedbackState()
    let review = ReviewState()

    // The tabs keep their view models, so switching tabs shows the last
    // data straight away while it refreshes.
    let home: HomeViewModel
    let daily: DailyViewModel
    let leaderboard: LeaderboardViewModel
    let profile: ProfileViewModel
    let account: AccountViewModel
    let intro: OnboardingViewModel

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        home = HomeViewModel(api: dependencies.api, router: router)
        daily = DailyViewModel(api: dependencies.api, router: router)
        leaderboard = LeaderboardViewModel(api: dependencies.api, router: router)
        profile = ProfileViewModel(api: dependencies.api, router: router)
        account = AccountViewModel(account: dependencies.account, router: router)
        intro = OnboardingViewModel(api: dependencies.api, router: router, onboarding: onboarding)
    }

    // The real backend, or an in-memory one when launched with
    // -FakeBackend (for UI runs and screenshots without production data).
    static func make() -> AppContainer {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-FakeBackend") {
            let fake = FakeBackend()
            return AppContainer(dependencies: Dependencies(api: fake, account: fake))
        }
        #endif
        let backend = SupabaseBackend(url: AppConfig.supabaseURL, key: AppConfig.supabaseKey)
        return AppContainer(dependencies: Dependencies(api: backend, account: backend))
    }

    func feedbackModel(_ request: FeedbackRequest) -> FeedbackViewModel {
        FeedbackViewModel(request: request, api: dependencies.api, account: dependencies.account)
    }

    // Where the player is, for feedback sent by shaking the phone.
    var currentScreen: String {
        switch router.flow?.screen {
        case let .matchmaking(company): "matchmaking" + (company.map { " (\($0.name))" } ?? "")
        case let .duel(id): "duel \(id)"
        case let .result(id): "result \(id)"
        case let .challenge(code): "challenge \(code)"
        case .newRoom: "new live room"
        case let .live(id): "live duel \(id)"
        case let .player(id): "player \(id)"
        case nil: "\(router.tab) tab"
        }
    }

    // A full-screen flow's screen, with a fresh view model.
    @ViewBuilder
    func view(for screen: Screen) -> some View {
        let api = dependencies.api
        switch screen {
        case let .matchmaking(company):
            MatchmakingView(model: MatchmakingViewModel(company: company, api: api, router: router))
        case let .duel(id):
            DuelPlayView(model: DuelPlayViewModel(duelId: id, api: api, router: router))
        case let .result(id):
            DuelResultView(model: DuelResultViewModel(duelId: id, api: api, router: router))
        case let .challenge(code):
            ChallengeView(model: ChallengeViewModel(code: code, api: api, account: dependencies.account, router: router))
        case .newRoom:
            NewRoomView(model: NewRoomViewModel(api: api, account: dependencies.account, router: router))
        case let .live(id):
            LiveStartView(model: LiveStartViewModel(duelId: id, api: api, router: router))
        case let .player(id):
            PlayerProfileView(model: PlayerProfileViewModel(id: id, api: api, router: router))
        }
    }
}

// Build settings read at run time (Configs/App.xcconfig via Info.plist).
enum AppConfig {
    static let supabaseURL = URL(string: value("SupabaseURL"))!
    static let supabaseKey = value("SupabaseKey")

    private static func value(_ key: String) -> String {
        guard let v = Bundle.main.object(forInfoDictionaryKey: key) as? String, !v.isEmpty else {
            fatalError("\(key) is missing from Info.plist; check Configs/App.xcconfig")
        }
        return v
    }
}
