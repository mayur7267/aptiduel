import AppCore
import Domain
import Foundation
import NetworkingFakes
import Testing
import Tiko
@testable import HomeFeature

@MainActor
struct HomeViewModelTests {
    let backend = FakeBackend(latency: .zero)
    let router = AppRouter()

    @Test func loadsHome() async {
        let model = HomeViewModel(api: backend, router: router)
        await model.load()
        #expect(model.me != nil)
        #expect(model.board != nil)
        #expect(!model.duels.isEmpty)
        #expect(model.error == nil)
    }

    @Test func nudgesAnUnplayedStreak() async {
        let model = HomeViewModel(api: backend, router: router)
        await model.load()
        // The fake player has a 2-day streak and hasn't played today.
        #expect(model.nudge.mood == .think)
        #expect(model.nudge.say == "Your 2-day streak needs a duel today!")
    }

    @Test func duelingAFriendOpensARoom() async {
        let model = HomeViewModel(api: backend, router: router)
        model.startChallenge()
        #expect(router.flow?.screen == .newRoom)
    }

    @Test func latestChallengeLastsAWeek() async throws {
        let model = HomeViewModel(api: backend, router: router)
        _ = try await backend.createChallenge()
        await model.load()
        #expect(model.latestChallenge(now: Date())?.code != nil)
        #expect(model.latestChallenge(now: Date().addingTimeInterval(8 * 86_400)) == nil)
    }

    @Test func aDriveCountsDownThenAsksHowItWent() async throws {
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        backend.now = { clock }
        let model = DriveViewModel(api: backend, router: router, now: { clock })
        await model.load()
        #expect(model.stage == .unset)
        #expect(model.showsForm)

        // Set it: TCS NQT, 12 days out.
        model.company = "TCS NQT"
        model.date = clock.addingTimeInterval(12 * 86_400)
        await model.save()
        #expect(model.stage == .upcoming(days: 12))
        #expect(model.drive?.weakTopics == ["Probability", "Syllogisms"])
        model.practise()
        #expect(router.flow?.screen == .matchmaking(company(named: "TCS NQT")))

        // The day after: two taps on how it went.
        clock = clock.addingTimeInterval(13 * 86_400)
        await model.load()
        #expect(model.asksHowItWent)
        await model.answer("yes")
        #expect(model.cleared == "yes")
        await model.finish(difficulty: "harder")
        #expect(model.stage == .answered)
        #expect(model.drive?.cleared == "yes")

        // And on to the next one.
        model.startEditing()
        #expect(model.showsForm)
        await model.clear()
        #expect(model.stage == .unset)
    }

    @Test func aDriveCanNotBeReportedEarly() async throws {
        let model = DriveViewModel(api: backend, router: router)
        model.company = DriveViewModel.other
        model.otherCompany = "Zoho"
        await model.save()
        #expect(model.drive?.company == "Zoho")
        #expect(model.stage == .upcoming(days: 14))
        await #expect(throws: (any Error).self) { try await backend.submitDriveResult(cleared: "yes", difficulty: nil) }
    }

    @Test func dailyOpensTheDuel() async {
        let model = HomeViewModel(api: backend, router: router)
        await model.startDaily()
        guard case let .duel(id) = router.flow?.screen else { Issue.record("expected a duel"); return }
        #expect(id.contains("daily"))
    }

    @Test func recentDuelLines() async throws {
        let duels = try await backend.myDuels(limit: 8)
        let won = try #require(duels.first { $0.id == "fake-history-1" })
        let line = DuelLine(won)
        #expect(line.status.text == "Won 🏆")
        #expect(line.score == "486 – 371")
        #expect(line.delta == 16)
        #expect(line.sub == "NIT Trichy")
    }
}
