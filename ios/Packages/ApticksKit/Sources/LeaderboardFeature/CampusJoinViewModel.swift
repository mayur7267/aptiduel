import AppCore
import Domain
import Foundation
import Networking

// A college's campus link (playapticks.in/join/<id>-<name>), opened in the
// app: that college's page, and one tap to join its board and start a duel.
// Port of web/src/app/join/[slug].
@MainActor
@Observable
public final class CampusJoinViewModel {
    public enum Load: Equatable {
        case loading
        case missing // no college with that id
        case failed(String)
        case loaded(CollegeCard, Me)
    }

    public private(set) var load: Load = .loading
    public private(set) var joining = false
    public private(set) var error: String?

    private let id: Int
    private let api: any APIClient
    private let router: AppRouter?

    public init(id: Int, api: any APIClient, router: AppRouter? = nil) {
        self.id = id
        self.api = api
        self.router = router
    }

    public func fetch() async {
        do {
            async let card = api.collegeCard(id)
            async let me = api.me()
            guard let c = try await card else { load = .missing; return }
            load = .loaded(c, try await me)
        } catch {
            if !error.isCancellation { load = .failed(error.localizedDescription) }
        }
    }

    // You already play for this college.
    public var isHere: Bool {
        if case let .loaded(c, me) = load { return me.collegeId == c.id }
        return false
    }

    // You play for another college: joining moves you.
    public var otherCollege: String? {
        if case let .loaded(c, me) = load, let mine = me.collegeId, mine != c.id { return me.college ?? "another college" }
        return nil
    }

    // Join, then straight into an Aptitude Quick Match.
    public func join() async {
        joining = true
        error = nil
        do {
            _ = try await api.joinCollege(id)
            router?.reload()
            router?.open(.matchmaking(nil))
        } catch {
            if !error.isCancellation { self.error = error.localizedDescription }
        }
        joining = false
    }

    public func play() { router?.open(.matchmaking(nil)) }
    public func seeBoard() { router?.close(to: .ranks) }
    public func close() { router?.close() }
}
