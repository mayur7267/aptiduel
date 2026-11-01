import AppCore
import DesignSystem
import SwiftUI

// The first-launch intro. Six pages you can swipe or step through; each
// has a scene that plays when you arrive (and again if you come back).
// While swiping, pages turn in 3D, their text slides at its own depth,
// the backdrop shifts colour and the dots stretch to follow your finger.
public struct OnboardingView: View {
    @State private var model: OnboardingViewModel
    @State private var tilt = Tilt()
    @State private var starts: [Int: Date] = [:]
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.45, dampingFraction: 0.86)))
    private var drag: CGFloat = 0
    @FocusState private var nameFocused: Bool
    @Environment(LaunchState.self) private var launch
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias Page = OnboardingViewModel.Page

    public init(model: OnboardingViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let progress = rubberBand(CGFloat(model.page.rawValue) - drag / w)
            ZStack(alignment: .top) {
                Backdrop(progress: progress, tilt: tilt)
                HStack(spacing: 0) {
                    ForEach(Page.allCases) { p in
                        page(p, progress: progress, size: geo.size)
                            .frame(width: w, height: geo.size.height)
                    }
                }
                .frame(width: w, alignment: .leading)
                .offset(x: -progress * w)
                topBar
                controls(progress: progress)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(swipe(width: w))
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: model.page)
        .ignoresSafeArea(.keyboard)
        .background(Theme.ink)
        .onAppear {
            if !launch.splashing { starts[0] = Date().addingTimeInterval(0.3) }
            if !reduceMotion { tilt.start() }
        }
        .onChange(of: launch.splashing) { _, splashing in
            if !splashing && starts[model.page.rawValue] == nil { starts[model.page.rawValue] = Date().addingTimeInterval(0.15) }
        }
        .onDisappear { tilt.stop() }
        .onChange(of: model.page) { _, p in
            starts[p.rawValue] = Date()
            nameFocused = false
        }
        .sensoryFeedback(.selection, trigger: model.page)
        .task { await model.prepare() }
    }

    // Past the first and last page the swipe stretches instead of moving.
    private func rubberBand(_ p: CGFloat) -> CGFloat {
        let last = CGFloat(Page.allCases.count - 1)
        if p < 0 { return p * 0.3 }
        if p > last { return last + (p - last) * 0.3 }
        return p
    }

    private func swipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .updating($drag) { v, state, _ in
                if abs(v.translation.width) > abs(v.translation.height) { state = v.translation.width }
            }
            .onEnded { v in
                guard abs(v.translation.width) > abs(v.translation.height) else { return }
                let moved = v.predictedEndTranslation.width
                if moved < -width * 0.2 && !model.isLast {
                    Task { await model.next() }
                } else if moved > width * 0.2 {
                    model.back()
                }
            }
    }

    // MARK: Pages

    private func page(_ p: Page, progress: CGFloat, size: CGSize) -> some View {
        let d = CGFloat(p.rawValue) - progress // -1...1 for the pages either side
        let near = min(1, abs(d))
        let start = starts[p.rawValue]
        let copy = Copy.for(p)
        return VStack(spacing: 0) {
            Color.clear.frame(height: 64)
            scene(p, start: start)
                .frame(height: size.height * (p == .name ? 0.48 : 0.5))
                // Clip the sides so a neighbour's Tiko, waiting off its own
                // edge, never peeks in; the top stays open for big jumps.
                .mask(Rectangle().padding(.vertical, -1_000))
                // Turning away like a card on a carousel.
                .rotation3DEffect(.degrees(Double(d) * -24), axis: (x: 0, y: 1, z: 0),
                                  anchor: d > 0 ? .leading : .trailing, perspective: 0.55)
                .scaleEffect(1 - near * 0.1)
                .opacity(1 - near * 0.4)
            VStack(alignment: .leading, spacing: 12) {
                Text(copy.kicker)
                    .font(.mono(11))
                    .tracking(2)
                    .foregroundStyle(PAGE_GLOW[p.rawValue])
                KineticText(text: copy.title, start: start)
                Text(copy.body)
                    .font(.ui(16))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(start.map { _ in 1 } ?? 0)
                    .animation(.easeOut(duration: 0.5).delay(0.35), value: start)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 6)
            // The words travel faster than the page: depth.
            .offset(x: d * size.width * 0.28)
            .opacity(1 - near * 0.9)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityHidden(p != model.page)
    }

    @ViewBuilder
    private func scene(_ p: Page, start: Date?) -> some View {
        switch p {
        case .hello: SwingScene(start: start)
        case .duel: DuelScene(start: start)
        case .challenge: ChallengeScene(start: start)
        case .climb: ClimbScene(start: start)
        case .name: NameScene(start: start, model: model, focused: $nameFocused)
        case .ready: LaunchScene(start: start)
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            Logo()
            Spacer()
            if !model.isLast {
                Button("Skip") { Task { await model.finish(.explore) } }
                    .font(.ui(15, .semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Capsule().fill(Theme.surface.opacity(0.7)))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .animation(.easeInOut, value: model.isLast)
    }

    private func controls(progress: CGFloat) -> some View {
        VStack(spacing: 16) {
            PageDots(progress: progress, count: Page.allCases.count)
            if let error = model.error {
                Text(error).font(.ui(13)).foregroundStyle(Theme.redSoft).multilineTextAlignment(.center)
            }
            if model.isLast {
                Button { Task { await model.finish(.play) } } label: {
                    Label("Find my first match", systemImage: "bolt.fill").font(.ui(17, .heavy))
                }
                .buttonStyle(PressableStyle(fill: Theme.lime, foreground: Theme.ink, pop: Theme.limePop, radius: 18, height: 60))
                .overlay { Shine().clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)).allowsHitTesting(false) }
                .modifier(Breathe())
                Button("Explore home first") { Task { await model.finish(.explore) } }
                    .font(.ui(15, .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(height: 30)
            } else {
                Button { Task { await model.next() } } label: {
                    HStack(spacing: 8) {
                        Text(primaryLabel).contentTransition(.interpolate)
                        if model.saving { ProgressView().tint(Theme.ink) } else { Image(systemName: "arrow.right") }
                    }
                    .font(.ui(17, .heavy))
                }
                .buttonStyle(PressableStyle(fill: Theme.lime, foreground: Theme.ink, pop: Theme.limePop, radius: 18, height: 60))
                .disabled(model.saving || (model.page == .name && !model.name.isEmpty && !model.nameIsValid))
                .animation(.snappy, value: primaryLabel)
                Group {
                    if model.page == .hello {
                        Button("I already have an account") { Task { await model.finish(.signIn) } }
                    } else {
                        Text(" ")
                    }
                }
                .font(.ui(15, .semibold))
                .foregroundStyle(Theme.muted)
                .frame(height: 30)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }

    private var primaryLabel: String {
        switch model.page {
        case .hello: "Let's go"
        case .name: model.name.trimmingCharacters(in: .whitespaces).isEmpty ? "Not now" : "That's me"
        default: "Next"
        }
    }
}

// What each page says.
private struct Copy {
    let kicker: String
    let title: String
    let body: String

    static func `for`(_ page: OnboardingViewModel.Page) -> Copy {
        switch page {
        case .hello:
            Copy(kicker: "WELCOME TO APTICKS", title: "Hi, I'm Tiko!",
                 body: "Your sidekick for placement season. Let's make aptitude practice feel like a game.")
        case .duel:
            Copy(kicker: "QUICK MATCH", title: "5 questions. 3 minutes. One winner.",
                 body: "Race a player near your rating. A right answer scores 100, and speed adds up to 50 more.")
        case .challenge:
            Copy(kicker: "CHALLENGES", title: "Challenge your friends",
                 body: "Send a link on WhatsApp. You both get the same 5 questions, and whoever plays second races the other's run.")
        case .climb:
            Copy(kicker: "YOUR RATING", title: "Climb from Fresher to Architect",
                 body: "Win duels to grow your rating, keep a daily streak going and top your college leaderboard.")
        case .name:
            Copy(kicker: "ABOUT YOU", title: "What should friends call you?",
                 body: "It's shown on challenges and leaderboards. You can change it any time in Profile.")
        case .ready:
            Copy(kicker: "READY", title: "You're all set!",
                 body: "Your first duel is one tap away. Tiko will be right there with you.")
        }
    }
}

// Dots that stretch into a pill for the page you're on, following the swipe.
private struct PageDots: View {
    let progress: CGFloat
    let count: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                let near = max(0, 1 - abs(progress - CGFloat(i)))
                Capsule()
                    .fill(Theme.lineStrong)
                    .overlay(Capsule().fill(Theme.lime).opacity(near))
                    .frame(width: 8 + 24 * near, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(Int(progress.rounded()) + 1) of \(count)")
    }
}

// A sweep of light across the final button.
private struct Shine: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { tl in
            GeometryReader { g in
                let cycle = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.6) / 2.6
                let k = Ease.easeInOut(min(1, cycle / 0.45))
                LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: g.size.width * 0.35)
                    .rotationEffect(.degrees(18))
                    .offset(x: -g.size.width * 0.5 + g.size.width * 1.5 * k)
                    .opacity(cycle < 0.45 && !reduceMotion ? 1 : 0)
                    .blendMode(.plusLighter)
            }
        }
    }
}

// A soft glow that breathes in and out.
private struct Breathe: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: reduceMotion)) { tl in
            let k = (sin(tl.date.timeIntervalSinceReferenceDate * 2.4) + 1) / 2
            content.shadow(color: Theme.lime.opacity(0.18 + 0.27 * k), radius: 10 + 12 * k)
        }
    }
}
