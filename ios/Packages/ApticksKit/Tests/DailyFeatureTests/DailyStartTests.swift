import AppCore
import Domain
import Foundation
import NetworkingFakes
import Testing
@testable import DailyFeature

@MainActor
struct DailyStartTests {
    private func dailyRuns(_ backend: FakeBackend) async throws -> [DuelSummary] {
        try await backend.myDuels(limit: 50).filter { $0.mode == .daily }
    }

    @Test func openingTheTabDoesNotStartTodaysRun() async throws {
        let backend = FakeBackend(latency: .zero)
        let model = DailyViewModel(api: backend, router: AppRouter())
        await model.load()
        #expect(model.error == nil)
        #expect(model.ready)
        #expect(model.duel == nil)
        // Looking at the Daily isn't a game: no run exists yet.
        #expect(try await dailyRuns(backend).isEmpty)
    }

    @Test func startMakesTheRunAndOpensIt() async throws {
        let backend = FakeBackend(latency: .zero)
        let router = AppRouter()
        let model = DailyViewModel(api: backend, router: router)
        await model.load()
        await model.start()
        let runs = try await dailyRuns(backend)
        #expect(runs.count == 1)
        #expect(router.flow?.screen == .duel(runs[0].id))
        // Pressing Start again (say, after leaving mid-run) resumes the same run.
        router.close()
        await model.start()
        #expect(try await dailyRuns(backend).count == 1)
        #expect(router.flow?.screen == .duel(runs[0].id))
    }

    @Test func aFinishedDailyShowsItsScoreAndOpensTheResult() async throws {
        let backend = FakeBackend(latency: .zero)
        let id = try await backend.dailyChallenge().duelId
        for i in 0..<5 {
            _ = try await backend.nextQuestion(id)
            _ = try await backend.submitAnswer(id, question: i, choice: 0)
        }
        let router = AppRouter()
        let model = DailyViewModel(api: backend, router: router)
        await model.load()
        #expect(model.finished)
        #expect(!model.ready)
        #expect(model.duel?.id == id)
        model.open()
        #expect(router.flow?.screen == .result(id))
    }
}
