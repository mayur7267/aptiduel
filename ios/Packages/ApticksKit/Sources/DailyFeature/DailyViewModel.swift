import AppCore
import Domain
import Foundation
import Networking

// Today's daily challenge (port of web/src/app/(app)/daily/daily-start.tsx).
// A fresh run waits for Start, since the clock begins as soon as the first
// question opens.
@MainActor
@Observable
public final class DailyViewModel {
    public private(set) var duel: Duel?
    public private(set) var error: String?

    private let api: any APIClient
    private let router: AppRouter

    public init(api: any APIClient, router: AppRouter) {
        self.api = api
        self.router = router
    }

    public var finished: Bool { duel?.me.finished == true }
    public var started: Bool { (duel?.me.answered ?? 0) > 0 }

    public func load() async {
        do {
            duel = try await api.duel(try await api.dailyChallenge().duelId)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func open() {
        guard let duel else { return }
        router.open(finished ? .result(duel.id) : .duel(duel.id))
    }
}
