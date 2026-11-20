import AppCore
import Domain
import Foundation
import Testing
@testable import LeaderboardFeature
@testable import NetworkingFakes
@testable import ProfileFeature

// A rating and a board per subject (0025_subject_ranks.sql).
@MainActor
struct SubjectRanksTests {
    let backend = FakeBackend(latency: .zero)
    let router = AppRouter()

    @Test func eachSubjectHasItsOwnBoard() async throws {
        let model = LeaderboardViewModel(api: backend, router: router)
        model.scope = .india
        await model.load()
        #expect(model.board?.subject == .aptitude)
        let aptitudeTop = model.board?.rows.first?.name
        model.subject = .coding
        #expect(model.board == nil)
        await model.load()
        #expect(model.board?.subject == .coding)
        #expect(model.board?.rows.first?.name != aptitudeTop)
        // Switching back shows the board already loaded.
        model.subject = .aptitude
        #expect(model.board?.rows.first?.name == aptitudeTop)
    }

    @Test func theProfileChartFollowsTheChosenSubject() async throws {
        _ = try await backend.quickMatch(.english)
        let model = ProfileViewModel(api: backend, router: router, sleep: { _ in })
        await model.load()
        #expect(model.subject == .aptitude)
        #expect(model.rating == model.me?.rating)
        #expect(model.subjects?.english != nil)
        model.subject = .english
        #expect(model.rating == model.subjects?.english?.rating)
        #expect(model.ratingHistory.last == model.rating)
    }

    @Test func otherPlayersShowEverySubject() async throws {
        let p = try #require(try await backend.profile("fake-friend"))
        #expect(p.subjects?.coding.rating == 1312)
        #expect(p.subjects?[.english]?.games == 0)
    }

    @Test func boardsAndProfilesFromBeforeSubjectsStillDecode() throws {
        let json = #"{"scope": "india", "college": null, "players": 0, "rows": [], "me": null}"#
        let board = try JSONDecoder().decode(Board.self, from: Data(json.utf8))
        #expect(board.subject == nil)
    }
}
