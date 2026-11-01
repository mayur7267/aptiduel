import AppCore
import Domain
import Foundation
import Networking
import Testing
@testable import ChallengeFeature
@testable import DuelFeature
@testable import NetworkingFakes
@testable import ProfileFeature

// Live friend duels end to end against the in-memory backend: opening a
// room (signing in first), the lobby, five lockstep questions with a
// pretend friend, the result and a rematch. Time only moves when a test
// moves it.
@MainActor
struct LiveDuelTests {
    let backend = FakeBackend(latency: .zero)
    let router = AppRouter()

    private func signIn(_ model: SignInModel) async {
        model.email = "asha@test.local"
        await model.sendCode()
        model.code = "123456"
        await model.confirm()
    }

    private func member() async throws {
        try await backend.sendSaveCode("asha@test.local")
        try await backend.confirmSaveCode("asha@test.local", code: "123456")
    }

    @Test func guestsSignInBeforeOpeningARoom() async throws {
        router.open(.newRoom)
        let model = NewRoomViewModel(api: backend, account: backend, router: router)
        await model.load()
        #expect(model.step == .signIn)
        await signIn(model.signIn)
        guard case let .challenge(code) = router.flow?.screen else { Issue.record("expected the room's lobby"); return }
        #expect(code.hasPrefix("LIVE"))
    }

    @Test func guestsCanNotOpenARoomDirectly() async {
        await #expect(throws: AppError("Sign in to duel friends.")) { try await backend.createRoom() }
    }

