import AppCore
import Domain
import Foundation
import Networking

// Both players are in: see each other, count down together, then the
// race starts on the duel screen at the same moment for both (port of
// web/src/app/live/[id]/live-start.tsx).
@MainActor
@Observable
public final class LiveStartViewModel {
    public let duelId: String
    public private(set) var state: LiveState?
    public private(set) var error: String?
    // The server's clock, ticking.
    public private(set) var now = Date()

    private var offset: TimeInterval = 0 // server seconds minus this device's
    private var left = false
    private let api: any APIClient
    private let router: AppRouter
    private let sleep: (Duration) async -> Void
    private let clock: () -> Date

    public init(duelId: String, api: any APIClient, router: AppRouter,
                sleep: @escaping (Duration) async -> Void = Wait.real, clock: @escaping () -> Date = Date.init) {
        self.duelId = duelId
        self.api = api
        self.router = router
        self.sleep = sleep
        self.clock = clock
    }

    var serverNow: Date { clock().addingTimeInterval(offset) }

    public func poll() async {
        while !Task.isCancelled, !left {
            await refresh()
            await sleep(.milliseconds(700))
        }
    }

    public func runClock() async {
        while !Task.isCancelled, !left {
            now = serverNow
            startIfTime()
            await sleep(.milliseconds(100))
        }
    }

    func refresh() async {
        let sentAt = clock()
        do {
            let s = try await api.liveState(duelId)
            // The server read its clock about halfway through the round trip.
            let midway = sentAt.addingTimeInterval(clock().timeIntervalSince(sentAt) / 2)
            offset = Double(s.nowMs) / 1000 - midway.timeIntervalSince1970
            state = s
            now = serverNow
            error = nil
            switch s.status {
            case .waiting, .closed: go(.challenge(s.code))
            case .async, .playing: go(.duel(duelId))
            case .done: go(.result(duelId))
            case .starting: startIfTime()
            }
        } catch {
            if state == nil { self.error = error.localizedDescription }
        }
    }

    // A moment after the start, so the server has opened the first question.
    func startIfTime() {
        guard state?.status == .starting, let at = state?.startsAtMs else { return }
        if now.timeIntervalSince1970 * 1000 > Double(at) + 250 { go(.duel(duelId)) }
    }

    private func go(_ screen: Screen) {
        guard !left else { return }
        left = true
        router.open(screen)
    }

    public func retry() async {
        error = nil
        await refresh()
    }

    public func leave() { router.close() }

    public var secondsLeft: Int {
        guard let at = state?.startsAtMs else { return 5 }
        return max(0, Int((Double(at) / 1000 - now.timeIntervalSince1970).rounded(.up)))
    }
}
