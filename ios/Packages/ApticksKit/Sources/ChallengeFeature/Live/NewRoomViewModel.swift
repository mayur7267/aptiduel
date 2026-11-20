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
    private let subject: () -> Subject

    // The room starts in the subject open on Home; the host can switch it
    // in the lobby.
    public init(api: any APIClient, account: any AccountClient, router: AppRouter,
                subject: @escaping () -> Subject = { Subject.openOnHome() }) {
        self.api = api
        self.account = account
        self.router = router
        self.subject = subject
        signIn = SignInModel(account: account) { [weak self] in await self?.open() }
    }

    public func load() async {
        let guest = (try? await account.info())?.guest ?? true
        if guest { step = .signIn } else { await open() }
    }

    public func open() async {
        step = .opening
        do {
            let room = try await api.createRoom(subject())
            router.open(.challenge(room.code))
        } catch {
            step = .failed(error.localizedDescription)
        }
    }

    public func close() { router.close() }
}
