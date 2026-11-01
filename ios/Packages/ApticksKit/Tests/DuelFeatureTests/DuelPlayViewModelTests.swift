import AppCore
import Domain
import Foundation
import NetworkingFakes
import Testing
@testable import DuelFeature

// Whole duels against the in-memory backend, with time standing still and
// waits that return at once.
@MainActor
struct DuelPlayViewModelTests {
    let backend = FakeBackend(latency: .zero)
    let router = AppRouter()

    private func startQuickMatch() async throws -> DuelPlayViewModel {
        let start = try await backend.quickMatch()
        router.open(.duel(start.duelId))
        let model = DuelPlayViewModel(duelId: start.duelId, api: backend, router: router, sleep: { _ in })
        await model.load()
        return model
    }

    @Test func loadsTheFirstQuestion() async throws {
        let model = try await startQuickMatch()
        #expect(model.phase == .question)
        #expect(model.question?.qIndex == 0)
        #expect(model.marks.isEmpty)
        #expect(model.remainingMs > 39_000)
        #expect(model.duel?.opponent?.isBot == true)
    }

    @Test func rightAnswerScoresAndMovesOn() async throws {
        let model = try await startQuickMatch()
        await model.submit(1) // 25%
        #expect(model.phase == .reveal)
        #expect(model.result?.correct == true)
        #expect(model.marks == [.right])
        #expect(model.score >= 100)
        await model.settle()
        #expect(model.question?.qIndex == 1)
        #expect(model.phase == .question)
        #expect(model.oppRevealed == 0)
    }

    @Test func wrongAnswerShowsTheRightOne() async throws {
        let model = try await startQuickMatch()
        await model.submit(0)
        #expect(model.result?.correct == false)
        #expect(model.result?.correctIdx == 1)
        #expect(model.marks == [.wrong])
        #expect(model.score == 0)
    }

    @Test func answersOnlyOncePerQuestion() async throws {
        let model = try await startQuickMatch()
        await model.submit(1)
        await model.submit(2) // ignored: already answered
        #expect(model.marks == [.right])
    }

    @Test func aFullRunEndsOnTheResult() async throws {
        let model = try await startQuickMatch()
        for choice in [1, 2, 1, 3, 1] { // one wrong: Figure Series is A
            await model.submit(choice)
            await model.settle()
        }
        #expect(router.flow?.screen == .result(model.duelId))
        let duel = try await backend.duel(model.duelId)
        #expect(duel.me.finished)
        #expect(duel.me.correct == 4)
        #expect(duel.outcome != nil)
    }

    @Test func runningOutOfTimeCountsAsUnanswered() async throws {
        var now = Date()
        let start = try await backend.quickMatch()
        backend.now = { now }
        let model = DuelPlayViewModel(duelId: start.duelId, api: backend, router: router, now: { now }, sleep: { _ in now += 41 })
        await model.load()
        await model.runClock()
        #expect(model.chosen == nil)
        #expect(model.result?.correct == false)
        #expect(model.marks == [.wrong])
    }

    @Test func restoresAnswersFromBefore() async throws {
        let first = try await startQuickMatch()
        await first.submit(1)
        // Coming back to the same duel later.
        let again = DuelPlayViewModel(duelId: first.duelId, api: backend, router: router, sleep: { _ in })
        await again.load()
        #expect(again.marks == [.right])
        #expect(again.question?.qIndex == 1)
    }

    // An answer that never reached the server can be sent again after Retry.
    @Test func retryAfterAFailedAnswerCanAnswerAgain() async throws {
        let model = try await startQuickMatch()
        backend.offline = true
        await model.submit(1)
        #expect(model.error != nil)
        backend.offline = false
        await model.retry()
        #expect(model.phase == .question)
        #expect(model.question?.qIndex == 0)
        await model.submit(1)
        #expect(model.result?.correct == true)
        #expect(model.marks == [.right])
    }

    @Test func leavingClosesTheFlow() async throws {
        let model = try await startQuickMatch()
        model.leave()
        #expect(router.flow == nil)
    }
}

@MainActor
struct MatchmakingViewModelTests {
    @Test func findsABotThenCountsDownIntoTheDuel() async {
        let backend = FakeBackend(latency: .zero)
        let router = AppRouter()
        router.open(.matchmaking(nil))
        let model = MatchmakingViewModel(company: nil, api: backend, router: router, sleep: { _ in }, searchTime: 0...0)
        await model.find()
        #expect(model.duel?.opponent?.name == "Bolt")
        #expect(!model.resumed)
        await model.runCountdown()
        #expect(model.count == 1)
        #expect(router.flow?.screen == .duel(model.duel!.id))
    }

    // Regression: with real waiting, the countdown must resume on the main
    // actor (a closure-literal default once resumed it on a background
    // thread, and the router's animation crashed).
    @Test func realCountdownStaysOnTheMainActor() async {
        let backend = FakeBackend(latency: .zero)
        let router = AppRouter()
        let model = MatchmakingViewModel(company: nil, api: backend, router: router, searchTime: 0...0)
        await model.find()
        await model.runCountdown()
        MainActor.assertIsolated()
        #expect(router.flow != nil)
    }

    @Test func companyPracticeUsesThatCompany() async {
        let backend = FakeBackend(latency: .zero)
        let infosys = COMPANIES[1]
        let model = MatchmakingViewModel(company: infosys, api: backend, router: AppRouter(), sleep: { _ in }, searchTime: 0...0)
        #expect(model.label == "Infosys practice")
        await model.find()
        #expect(model.duel?.company == "Infosys")
    }
}
