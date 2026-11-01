import AppCore
import DesignSystem
import SwiftUI
import Tiko

// Tiko the companion: stays with the player in the bottom corner of the
// main tabs, with a mood that fits the tab, and says the odd helpful
// thing. Screens that draw their own Tiko (matchmaking, duels, results,
// the Daily tab, challenge links) don't show this one, so there's only
// ever one Tiko on screen.


// Profile has Tiko on its banner and its own tile, so the companion sits that one out.
private let ROUTE_MOOD: [AppTab: TikoMood] = [.home: .happy, .ranks: .point]

private let TIPS = [
    "Right answers score 100, plus up to 50 for speed.",
    "A guess beats a timeout: unanswered questions score nothing.",
    "In a challenge, whoever plays second races the other's run live.",
    "Play the Daily Challenge every day to grow your streak.",
    "Company practice only uses topics from that company's test.",
    "Add your college to climb your college leaderboard.",
    "Tap me five times fast. I dare you.",
]

public struct CompanionView: View {
    @Environment(AppRouter.self) private var app
    @Environment(CompanionState.self) private var companion
    @Environment(TourState.self) private var tour
    @Environment(OnboardingState.self) private var onboarding
    @Environment(LaunchState.self) private var launch
    @State private var bubble: String?
    @State private var seen: Set<String> = []
    @State private var hideTask: Task<Void, Never>?

    public init() {}

    public var body: some View {
        let routeMood = ROUTE_MOOD[app.tab]
        let visible = routeMood != nil && !companion.touring && !companion.off && !onboarding.showing && !launch.splashing
        let page = companion.pages[app.tab]
        let mood = page?.mood ?? routeMood ?? .happy
        let say = visible ? page?.say : nil

        HStack(alignment: .bottom, spacing: 8) {
            if visible, let bubble {
                Button { self.bubble = nil } label: {
                    Text(bubble)
                        .font(.ui(13))
                        .foregroundStyle(Theme.soft)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: 230, alignment: .leading)
                        .card(16, border: Theme.line, width: 2)
                        .overlay(alignment: .bottomTrailing) { BubbleTail(edge: .trailing).offset(x: 7, y: -16) }
                        .sticker(16)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 16)
                .popIn()
                .id(bubble)
                .accessibilityAddTraits(.updatesFrequently)
            }
            ZStack {
                // The dock: the tour's Tiko starts and ends here.
                Color.clear
                    .frame(width: COMPANION_SIZE, height: TikoView.height(for: COMPANION_SIZE))
                    .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { tour.frames["dock"] = $0 }
                if visible {
                    TikoView(mood: mood, size: COMPANION_SIZE) { speak(TIPS.randomElement()!) }
                        .rise()
                }
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 12)
        // A tab's message shows once per visit.
        .task(id: say) {
            guard let say, !seen.contains(say) else { return }
            try? await Task.sleep(for: .milliseconds(900))
            if Task.isCancelled { return }
            seen.insert(say)
            speak(say)
        }
        .onChange(of: visible) { _, now in
            if !now {
                hideTask?.cancel()
                bubble = nil
            }
        }
    }

    private func speak(_ text: String) {
        hideTask?.cancel()
        withAnimation(.snappy) { bubble = text }
        hideTask = Task {
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled { withAnimation(.easeOut) { bubble = nil } }
        }
    }
}
