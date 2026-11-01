import AppCore
import Domain
import Foundation
import Networking

// After a duel (port of web/src/app/duel/[id]/result/duel-result.tsx).
@MainActor
@Observable
public final class DuelResultViewModel {
    public let duelId: String
    public private(set) var duel: Duel?
    public private(set) var error: String?
    public private(set) var ownCode: String?
    public private(set) var sharing = false
    public var showReview = false
    // Live duels: the rematch room, once either player has asked for one.
    public private(set) var rematchId: String?
    public private(set) var rematching = false

    private let api: any APIClient
    private let router: AppRouter
    private let sleep: (Duration) async -> Void

    public init(duelId: String, api: any APIClient, router: AppRouter,
                sleep: @escaping (Duration) async -> Void = Wait.real) {
        self.duelId = duelId
        self.api = api
        self.router = router
        self.sleep = sleep
    }

    // The link to share: your own challenge's, or one made from this run.
    public var shareCode: String? { duel?.isCreator == true ? duel?.code : ownCode }
    // After company practice, "play again" means the same company.
    public var rematch: Company? { company(named: duel?.company) }

    public func load() async {
        do {
            let d = try await api.duel(duelId)
            if d.me.finished { duel = d } else { router.open(.duel(duelId)) }
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func retry() async {
        error = nil
        await load()
    }

    // Keep checking while an opponent can still arrive or finish: every
    // couple of seconds in a live race, every 8 otherwise.
    public func poll() async {
        while duel?.awaitingOpponent == true, !Task.isCancelled {
            await sleep(isLive ? .seconds(2) : .seconds(8))
            if Task.isCancelled { return }
            if let d = try? await api.duel(duelId) { duel = d }
        }
    }

    public func makeShareCode() async {
        sharing = true
        do {
            ownCode = try await api.shareCode(duelId).code
        } catch {
            self.error = error.localizedDescription
        }
        sharing = false
    }

    public var isLive: Bool { duel?.mode == .live }

    // Live duels: notice when the other player asks for a rematch.
    public func watchRematch() async {
        while isLive, !Task.isCancelled {
            if let s = try? await api.liveState(duelId) { rematchId = s.rematchId }
            await sleep(.milliseconds(2500))
        }
    }

    // Asking again just returns the room the other player made.
    public func rematchLive() async {
        rematching = true
        do {
            router.open(.challenge(try await api.liveRematch(duelId).code))
        } catch {
            self.error = error.localizedDescription
        }
        rematching = false
    }

    public func openPlayer(_ id: String) { router.open(.player(id)) }
    public func playAgain() { router.open(.matchmaking(rematch)) }
    public func close(to tab: AppTab? = nil) { router.close(to: tab) }
}
