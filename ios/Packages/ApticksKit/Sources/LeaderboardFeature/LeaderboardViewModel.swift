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
    // Each subject has its own board.
    public var subject: Subject = .aptitude {
        didSet { if subject != oldValue { error = nil } }
    }
    public private(set) var boards: [String: Board] = [:]
    public private(set) var error: String?
    // Your college's id, for its campus link (the board only has its name).
    public private(set) var collegeId: Int?

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

    private func key(_ subject: Subject, _ scope: BoardScope) -> String { "\(subject.rawValue)-\(scope.rawValue)" }
    public var board: Board? { boards[key(subject, scope)] }

    public func load() async {
        let (sub, s) = (subject, scope)
        do {
            async let me: Me? = s == .college ? (try? await api.me()) : nil
            boards[key(sub, s)] = try await api.leaderboard(s, limit: 50, subject: sub)
            if let me = await me { collegeId = me.collegeId }
            error = nil
        } catch {
            // Cancelled part-way (a pull-to-refresh restarted): keep what's shown.
            if !error.isCancellation { self.error = error.localizedDescription }
        }
    }

    // The campus link was shared (0021 share counts).
    public func logInvite(_ channel: ShareChannel) {
        Task { try? await api.logShare(.campus, channel, duelId: nil) }
    }

    var companionPage: CompanionPage {
        board?.isEmpty == true
            ? CompanionPage(mood: .think, say: "Nobody's ranked in \(subject.label) here yet. One Quick Match puts you on top!")
            : CompanionPage(mood: .point)
    }
}
