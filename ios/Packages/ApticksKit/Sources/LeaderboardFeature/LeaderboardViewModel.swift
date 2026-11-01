import AppCore
import Domain
import Foundation
import Networking
import Tiko

// Port of web/src/app/(app)/leaderboard/leaderboard-client.tsx.
@MainActor
@Observable
public final class LeaderboardViewModel {
    public var scope: BoardScope = .college {
        didSet { if scope != oldValue { error = nil } }
    }
    public private(set) var boards: [BoardScope: Board] = [:]
    public private(set) var error: String?

    private let api: any APIClient
    private let router: AppRouter?

    public init(api: any APIClient, router: AppRouter? = nil) {
        self.api = api
        self.router = router
    }

    // Someone else's row opens their profile.
    public func open(_ row: BoardRow) {
        guard let id = row.id, !row.isMe else { return }
        router?.open(.player(id))
    }

    public var board: Board? { boards[scope] }

    public func load() async {
        let s = scope
        do {
            boards[s] = try await api.leaderboard(s, limit: 50)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    var companionPage: CompanionPage {
        board?.isEmpty == true
            ? CompanionPage(mood: .think, say: "Nobody's ranked here yet. One Quick Match puts you on top!")
            : CompanionPage(mood: .point)
    }
}
