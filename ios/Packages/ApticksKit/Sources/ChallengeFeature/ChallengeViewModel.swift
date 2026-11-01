import AppCore
import Domain
import Foundation
import Networking
import Tiko

// A challenge link opened in the app (port of web/src/app/c/[code]).
// A live room shows its lobby to players in it, and the invite (with a
// sign-in step for guests) to anyone else. A recorded challenge shows the
// invite to friends and the challenger's own side to the challenger.
@MainActor
@Observable
public final class ChallengeViewModel {
    public let code: String
    public private(set) var status: ChallengeStatus? // set when you're the challenger
    public private(set) var challenge: Challenge?
    public private(set) var loaded = false
    public private(set) var error: String?
    public private(set) var accepting = false
    public private(set) var acceptError: String?
    // Live rooms: the lobby once you're in, and the sign-in step for guests.
    public private(set) var lobby: LobbyViewModel?
    public private(set) var guest = true
    public private(set) var signIn: SignInModel?

    private let api: any APIClient
    private let account: any AccountClient
    private let router: AppRouter
    private let sleep: (Duration) async -> Void

    public init(code: String, api: any APIClient, account: any AccountClient, router: AppRouter,
                sleep: @escaping (Duration) async -> Void = Wait.real) {
        self.code = code
        self.api = api
        self.account = account
        self.router = router
        self.sleep = sleep
    }

    public func load() async {
        do {
            if let s = try await api.challengeStatus(code) {
                status = s
            } else {
                challenge = try await api.challenge(code)
            }
            if let challenge, challenge.live == true {
                guest = (try? await account.info())?.guest ?? true
                // Already in the room (you opened it, or joined before).
                if challenge.mySeat != nil { await joinLive() }
            }
            loaded = true
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // Keep the challenger's view fresh as friends play.
    public func poll() async {
        while status != nil, !Task.isCancelled {
            await sleep(.seconds(10))
            if Task.isCancelled { return }
            if let s = try? await api.challengeStatus(code) { status = s }
        }
    }

    public func accept() async {
        accepting = true
        acceptError = nil
        do {
            router.open(.duel(try await api.joinChallenge(code).duelId))
        } catch {
            acceptError = error.localizedDescription
            accepting = false
        }
    }

    // Join a live room. One nobody waited for is an ordinary challenge now,
    // so you play your turn.
    public func joinLive() async {
        accepting = true
        acceptError = nil
        do {
            let joined = try await api.joinRoom(code)
            if joined.mode == .challenge {
                router.open(.duel(joined.duelId))
            } else {
                lobby = LobbyViewModel(duelId: joined.duelId, code: code.uppercased(), hostName: challenge?.challenger.name ?? "",
                                       api: api, router: router, sleep: sleep)
            }
        } catch {
            acceptError = error.localizedDescription
        }
        accepting = false
    }

    public func startSignIn() {
        signIn = SignInModel(account: account) { [weak self] in
            guard let self else { return }
            guest = false
            signIn = nil
            router.reload()
            await joinLive()
        }
    }

    var ownerTitle: String {
        let friends = status?.friends ?? []
        return friends.isEmpty ? "Waiting for your friend" : friends.count == 1 ? "\(friends[0].name) is in" : "\(friends.count) friends are in"
    }

    // The challenger's Tiko waits with you, points you to your turn, then
    // cheers or sulks.
    var ownerMood: TikoMood {
        guard let status else { return .think }
        let me = status.me
        let settled = status.friends.filter { $0.finished && me.finished }
        let lostOne = settled.contains {
            DuelOutcome(myScore: me.score, myMs: me.totalMs, theirScore: $0.score, theirMs: $0.totalMs) == .loss
        }
        if status.friends.isEmpty { return .think }
        if !me.finished { return .point }
        return settled.isEmpty ? .think : lostOne ? .sad : .cheer
    }

    var shareText: String {
        guard let status else { return "" }
        let me = status.me
        return me.finished ? challengeShareText(me.name, me.correct, me.totalMs, code) : inviteShareText(me.name, code)
    }

    public func open(_ screen: Screen) { router.open(screen) }
    public func close() { router.close() }
}
