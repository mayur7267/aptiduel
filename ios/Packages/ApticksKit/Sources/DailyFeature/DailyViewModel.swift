import AppCore
import Domain
import Foundation
import Networking

// Today's daily challenge (port of web/src/app/(app)/daily/daily-start.tsx).
// Today's run is only made when Start is pressed, so opening this tab
// doesn't count as starting a game, and the clock begins with the first
// question. A run you've finished shows its score and opens its result.
@MainActor
@Observable
public final class DailyViewModel {
    // Today's finished run, once there is one.
    public private(set) var duel: Duel?
    // Nothing finished today: show what the Daily is, with Start.
    public private(set) var ready = false
    public private(set) var starting = false
    public private(set) var error: String?

    private let api: any APIClient
    private let router: AppRouter

    public init(api: any APIClient, router: AppRouter) {
        self.api = api
        self.router = router
    }

    public var finished: Bool { duel?.me.finished == true }

    public func load() async {
        do {
            if try await api.me().quests.daily == 0 {
                duel = nil
                ready = true
            } else {
                // Finished today: asking again returns that run, it doesn't make one.
                duel = try await api.duel(try await api.dailyChallenge().duelId)
                ready = false
            }
            error = nil
        } catch {
            // Cancelled part-way (a pull-to-refresh restarted): keep what's shown.
            if !error.isCancellation { self.error = error.localizedDescription }
        }
    }

    // Makes today's run (or returns the one already started) and opens it.
    public func start() async {
        guard !starting else { return }
        starting = true
        defer { starting = false }
        do {
            router.open(.duel(try await api.dailyChallenge().duelId))
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func open() {
        guard let duel else { return }
        router.open(.result(duel.id))
    }
}
