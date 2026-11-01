import SwiftUI
import Testing
@testable import DesignSystem

// Renders the launch splash frame by frame when FILM_DIR is set (see
// OnboardingFeatureTests/SceneFilm).
@MainActor
struct SplashFilm {
    @Test func splash() throws {
        guard let dir = ProcessInfo.processInfo.environment["FILM_DIR"] else { return }
        let folder = URL(fileURLWithPath: dir).appendingPathComponent("splash")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (i, t) in stride(from: 0.0, through: 2.3, by: 0.1).enumerated() {
            let view = ZStack {
                Color.red.opacity(0.35) // the "app" underneath, to see the reveal
                BrandSplash(at: Date().addingTimeInterval(-t))
            }
            .frame(width: 300, height: 520)
            .overlay(alignment: .topLeading) {
                Text(String(format: "t = %.1fs", t)).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.white).padding(6)
            }
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            try #require(renderer.uiImage?.pngData()).write(to: folder.appendingPathComponent(String(format: "%03d.png", i)))
        }
    }
}
