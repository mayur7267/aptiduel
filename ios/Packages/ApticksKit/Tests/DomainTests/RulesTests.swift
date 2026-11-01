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
        #expect(Links.challengeCode(from: URL(string: "https://aptiduel.vercel.app/c/xY9k2")!) == "xY9k2")
        #expect(Links.challengeCode(from: URL(string: "https://aptiduel.vercel.app/leaderboard")!) == nil)
        #expect(Links.challengeCode(from: URL(string: "apticks://c/bad!code")!) == nil)
        #expect(inviteShareText("Asha", "AB12").hasSuffix("https://aptiduel.vercel.app/c/AB12"))
    }

    @Test func websiteLinksOpenTheRightScreen() {
        let site = "https://aptiduel.vercel.app"
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

    @Test func companiesByName() {
        #expect(company(named: "Infosys")?.slug == "infosys")
        #expect(company(named: nil) == nil)
    }
}
