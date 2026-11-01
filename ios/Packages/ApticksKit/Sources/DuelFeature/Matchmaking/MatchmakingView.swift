import DesignSystem
import Domain
import SwiftUI
import Tiko

public struct MatchmakingView: View {
    @State private var model: MatchmakingViewModel

    public init(model: MatchmakingViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton("Cancel and go home") { model.cancel() }
                Spacer()
                Text(model.label).font(.ui(14, .semibold)).foregroundStyle(Theme.muted)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            VStack(spacing: 36) {
                if let error = model.error {
                    VStack(alignment: .leading, spacing: 12) {
                        ErrorNote(error) { model.retry() }
                        Button("Back to home") { model.cancel() }.font(.ui(14, .semibold)).foregroundStyle(Theme.lime)
                    }
                } else if let duel = model.duel {
                    Reveal(me: duel.me, opponent: duel.opponent, count: model.count, resuming: model.resumed)
                } else {
                    Searching(me: model.me, status: model.status) { model.cancel() }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.snappy, value: model.duel != nil)
        }
        .background {
            RadialGradient(colors: [Theme.lime.opacity(0.09), .clear], center: UnitPoint(x: 0.5, y: 0.38), startRadius: 0, endRadius: 320)
                .ignoresSafeArea()
        }
        .task(id: model.attempt) { await model.find() }
        .task(id: model.attempt) { await model.runStatus() }
        .task(id: model.duel?.id) { await model.runCountdown() }
        .sensoryFeedback(.success, trigger: model.duel != nil) { _, found in found }
        .sensoryFeedback(.impact(weight: .medium), trigger: model.count)
    }
}

private struct Searching: View {
    let me: Me?
    let status: String
    let onCancel: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 36) {
            TimelineView(.animation(paused: reduceMotion)) { tl in
                let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach([0.0, 0.8, 1.6], id: \.self) { delay in
                        let p = ((t - delay) / 2.4).truncatingRemainder(dividingBy: 1)
                        let k = Ease.bezier(0.2, 0.6, 0.4, 1)(p < 0 ? p + 1 : p)
                        Circle().strokeBorder(Theme.lime.opacity(0.4), lineWidth: 2)
                            .scaleEffect(reduceMotion ? 1 : 0.35 + 0.65 * k)
                            .opacity(reduceMotion ? 0.3 : 0.9 * (1 - k))
                    }
                    Circle().strokeBorder(Theme.line).padding(280 * 0.14)
                    Circle().strokeBorder(Theme.line).padding(280 * 0.30)
                    AngularGradient(stops: [.init(color: Theme.lime.opacity(0.28), location: 0), .init(color: .clear, location: 0.22)],
                                    center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))
                        .clipShape(Circle())
                        .rotationEffect(.degrees(t / 2.2 * 360))
                    orbit(t, reverse: false)
                    orbit(t, reverse: true)
                    PlayerAvatar(name: me?.name ?? "You", bot: false, size: 92)
                        .padding(4).background(Circle().fill(Theme.ink))
                        .padding(4).background(Circle().fill(Theme.lime))
                }
            }
            .frame(width: 280, height: 280)
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                TikoView(mood: .think, size: 64)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Finding an opponent").font(.display(22)).foregroundStyle(Theme.text)
                    BouncingDots(color: Theme.lime, size: 6)
                }
                Text(status + (me.map { " · \(grouped($0.rating))" } ?? ""))
                    .font(.ui(14)).foregroundStyle(Theme.muted)
                    .contentTransition(.opacity)
                    .animation(.easeInOut, value: status)
            }
            .multilineTextAlignment(.center)

            Button("Cancel", action: onCancel)
                .buttonStyle(FilledStyle(fill: .clear, foreground: Theme.muted, border: Theme.line, radius: 12, height: 42))
        }
    }

    private func orbit(_ t: Double, reverse: Bool) -> some View {
        let angle = (t / 7).truncatingRemainder(dividingBy: 1) * 360 * (reverse ? -1 : 1)
        return ZStack {
            if reverse {
                glowDot(Theme.cyan, 10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(.top, 12).padding(.trailing, 6)
            } else {
                glowDot(Theme.orange, 12).frame(maxHeight: .infinity, alignment: .top)
                glowDot(Theme.violet, 10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.bottom, 34).padding(.leading, 16)
            }
        }
        .padding(reverse ? 280 * 0.22 : 280 * 0.06)
        .rotationEffect(.degrees(angle))
    }

    private func glowDot(_ color: Color, _ size: CGFloat) -> some View {
        Circle().fill(color).frame(width: size, height: size).shadow(color: color, radius: 7)
    }
}

private struct Reveal: View {
    let me: Player
    let opponent: Player?
    let count: Int
    let resuming: Bool
    @State private var entered = false

    var body: some View {
        VStack(spacing: 36) {
            Text(resuming ? "FINISH THIS MATCH FIRST" : opponent != nil ? "OPPONENT FOUND" : "READY")
                .font(.ui(12, .bold)).tracking(2.8).foregroundStyle(Theme.lime)
                .popIn()

            HStack(alignment: .top, spacing: 8) {
                Side(player: me, label: "You", ring: Theme.lime)
                    .offset(x: entered ? 0 : -60)
                    .opacity(entered ? 1 : 0)
                Text("VS").font(.display(30)).foregroundStyle(Theme.lime).padding(.top, 32).popIn(0.25)
                Group {
                    if let opponent {
                        Side(player: opponent, label: nil, ring: Theme.orange)
                    } else {
                        VStack(spacing: 8) {
                            Text("?").font(.ui(24)).foregroundStyle(Theme.muted)
                                .frame(width: 84, height: 84)
                                .overlay(Circle().strokeBorder(Theme.lineStrong, style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
                            Text("Solo run").font(.ui(15, .semibold)).foregroundStyle(Theme.text)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .offset(x: entered ? 0 : 60)
                .opacity(entered ? 1 : 0)
            }
            .onAppear {
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.55)) { entered = true }
            }

            if let tagline = opponent?.tagline {
                Text("“\(tagline)”").font(.ui(14)).italic().foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 300)
            }

            if resuming {
                Text("You left this match unfinished and its clock is still running. Taking you back…")
                    .font(.ui(14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 300)
            } else {
                VStack(spacing: 4) {
                    Text("STARTING IN").font(.ui(12, .semibold)).tracking(1.2).foregroundStyle(Theme.muted)
                    Text("\(count)").font(.display(60)).foregroundStyle(Theme.text)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.pop, value: count)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct Side: View {
    let player: Player
    let label: String?
    let ring: Color

    var body: some View {
        VStack(spacing: 8) {
            PlayerAvatar(name: player.name, bot: player.isBot, size: 84)
                .padding(4).background(Circle().fill(Theme.ink))
                .padding(4).background(Circle().fill(ring))
            HStack(spacing: 4) {
                Text(label ?? player.name).lineLimit(1)
                if player.isBot { BotTag() }
            }
            .font(.ui(15, .bold)).foregroundStyle(Theme.text).padding(.top, 4)
            (Text(grouped(player.rating)).font(.mono(12, .regular)) + Text(" · \(tierFor(player.rating).name)"))
                .font(.ui(12)).foregroundStyle(Theme.muted)
            if !player.isBot, let college = player.college, label == nil {
                Text(college).font(.ui(12)).foregroundStyle(Theme.faint).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
