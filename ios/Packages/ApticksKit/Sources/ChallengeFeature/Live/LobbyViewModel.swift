import AppCore
import Domain
import Foundation
import Networking

// Waiting together in a live room (port of web/src/app/c/[code]/
// live-room.tsx). The duel starts by itself once both players are here,
// and the live screen takes over.
@MainActor
@Observable
public final class LobbyViewModel {
    public enum Busy { case playNow, close }

    public let duelId: String
    public let code: String
    public let hostName: String
    public private(set) var state: LiveState?
    public private(set) var error: String?
    public private(set) var busy: Busy?
    public let since: Date

    // How long the host waits before "Play now" is offered.
    static let offerPlayNowAfter: TimeInterval = 45

    private let api: any APIClient
    private let router: AppRouter
    private let sleep: (Duration) async -> Void
    private let now: () -> Date

    public init(duelId: String, code: String, hostName: String, api: any APIClient, router: AppRouter,
                sleep: @escaping (Duration) async -> Void = Wait.real, now: @escaping () -> Date = Date.init) {
        self.duelId = duelId
        self.code = code
        self.hostName = hostName
        self.api = api
        self.router = router
        self.sleep = sleep
        self.now = now
        since = now()
    }

    // About once a second: tells the server you're here, and follows the
    // room until the duel starts.
    public func poll() async {
        while !Task.isCancelled {
            await refresh()
            if let status = state?.status, status != .waiting { return }
            await sleep(.seconds(1))
        }
    }

    func refresh() async {
        do {
            let s = try await api.liveState(duelId)
            state = s
            error = nil
            if s.status == .starting || s.status == .playing || s.status == .done { router.open(.live(duelId)) }
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func playNow() async {
        busy = .playNow
        do {
            router.open(.duel(try await api.livePlayNow(duelId).duelId))
        } catch {
            self.error = error.localizedDescription
            busy = nil
        }
    }

    public func close() async {
        busy = .close
        // Leaving anyway; an unused room just closes after a week.
        try? await api.liveCancel(duelId)
        router.close()
    }

    public func playYourTurn() { router.open(.duel(duelId)) }
    public func leave() { router.close() }

    // MARK: What the lobby says

    var opponent: LivePlayer? { state?.opponent }
    var isHost: Bool { state?.isHost ?? true }

    func offersPlayNow(at date: Date) -> Bool {
        guard state?.status == .waiting else { return false }
        if let opponent, !opponent.present, !isHost { return true }
        return date.timeIntervalSince(since) > Self.offerPlayNowAfter
    }

    var title: String {
        switch state?.status {
        case .async: return "It's a recorded challenge now"
        case .closed: return "This duel was closed"
        default:
            guard let opponent else { return "Waiting for your friend" }
            return opponent.present ? "\(opponent.name) is here!" : "Waiting for \(opponent.name)"
        }
    }

    var line: String {
        switch state?.status {
        case .async:
            return "\(opponent?.name ?? "Your friend") couldn't wait, so they played their turn. Play yours whenever you like: you'll race their run."
        case .closed:
            return "Start a new one from home and send a fresh link."
        default:
            guard let opponent else { return "Send them the link. The duel starts the moment they join." }
            if opponent.present { return "Get ready…" }
            return isHost
                ? "\(opponent.name) joined but stepped away. You'll start as soon as they're back."
                : "\(opponent.name) isn't here right now. You'll start as soon as they open the duel."
        }
    }

    var shareText: String { liveInviteText(state?.me.name ?? hostName, code) }
}
