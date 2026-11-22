import AppCore
import Domain
import Foundation
import Testing
@testable import LeaderboardFeature
@testable import NetworkingFakes

// Campus links opened in the app (0029_campus_links.sql): the college's
// page, joining its board, and the move from another college.
@MainActor
struct CampusJoinTests {
    let backend = FakeBackend(latency: .zero)
    let router = AppRouter()

    @Test func aLinkOpensItsCollege() {
        router.handle(URL(string: "https://www.playapticks.in/join/101-mit")!)
        #expect(router.flow?.screen == .campus(101))
    }

    @Test func aNewPlayerJoinsAndGoesStraightToADuel() async throws {
        router.open(.campus(1))
        let model = CampusJoinViewModel(id: 1, api: backend, router: router)
        await model.fetch()
        guard case let .loaded(card, _) = model.load else { Issue.record("expected the college"); return }
        #expect(card.name == "VIT Vellore")
        #expect(card.top.count == 3)
        #expect(!model.isHere && model.otherCollege == nil)
        await model.join()
        #expect(try await backend.me().collegeId == 1)
        #expect(router.flow?.screen == .matchmaking(nil))
    }

    @Test func someoneFromAnotherCollegeIsToldBeforeMoving() async throws {
        backend.start(as: "Asha", rating: 1342, collegeId: 2, gradYear: 2027)
        let model = CampusJoinViewModel(id: 102, api: backend, router: router)
        await model.fetch()
        #expect(model.otherCollege == "IIT Bombay")
        await model.join()
        let me = try await backend.me()
        #expect(me.collegeId == 102)
        #expect(me.college == "University of Oxford")
    }

    @Test func alreadyThereJustPlays() async {
        backend.start(as: "Asha", rating: 1342, collegeId: 1, gradYear: 2027)
        let model = CampusJoinViewModel(id: 1, api: backend, router: router)
        await model.fetch()
        #expect(model.isHere)
    }

    @Test func anUnknownCollegeIsMissing() async {
        let model = CampusJoinViewModel(id: 999_999, api: backend, router: router)
        await model.fetch()
        #expect(model.load == .missing)
    }

    // Ranks knows your college's id, for its campus link.
    @Test func ranksKnowsYourCollege() async {
        backend.start(as: "Asha", rating: 1342, collegeId: 1, gradYear: 2027)
        let model = LeaderboardViewModel(api: backend, router: router)
        await model.load()
        #expect(model.collegeId == 1)
        #expect(Links.campus(1, name: "VIT Vellore") == "https://www.playapticks.in/join/1-vit-vellore")
    }
}
