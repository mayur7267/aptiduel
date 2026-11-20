import AppCore
import Domain
import Foundation
import Networking
import Testing
@testable import ChallengeFeature
@testable import DuelFeature
@testable import NetworkingFakes

// Friend duels in a subject (0023_room_subjects.sql): a room opens in the
// subject open on Home, the host can switch it until the friend is in, and
// the questions, the invite and a rematch follow it.
@MainActor
struct RoomSubjectTests {
    let backend = FakeBackend(latency: .zero)
    let router = AppRouter()

    private func member() async throws {
        try await backend.sendSaveCode("asha@test.local")
        try await backend.confirmSaveCode("asha@test.local", code: "123456")
    }

    @Test func aRoomOpensInTheSubjectOpenOnHome() async throws {
        try await member()
        router.open(.newRoom)
        let model = NewRoomViewModel(api: backend, account: backend, router: router, subject: { .coding })
        await model.load()
        guard case let .challenge(code) = router.flow?.screen else { Issue.record("expected the lobby"); return }
        let challenge = try #require(try await backend.challenge(code))
        #expect(challenge.subject == .coding)
    }

    @Test func homesTabPicksTheSubject() {
        let defaults = UserDefaults(suiteName: "RoomSubjectTests")!
        defer { defaults.removePersistentDomain(forName: "RoomSubjectTests") }
        #expect(Subject.openOnHome(defaults) == .aptitude)
        defaults.set("coding", forKey: "apticks-subject")
        #expect(Subject.openOnHome(defaults) == .coding)
        defaults.set("english", forKey: "apticks-subject")
        #expect(Subject.openOnHome(defaults) == .english)
        // GK is coming soon: its duel is Aptitude.
        defaults.set("gk", forKey: "apticks-subject")
        #expect(Subject.openOnHome(defaults) == .aptitude)
    }

    @Test func theHostSwitchesUntilTheFriendIsIn() async throws {
        let clock = Clock(Date(timeIntervalSince1970: 1_800_000_000))
        backend.now = { clock.now }
        try await member()
        let room = try await backend.createRoom()
        router.open(.challenge(room.code))
        let lobby = LobbyViewModel(duelId: room.duelId, code: room.code, hostName: "Asha", api: backend, router: router, sleep: { _ in })
        await lobby.refresh()
        #expect(lobby.subject == .aptitude)
        #expect(lobby.canPick)

        // Switching shows at once, and the server agrees.
        await lobby.pick(.coding)
        #expect(lobby.subject == .coding)
        #expect(lobby.pickError == nil)
        #expect(lobby.shareText.contains("live coding duel"))
        await lobby.refresh()
        #expect(lobby.state?.subject == .coding)

        // The race is Coding: the questions come with code.
        clock.now += backend.friendJoinDelay + 0.5
        await lobby.refresh()
        #expect(!lobby.canPick)
        #expect(lobby.subject == .coding)
        await #expect(throws: AppError("Your friend is already in, so the subject is set.")) {
            try await backend.setRoomSubject(room.duelId, .aptitude)
        }
        clock.now += 6
        let duel = DuelPlayViewModel(duelId: room.duelId, api: backend, router: router, now: { clock.now }, sleep: { _ in })
        await duel.load()
        #expect(duel.question?.code != nil)

        // A rematch keeps Coding.
        for k in 0..<5 {
            let right = FakeBackend.codingQuestions[k].correctIdx
            await duel.submit(right)
            await duel.settle()
            clock.now += 1
        }
        clock.now += 30
        let again = try await backend.liveRematch(room.duelId)
        #expect(try await backend.liveState(again.duelId).subject == .coding)
    }

    @Test func onlyTheHostPicks() async throws {
        try await member()
        let joined = try await backend.joinRoom("LIVE77")
        let lobby = LobbyViewModel(duelId: joined.duelId, code: "LIVE77", hostName: "Rohan Mehta", api: backend, router: router, sleep: { _ in })
        await lobby.refresh()
        #expect(!lobby.canPick)
        await lobby.pick(.coding)
        #expect(lobby.subject == .aptitude)
        await #expect(throws: AppError("Only the player who opened the room can change it.")) {
            try await backend.setRoomSubject(joined.duelId, .coding)
        }
    }

    @Test func shareTextsSayWhenItsCoding() {
        #expect(inviteShareText("Asha", "AB12", .coding).hasPrefix("Asha challenged you to a coding duel on Apticks."))
        #expect(inviteShareText("Asha", "AB12").hasPrefix("Asha challenged you to an aptitude duel on Apticks."))
        #expect(liveInviteText("Asha", "AB12", .coding).contains("C, C++, Java, Python or pseudocode"))
        #expect(!challengeShareText("Asha", 4, 95_000, "AB12", .coding).contains("aptitude"))
        #expect(challengeShareText("Asha", 4, 95_000, "AB12").contains("5 placement aptitude questions"))
    }
}
