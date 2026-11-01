import AppCore
import Domain
import Foundation
import NetworkingFakes
import SwiftUI
import Testing
@testable import OnboardingFeature

@MainActor
struct OnboardingViewModelTests {
    let backend = FakeBackend(latency: .zero)
    let router = AppRouter()
    let state = OnboardingState()

    private func model() -> OnboardingViewModel {
        OnboardingViewModel(api: backend, router: router, onboarding: state)
    }

    @Test func stepsThroughThePages() async {
        let m = model()
        #expect(m.page == .hello)
        await m.next()
        await m.next()
        #expect(m.page == .challenge)
        m.back()
        #expect(m.page == .duel)
    }

    @Test func savesTheNameBeforeMovingOn() async throws {
        let m = model()
        await m.prepare()
        #expect(!m.colleges.isEmpty)
        m.go(to: .name)
        m.name = "Asha"
        m.collegeId = m.colleges.first?.id
        await m.next()
        #expect(m.page == .ready)
        let me = try await backend.me()
        #expect(me.name == "Asha")
        #expect(me.collegeId == m.colleges.first?.id)
    }

    @Test func aNameIsOptional() async throws {
        let m = model()
        m.go(to: .name)
        await m.next()
        #expect(m.page == .ready)
        #expect(try await backend.me().hasGuestName)
    }

    @Test func namesAreTrimmedAndOneLetterIsntSaved() async throws {
        let m = model()
        m.go(to: .name)
        m.name = String(repeating: "a", count: 30)
        #expect(m.name.count == 24)
        m.name = "A"
        #expect(!m.nameIsValid)
        await m.next()
        #expect(try await backend.me().hasGuestName)
    }

    @Test func finishingStartsAMatch() async {
        state.replay()
        let m = model()
        await m.finish(.play)
        #expect(!state.showing)
        #expect(router.flow?.screen == .matchmaking(nil))
    }

    @Test func signingInGoesToProfile() async {
        state.replay()
        let m = model()
        await m.finish(.signIn)
        #expect(router.tab == .profile)
        #expect(router.flow == nil)
    }
}

// Renders each scene at exact moments into PNG filmstrips, to check the
// motion frame by frame. Only runs when FILM_DIR is set:
//   TEST_RUNNER_FILM_DIR=/tmp/film xcodebuild test -only-testing:OnboardingFeatureTests/SceneFilm …
@MainActor
struct SceneFilm {
    private let size = CGSize(width: 402, height: 437)

    @Test func swing() throws { try film("swing", until: 4.4, every: 0.12) { SwingScene(start: $0) } }
    @Test func duel() throws { try film("duel", until: 5, every: 0.2) { DuelScene(start: $0) } }
    @Test func challenge() throws { try film("challenge", until: 4, every: 0.2) { ChallengeScene(start: $0) } }
    @Test func climb() throws { try film("climb", until: 5.2, every: 0.2) { ClimbScene(start: $0) } }
    @Test func launch() throws { try film("launch", until: 3.6, every: 0.12) { LaunchScene(start: $0) } }

    private func film(_ name: String, until end: Double, every step: Double, _ scene: (Date) -> some View) throws {
        guard let dir = ProcessInfo.processInfo.environment["FILM_DIR"] else { return }
        let folder = URL(fileURLWithPath: dir).appendingPathComponent(name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var frame = 0
        for t in stride(from: 0.0, through: end, by: step) {
            let view = scene(Date().addingTimeInterval(-t))
                .frame(width: size.width, height: size.height)
                .background(Color(red: 0.043, green: 0.055, blue: 0.09))
                .overlay(alignment: .topLeading) {
                    Text(String(format: "t = %.2fs", t)).font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7)).padding(6)
                }
                .environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            let image = try #require(renderer.uiImage)
            try #require(image.pngData()).write(to: folder.appendingPathComponent(String(format: "%03d.png", frame)))
            frame += 1
        }
    }
}
