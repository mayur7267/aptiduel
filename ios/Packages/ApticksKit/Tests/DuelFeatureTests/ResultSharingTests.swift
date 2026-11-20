import AppCore
import Domain
import Foundation
import NetworkingFakes
import SwiftUI
import Testing
@testable import DuelFeature

@MainActor
struct ResultSharingTests {
    let backend = FakeBackend(latency: .zero)
    let router = AppRouter()

    private func finishedDaily() async throws -> DuelResultViewModel {
        let id = try await backend.dailyChallenge().duelId
        for i in 0..<5 {
            _ = try await backend.nextQuestion(id)
            _ = try await backend.submitAnswer(id, question: i, choice: 0)
        }
        let model = DuelResultViewModel(duelId: id, api: backend, router: router, sleep: { _ in })
        await model.load()
        return model
    }

    @Test func dailyShareIsAGridAndTheDailyLink() async throws {
        let model = try await finishedDaily()
        let duel = try #require(model.duel)
        let text = try #require(model.dailyText)
        #expect(text.hasPrefix("Apticks Daily · \(shortDay(istToday()))"))
        #expect(text.hasSuffix(Links.daily(duel.code)))
        #expect(text.filter { $0 == "🟩" || $0 == "🟥" }.count == 5)
        #expect(text.contains("\(duel.me.correct)/5"))
        // Never the questions.
        #expect(!text.contains("cost price"))
    }

    @Test func storyPictureSaysWhatKindOfGame() async throws {
        let model = try await finishedDaily()
        let story = try #require(model.story)
        #expect(story.chip == "DAILY · \(shortDay(istToday()).uppercased())")
        #expect(story.headline == "Today's Daily")
        #expect(story.grid.count == 5)
        #expect(story.correct == model.duel?.me.correct)
    }

    @Test func aGuestNamesThemselvesWithoutLeaving() async throws {
        let model = try await finishedDaily()
        #expect(model.askForName)
        await model.saveName("  Asha ")
        #expect(model.nameError == nil)
        #expect(!model.askForName)
        #expect(model.profile?.name == "Asha")
        #expect(model.duel?.me.name == "Asha")
        #expect(router.flow == nil) // still here, about to share
    }

    @Test func sharesAreCounted() async throws {
        let model = try await finishedDaily()
        model.logShare(.daily, .whatsapp)
        model.sharedStory()
        for _ in 0..<50 where backend.shares.count < 2 { await Task.yield() }
        #expect(backend.shares.contains(.init(kind: .daily, channel: .whatsapp, duelId: model.duelId)))
        #expect(backend.shares.contains(.init(kind: .story, channel: .share, duelId: model.duelId)))
        #expect(model.storyShared)
    }

    // The picture is 1080 x 1920. With TEST_RUNNER_STORY_DIR set, it's
    // saved there to look at.
    @Test func storyPictureIsStorySized() throws {
        let data = StoryData(chip: "QUICK MATCH", headline: "I won!", correct: 4, score: 512, time: "1:12",
                             grid: [true, true, false, true, true], extra: "Beat Kavya R by 120 points")
        let renderer = ImageRenderer(content: StoryCanvas(data: data).environment(\.colorScheme, .dark))
        renderer.scale = 3
        let image = try #require(renderer.uiImage)
        #expect(image.size.width * image.scale == 1080)
        #expect(image.size.height * image.scale == 1920)
        if let dir = ProcessInfo.processInfo.environment["STORY_DIR"] {
            try image.pngData()?.write(to: URL(fileURLWithPath: dir).appendingPathComponent("story-win.png"))
            let daily = StoryData(chip: "DAILY · 19 NOV", headline: "Today's Daily", correct: 2, score: 296, time: "0:48",
                                  grid: [false, false, true, false, true], extra: "#3 of 40 today")
            let r2 = ImageRenderer(content: StoryCanvas(data: daily).environment(\.colorScheme, .dark))
            r2.scale = 3
            try r2.uiImage?.pngData()?.write(to: URL(fileURLWithPath: dir).appendingPathComponent("story-daily.png"))
        }
    }
}
