import AppCore
import Domain
import Foundation
import NetworkingFakes
import Testing
@testable import DuelFeature

// A Quick Match in Coding (0022_subjects.sql), against the in-memory backend.
@MainActor
struct CodingTests {
    let backend = FakeBackend(latency: .zero)
    let router = AppRouter()

    private func playCoding() async throws -> String {
        let start = try await backend.quickMatch(.coding)
        router.open(.duel(start.duelId))
        let model = DuelPlayViewModel(duelId: start.duelId, api: backend, router: router, sleep: { _ in })
        await model.load()
        for _ in 0..<5 {
            await model.submit(0)
            await model.settle()
        }
        return start.duelId
    }

    @Test func matchmakingInCodingStartsACodingDuel() async {
        let model = MatchmakingViewModel(company: nil, subject: .coding, api: backend, router: router, sleep: { _ in }, searchTime: 0...0)
        #expect(model.label == "Coding Quick Match")
        await model.find()
        #expect(model.duel?.isCoding == true)
    }

    @Test func aptitudeMatchmakingStaysAptitude() async {
        let model = MatchmakingViewModel(company: nil, api: backend, router: router, sleep: { _ in }, searchTime: 0...0)
        #expect(model.label == "Quick Match")
        await model.find()
        #expect(model.duel?.isCoding == false)
    }

    @Test func codingQuestionsCarryTheProgramInEveryLanguage() async throws {
        let start = try await backend.quickMatch(.coding)
        let model = DuelPlayViewModel(duelId: start.duelId, api: backend, router: router, sleep: { _ in })
        await model.load()
        let code = try #require(model.question?.code)
        #expect(model.question?.section == "coding")
        for lang in CodeLang.allCases { #expect(!code.text(lang).isEmpty) }
        #expect(code.java.contains("System.out.print"))
    }

    @Test func aCodingDuelMovesOnlyTheCodingRating() async throws {
        let before = try await backend.mySubjects()
        let id = try await playCoding()
        let after = try await backend.mySubjects()
        #expect(after.coding.games == before.coding.games + 1)
        #expect(after.coding.rating != before.coding.rating)
        #expect(after.aptitude.rating == before.aptitude.rating)
        let duel = try await backend.duel(id)
        #expect(duel.review?.count == 5)
        #expect(duel.review?.allSatisfy { $0.code != nil } == true)
    }

    @Test func playingAgainAfterCodingStaysInCoding() async throws {
        let id = try await playCoding()
        let result = DuelResultViewModel(duelId: id, api: backend, router: router)
        await result.load()
        result.playAgain()
        #expect(router.flow?.screen == .subjectMatch(.coding))
    }

    @Test func storyPictureSaysCoding() async throws {
        let id = try await playCoding()
        let duel = try await backend.duel(id)
        #expect(StoryData(duel: duel)?.chip == "CODING MATCH")
    }

    // Colouring never adds, drops or reorders a character.
    @Test func highlightingKeepsTheCodeExactlyAsWritten() {
        let lines = ["for (int i = 1; i <= 4; i++) s += i; // sum", "print(s, end=\" \")", "x = x mod 10 # not a comment in C"]
        for lang in CodeLang.allCases {
            for line in lines {
                #expect(String(CodeBlock.highlight(line, lang).characters) == line)
            }
        }
    }
}
