import Foundation
import Testing
@testable import Domain

struct RulesTests {
    @Test func outcomeByPointsThenTime() {
        #expect(DuelOutcome(myScore: 300, myMs: 90_000, theirScore: 250, theirMs: 60_000) == .win)
        #expect(DuelOutcome(myScore: 300, myMs: 60_000, theirScore: 300, theirMs: 61_000) == .win)
        #expect(DuelOutcome(myScore: 300, myMs: 61_000, theirScore: 300, theirMs: 60_000) == .loss)
        #expect(DuelOutcome(myScore: 300, myMs: 60_000, theirScore: 300, theirMs: 60_000) == .draw)
        #expect(DuelOutcome.win.flipped == .loss)
    }

    private let timeline = [
        TimelineStep(qIndex: 0, ms: 12_000, correct: true, points: 135),
        TimelineStep(qIndex: 1, ms: 20_000, correct: false, points: 0),
    ]

    @Test func replayHidesTheOpponentUntilTheyAnswer() {
        let r = OpponentReplay(timeline: timeline, question: 1, elapsedMs: 5_000, revealed: false)
        #expect(r.marks == [.right])
        #expect(r.score == 135)
        #expect(!r.answeredHere)
    }

    @Test func replayShowsAnsweredButNotWhetherRight() {
        let r = OpponentReplay(timeline: timeline, question: 1, elapsedMs: 21_000, revealed: false)
        #expect(r.marks == [.right, .unknown])
        #expect(r.answeredHere)
    }

    @Test func replayRevealsAfterYouAnswer() {
        let r = OpponentReplay(timeline: timeline, question: 1, elapsedMs: 21_000, revealed: true)
        #expect(r.marks == [.right, .wrong])
    }

    @Test func challengeLinks() {
        #expect(Links.challengeCode(from: URL(string: "apticks://c/AB12CD")!) == "AB12CD")
        #expect(Links.challengeCode(from: URL(string: "https://www.playapticks.in/c/xY9k2")!) == "xY9k2")
        #expect(Links.challengeCode(from: URL(string: "https://www.playapticks.in/leaderboard")!) == nil)
        // Links sent before the new address still open.
        #expect(Links.challengeCode(from: URL(string: "https://aptiduel.vercel.app/c/xY9k2")!) == "xY9k2")
        #expect(Links.challengeCode(from: URL(string: "apticks://c/bad!code")!) == nil)
        #expect(inviteShareText("Asha", "AB12").hasSuffix("https://www.playapticks.in/c/AB12"))
    }

    @Test(arguments: ["https://www.playapticks.in", "https://aptiduel.vercel.app"])
    func websiteLinksOpenTheRightScreen(site: String) {
        let id = "3f2c1a9e-8b7d-4c6e-a5f4-0123456789ab"
        #expect(Links.route(from: URL(string: "\(site)/c/AB12CD")!) == .challenge("AB12CD"))
        #expect(Links.route(from: URL(string: "\(site)/duel/\(id)")!) == .duel(id))
        #expect(Links.route(from: URL(string: "\(site)/duel/\(id)/result")!) == .result(id))
        #expect(Links.route(from: URL(string: "\(site)/duel/not-a-duel")!) == nil)
        #expect(Links.route(from: URL(string: "\(site)/play")!) == .play(nil))
        #expect(Links.route(from: URL(string: "\(site)/play/infosys")!) == .play(company(named: "Infosys")))
        #expect(Links.route(from: URL(string: "\(site)/play/nowhere")!) == nil)
        #expect(Links.route(from: URL(string: "apticks://play")!) == .play(nil))
    }

    // Campus links: /join/<college id>-<name>, from the website or the app's scheme.
    @Test func campusLinks() {
        #expect(Links.route(from: URL(string: "https://www.playapticks.in/join/43-delhi-technological-university")!) == .campus(43))
        #expect(Links.route(from: URL(string: "https://www.playapticks.in/join/43")!) == .campus(43))
        #expect(Links.route(from: URL(string: "apticks://join/28613-jspm")!) == .campus(28613))
        #expect(Links.route(from: URL(string: "https://www.playapticks.in/join/dtu")!) == nil)
        #expect(Links.route(from: URL(string: "https://www.playapticks.in/join")!) == nil)
        // The same address the website makes (web/src/lib/campus.ts).
        #expect(Links.campus(43, name: "Delhi Technological University") == "https://www.playapticks.in/join/43-delhi-technological-university")
        #expect(Links.campusPath(28613, name: "JSPM's Rajarshi Shahu College of Engineering") == "/join/28613-jspm-s-rajarshi-shahu-college-of-engineering")
        #expect(Links.campusPath(7, name: "École Polytechnique") == "/join/7-ecole-polytechnique")
        #expect(campusShareText("DTU", link: "https://x/join/1").hasSuffix("https://x/join/1"))
    }

    @Test func companiesByName() {
        #expect(company(named: "Infosys")?.slug == "infosys")
        #expect(company(named: nil) == nil)
    }
}
