import AppCore
import Domain
import Foundation
import Networking

// Opening a live room from home (or someone's profile): guests sign in
// first, then the room opens and its lobby takes over.
@MainActor
@Observable
public final class NewRoomViewModel {
    public enum Step: Equatable {
        case checking, signIn, opening
        case failed(String)
    }

    public private(set) var step: Step = .checking
    public private(set) var signIn: SignInModel!

    private let api: any APIClient
    private let account: any AccountClient
    private let router: AppRouter

    public init(api: any APIClient, account: any AccountClient, router: AppRouter) {
        self.api = api
        self.account = account
        self.router = router
        signIn = SignInModel(account: account) { [weak self] in await self?.open() }
    }

    public func load() async {
        let guest = (try? await account.info())?.guest ?? true
        if guest { step = .signIn } else { await open() }
    }

    public func open() async {
        step = .opening
        do {
            let room = try await api.createRoom()
            router.open(.challenge(room.code))
        } catch {
            step = .failed(error.localizedDescription)
        }
    }

    public func close() { router.close() }
}
