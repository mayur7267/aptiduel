import AppCore
import Domain
import Foundation
import Networking

// Anyone's profile, as other players see it (port of web/src/app/u/[id]):
// who they are, how they play, and your own record against them.
@MainActor
@Observable
public final class PlayerProfileViewModel {
    public enum Load: Equatable {
        case loading
        case loaded(PublicProfile)
        case missing
        case failed(String)
    }

    public let id: String
    public private(set) var load: Load = .loading

    private let api: any APIClient
    private let router: AppRouter

    public init(id: String, api: any APIClient, router: AppRouter) {
        self.id = id
        self.api = api
        self.router = router
    }

    public func fetch() async {
        do {
            load = try await api.profile(id).map(Load.loaded) ?? .missing
        } catch {
            load = .failed(error.localizedDescription)
        }
    }

    // A live room to send them (guests sign in first).
    public func duel() { router.open(.newRoom) }
    public func quickMatch() { router.open(.matchmaking(nil)) }
    public func editMine() { router.close(to: .profile) }
    public func close() { router.close() }

    // A guest is "Player 1234": the whole name, not just "Player".
    static func shortName(_ name: String) -> String {
        isGuestName(name) ? name : String(name.split(separator: " ").first ?? Substring(name))
    }
}
