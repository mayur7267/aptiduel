import AppCore
import Domain
import Foundation
import Testing
@testable import DuelFeature
@testable import NetworkingFakes

// English Quick Match (0024_english.sql): five verbal questions, its own
// rating, and "play again" stays in English.
@MainActor
struct EnglishTests {
    let backend = FakeBackend(latency: .zero)
    let router = AppRouter()

    private func playEnglish() async throws -> String {
        let start = try await backend.quickMatch(.english)
        router.open(.duel(start.duelId))
        let model = DuelPlayViewModel(duelId: start.duelId, api: backend, router: router, sleep: { _ in })
        await model.load()
        #expect(model.question?.section == "verbal")
        #expect(model.question?.code == nil)
        for k in 0..<5 {
            await model.submit(FakeBackend.englishQuestions[k].correctIdx)
            await model.settle()
        }
        return start.duelId
    }

    @Test func matchmakingInEnglishStartsAnEnglishDuel() async {
        let model = MatchmakingViewModel(company: nil, subject: .english, api: backend, router: router, sleep: { _ in }, searchTime: 0...0)
        #expect(model.label == "English Quick Match")
        await model.find()
        #expect(model.duel?.playedSubject == .english)
    }

    @Test func anEnglishDuelMovesOnlyTheEnglishRating() async throws {
        let before = try await backend.mySubjects()
        let id = try await playEnglish()
        let after = try await backend.mySubjects()
        #expect(after.english?.games == (before.english?.games ?? 0) + 1)
        #expect(after.english?.rating != before.english?.rating)
        #expect(after.aptitude.rating == before.aptitude.rating)
        #expect(after.coding.rating == before.coding.rating)
        let result = DuelResultViewModel(duelId: id, api: backend, router: router)
        await result.load()
        #expect(result.duel?.playedSubject.ratingLabel == "English rating")
        result.playAgain()
        #expect(router.flow?.screen == .subjectMatch(.english))
    }

    @Test func storyPictureSaysEnglish() async throws {
        let id = try await playEnglish()
        let duel = try await backend.duel(id)
        #expect(StoryData(duel: duel)?.chip == "ENGLISH MATCH")
    }

    @Test func englishReadsWellEverywhere() {
        #expect(Subject.english.quickMatchName == "English Quick Match")
        #expect(Subject.aptitude.quickMatchName == "Quick Match")
        #expect(Subject.english.duelPhrase == "an English duel")
        #expect(SubjectTab.english.subject == .english)
        #expect(SubjectTab.gk.soon)
        #expect(!SubjectTab.english.soon)
        #expect(inviteShareText("Asha", "AB12", .english).hasPrefix("Asha challenged you to an English duel on Apticks."))
        let defaults = UserDefaults(suiteName: "EnglishTests")!
        defer { defaults.removePersistentDomain(forName: "EnglishTests") }
        defaults.set("english", forKey: "apticks-subject")
        #expect(Subject.openOnHome(defaults) == .english)
        defaults.set("gk", forKey: "apticks-subject")
        #expect(Subject.openOnHome(defaults) == .aptitude)
    }

    @Test func ratingsWithoutEnglishStillDecode() throws {
        let json = #"{"aptitude": {"rating": 1100, "games": 4}, "coding": {"rating": 1000, "games": 0}}"#
        let ratings = try JSONDecoder().decode(SubjectRatings.self, from: Data(json.utf8))
        #expect(ratings.english == nil)
        #expect(ratings[.coding]?.rating == 1000)
    }
}