    @Test func aFriendsLinkSignsInThenJoins() async throws {
        router.open(.challenge("LIVE77"))
        let model = ChallengeViewModel(code: "LIVE77", api: backend, account: backend, router: router, sleep: { _ in })
        await model.load()
        #expect(model.challenge?.live == true)
        #expect(model.guest)
        #expect(model.lobby == nil)
        model.startSignIn()
        await signIn(try #require(model.signIn))
        let lobby = try #require(model.lobby)
        // The host is already waiting, so the countdown starts.
        await lobby.refresh()
        #expect(router.flow?.screen == .live(lobby.duelId))
    }

    @Test func aLiveRaceFromLobbyToRematch() async throws {
        let clock = Clock(Date(timeIntervalSince1970: 1_800_000_000))
        backend.now = { clock.now }
        try await member()

        // The lobby: waiting until the friend arrives.
        let room = try await backend.createRoom()
        router.open(.challenge(room.code))
        let challenge = ChallengeViewModel(code: room.code, api: backend, account: backend, router: router, sleep: { _ in })
        await challenge.load()
        let lobby = try #require(challenge.lobby)
        await lobby.refresh()
        #expect(lobby.state?.status == .waiting)
        #expect(lobby.title == "Waiting for your friend")
        clock.now += backend.friendJoinDelay + 0.5
        await lobby.refresh()
        #expect(router.flow?.screen == .live(room.duelId))

        // The countdown, then the race starts on the duel screen.
        let start = LiveStartViewModel(duelId: room.duelId, api: backend, router: router, sleep: { _ in }, clock: { clock.now })
        await start.refresh()
        #expect(start.state?.status == .starting)
        #expect(start.secondsLeft > 3)
        let startsAt = Double(try #require(start.state?.startsAtMs)) / 1000
        clock.now = Date(timeIntervalSince1970: startsAt + 0.4)
        await start.refresh()
        #expect(router.flow?.screen == .duel(room.duelId))

        // The first question opened at the start, for both.
        let duel = DuelPlayViewModel(duelId: room.duelId, api: backend, router: router, now: { clock.now }, sleep: { _ in })
        await duel.load()
        #expect(duel.isLive)
        #expect(duel.question?.qIndex == 0)
        #expect(duel.remainingMs <= backend.timeLimitMs - 400)

        // You race ahead, with no waiting between questions.
        for k in 0..<5 {
            #expect(duel.question?.qIndex == k)
            let right = FakeBackend.questions[k].correctIdx
            await duel.submit(k == 1 ? (right + 1) % 4 : right)
            await duel.settle()
            clock.now += 1
        }
        #expect(router.flow?.screen == .result(room.duelId))

        // Done first: the result waits for the friend, showing their progress.
        let result = DuelResultViewModel(duelId: room.duelId, api: backend, router: router, sleep: { _ in })
        await result.load()
        #expect(result.isLive)
        #expect(result.duel?.awaitingOpponent == true)
        #expect(result.duel?.opponent?.answered ?? 0 < 5)
        let race = try await backend.liveState(room.duelId)
        #expect(race.status == .playing)
        #expect(race.me.finished)
        #expect(race.opponent?.finished == false)

        // Once they finish: the outcome, and a rematch (the same room twice).
        clock.now += 30
        await result.load()
        #expect(result.duel?.outcome != nil)
        #expect(try await backend.liveState(room.duelId).status == .done)
        await result.rematchLive()
        guard case let .challenge(code) = router.flow?.screen else { Issue.record("expected the rematch lobby"); return }
        #expect(try await backend.liveRematch(room.duelId).code == code)
    }

    @Test func opponentProgressShowsDuringTheRace() async throws {
        let clock = Clock(Date(timeIntervalSince1970: 1_800_000_000))
        backend.now = { clock.now }
        try await member()
        let joined = try await backend.joinRoom("LIVE42") // a friend's room: they're already there
        clock.now += 5.2
        let duel = DuelPlayViewModel(duelId: joined.duelId, api: backend, router: router, now: { clock.now }, sleep: { _ in })
        await duel.load()
        #expect(duel.question?.qIndex == 0)
        // The friend answers their first two in about 10 s.
        clock.now += 10
        let race = try await backend.liveState(joined.duelId)
        #expect(race.opponent?.answered == 2)
        #expect(race.opponent?.marks == [true, false])
        #expect(race.me.answered == 0)
    }

    @Test func questionsWaitForTheCountdown() async throws {
        let clock = Clock(Date(timeIntervalSince1970: 1_800_000_000))
        backend.now = { clock.now }
        try await member()
        let room = try await backend.createRoom()
        clock.now += backend.friendJoinDelay + 1
        router.open(.duel(room.duelId))
        let duel = DuelPlayViewModel(duelId: room.duelId, api: backend, router: router, now: { clock.now }, sleep: { _ in })
        await duel.load()
        #expect(router.flow?.screen == .live(room.duelId))
        #expect(duel.error == nil)
    }

    @Test func playNowTurnsTheRoomIntoAChallenge() async throws {
        try await member()
        let room = try await backend.createRoom()
        router.open(.challenge(room.code))
        let lobby = LobbyViewModel(duelId: room.duelId, code: room.code, hostName: "Asha", api: backend, router: router, sleep: { _ in })
        await lobby.playNow()
        #expect(router.flow?.screen == .duel(room.duelId))
        let duel = DuelPlayViewModel(duelId: room.duelId, api: backend, router: router, sleep: { _ in })
        await duel.load()
        #expect(duel.question?.qIndex == 0)
    }

    @Test func profilesShowYourRecordAgainstThem() async throws {
        router.open(.player("fake-friend"))
        let model = PlayerProfileViewModel(id: "fake-friend", api: backend, router: router)
        await model.fetch()
        guard case let .loaded(p) = model.load else { Issue.record("expected a profile"); return }
        #expect(p.vsMe?.played == 3)
        #expect(p.winRate == 63)
        let missing = PlayerProfileViewModel(id: "missing", api: backend, router: router)
        await missing.fetch()
        #expect(missing.load == .missing)
        #expect(PlayerProfileViewModel.shortName("Player 1234") == "Player 1234")
        #expect(PlayerProfileViewModel.shortName("Kavya R") == "Kavya")
    }
}

// A clock the test moves by hand.
@MainActor
final class Clock {
    var now: Date
    init(_ now: Date) { self.now = now }
}
