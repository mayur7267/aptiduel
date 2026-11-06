import DesignSystem
import SwiftUI
import Tiko

public struct TourStep: Sendable {
    public let target: String?
    public let mood: TikoMood
    public let title: String
    public let text: String
}

// The first-run tour of the home tab, card by card.
public let TOUR_STEPS: [TourStep] = [
    TourStep(target: nil, mood: .wave, title: "Hi, I'm Tiko!", text: "I'll hop you around Apticks. It takes about 20 seconds."),
    TourStep(target: "quick", mood: .point, title: "Quick Match",
             text: "Race someone near your rating: 5 questions, about 3 minutes. A right answer scores 100, plus up to 50 for speed."),
    TourStep(target: "challenge", mood: .happy, title: "Duel a friend",
             text: "Send a link on WhatsApp. When your friend joins, you both race the same 5 questions live."),
    TourStep(target: "company", mood: .think, title: "Company prep",
             text: "Preparing for TCS NQT, Infosys, Cognizant or Wipro? Duel on just the topics their tests ask about."),
    TourStep(target: "daily", mood: .happy, title: "Daily Challenge",
             text: "One set a day, the same for everyone. Play daily to keep your streak alive. Swipe this card for more."),
    TourStep(target: "goals", mood: .cheer, title: "Daily goals",
             text: "Three small goals every day. Swipe once more to count down to your placement test."),
    TourStep(target: "profile", mood: .wave, title: "Your profile",
             text: "Add your name and college to join your college leaderboard, and save your account with your email."),
    TourStep(target: nil, mood: .cheer, title: "You're ready!", text: "Your first duel is one tap away. Good luck!"),
]

// The tour's progress, and where its targets are on screen.
@MainActor
@Observable
public final class TourState {
    private static let doneKey = "apticks-tour-done"

    public var open = false
    public var step = 0
    public var frames: [String: CGRect] = [:]
    public var scrollTarget: String?
    public var replayRequested = false

    public init() {}

    public var done: Bool {
        get { UserDefaults.standard.bool(forKey: Self.doneKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.doneKey) }
    }

    public var activeTarget: String? { open ? TOUR_STEPS[step].target : nil }

    // Shown on the first visit, or when Profile asks for a replay.
    public var shouldStart: Bool { (!done || replayRequested) && !open }

    public func start() {
        step = 0
        open = true
    }
}

private struct TourTarget: ViewModifier {
    let name: String
    var outline: Bool
    @Environment(TourState.self) private var tour

    func body(content: Content) -> some View {
        content
            .id(name)
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { tour.frames[name] = $0 }
            .overlay {
                // The card Tiko is talking about: a soft outline, no dimming.
                if outline {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Theme.lime, lineWidth: 2)
                        .padding(-5)
                        .opacity(tour.activeTarget == name ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: tour.activeTarget)
                        .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    // Marks something the tour can hop to.
    public func tourTarget(_ name: String, outline: Bool = true) -> some View {
        modifier(TourTarget(name: name, outline: outline))
    }
}
