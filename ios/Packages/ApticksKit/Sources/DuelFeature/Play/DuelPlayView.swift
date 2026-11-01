import DesignSystem
import Domain
import SwiftUI

public struct DuelPlayView: View {
    @State private var model: DuelPlayViewModel
    @Environment(\.scenePhase) private var scenePhase

    public init(model: DuelPlayViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        Group {
            if let error = model.error {
                VStack(alignment: .leading, spacing: 16) {
                    ErrorNote(error) { Task { await model.retry() } }
                    Button("Back to home") { model.leave() }.font(.ui(14, .semibold)).foregroundStyle(Theme.lime)
                }
                .padding(16)
                .frame(maxHeight: .infinity, alignment: .top)
            } else if let q = model.question {
                play(q)
            } else {
                Spinner("Loading duel").frame(maxHeight: .infinity)
            }
        }
        .task { await model.load() }
        .task(id: model.clockKey) { await model.runClock() }
        .task(id: model.isLive) { await model.followRace() }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, now in
            if now == .active { Task { await model.catchUp() } }
        }
        .sensoryFeedback(trigger: model.result) { _, r in r.map { $0.correct ? .success : .error } }
    }

    private func play(_ q: Question) -> some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    topBar(q)
                    if model.leaving { leaveConfirm }
                    Versus(model: model, question: q)
                    Fuse(fraction: model.fractionLeft, urgent: model.urgent)
                    tags(q)
                    Text(q.body).font(.ui(18, .semibold)).foregroundStyle(Theme.text).lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    if let figure = q.figure {
                        SVGFigure(svg: figure)
                            .frame(maxWidth: .infinity, maxHeight: 210)
                            .padding(12)
                            .card(16)
                            .accessibilityLabel("Question figure")
                    }
                    Spacer(minLength: 8)
                    // Pinned to the bottom for thumbs.
                    VStack(spacing: 10) {
                        DuelBuddy(q: q, phase: model.phase, result: model.result, chosen: model.chosen,
                                  urgent: model.urgent, waitingFor: model.waitingFor)
                        options(q)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .animation(.snappy, value: model.leaving)
    }

    private func topBar(_ q: Question) -> some View {
        let urgent = model.urgent
        return HStack {
            CloseButton("Leave duel") { model.leaving = true }
            Spacer()
            Text("Question \(q.qIndex + 1) of \(q.total)").font(.ui(15, .semibold)).foregroundStyle(Theme.text)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "clock").font(.system(size: 14, weight: .bold)).foregroundStyle(urgent ? Theme.orange : Theme.lime)
                Text(clock(model.remainingMs)).font(.mono(15)).monospacedDigit()
            }
            .foregroundStyle(urgent ? Theme.orange : Theme.text)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Capsule().fill(urgent ? Theme.orangeTint : Theme.surface))
            .overlay(Capsule().strokeBorder(urgent ? Theme.orange.opacity(0.4) : Theme.line))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(model.remainingMs / 1000) seconds left")
        }
    }

    private var leaveConfirm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Leave this duel? The clock keeps running, and questions you don't answer in time count as wrong.")
                .font(.ui(14)).foregroundStyle(Theme.orangeSoft)
            HStack(spacing: 10) {
                Button("Keep playing") { model.leaving = false }
                    .buttonStyle(FilledStyle(fill: Theme.lime, foreground: Theme.ink, radius: 12, height: 44))
                    .frame(maxWidth: .infinity)
                Button("Leave") { model.leave() }
                    .buttonStyle(FilledStyle(fill: Theme.surface, foreground: Theme.text, border: Theme.line, radius: 12, height: 44))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .card(16, fill: Theme.orangeTint, border: Theme.orange.opacity(0.4))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func tags(_ q: Question) -> some View {
        HStack(spacing: 8) {
            Chip(q.topic)
            Chip(SECTION_LABEL[q.section] ?? q.section)
            if let companies = q.companies, !companies.isEmpty {
                Chip(companyList(companies) + " pattern", fg: Theme.violet, bg: Theme.violetTint)
                    .accessibilityLabel(companies.joined(separator: ", ") + " pattern")
                    .accessibilityHint("This topic is part of these companies' aptitude tests")
            }
        }
    }

    @ViewBuilder
    private func options(_ q: Question) -> some View {
        let pick = { (i: Int) in Task { await model.submit(i) } }
        if let figures = q.optionFigures, figures.count == q.options.count {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(q.options.indices, id: \.self) { i in
                    OptionButton(index: i, text: q.options[i], figure: figures[i], phase: model.phase, chosen: model.chosen,
                                 result: model.result) { _ = pick(i) }
                }
            }
        } else {
            VStack(spacing: 10) {
                ForEach(q.options.indices, id: \.self) { i in
                    OptionButton(index: i, text: q.options[i], figure: nil, phase: model.phase, chosen: model.chosen,
                                 result: model.result) { _ = pick(i) }
                }
            }
        }
    }
}

// You against the opponent: live scores and right/wrong dots.
private struct Versus: View {
    let model: DuelPlayViewModel
    let question: Question

    var body: some View {
        let opp = model.duel?.opponent
        let replay = model.opponentReplay
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Text("You").font(.ui(14, .semibold)).foregroundStyle(Theme.text)
                Text("\(model.score)").font(.mono(28)).foregroundStyle(Theme.lime)
                    .contentTransition(.numericText(value: Double(model.score)))
                    .animation(.snappy, value: model.score)
                ProgressDots(marks: model.marks, current: question.qIndex, total: question.total)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("VS").font(.display(12)).foregroundStyle(Theme.soft)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.raised))
                .rotationEffect(.degrees(-6))

            VStack(alignment: .trailing, spacing: 8) {
                if model.isLive, let racer = model.race?.opponent {
                    LiveOpponent(player: racer, total: question.total)
                } else if let opp, opp.finished, model.duel?.opponentTimeline != nil {
                    HStack(spacing: 6) {
                        Text(opp.name).lineLimit(1)
                        if opp.isBot { BotTag() }
                    }
                    .font(.ui(14, .semibold)).foregroundStyle(Theme.text)
                    Text("\(replay.score)").font(.mono(28)).foregroundStyle(Theme.orange)
                        .contentTransition(.numericText(value: Double(replay.score)))
                        .animation(.snappy, value: replay.score)
                    ProgressDots(marks: replay.marks, current: replay.answeredHere ? -1 : question.qIndex, total: question.total, ring: Theme.orange)
                    HStack(spacing: 4) {
                        if !model.revealedHere && !replay.answeredHere {
                            BouncingDots(color: Theme.orange, size: 4)
                            Text("Thinking")
                        } else if !model.revealedHere {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundStyle(Theme.orange)
                            Text("Answered")
                        }
                    }
                    .font(.ui(12, .semibold)).foregroundStyle(Theme.muted)
                    .frame(height: 16)
                } else if let opp, opp.finished {
                    Text(opp.name).font(.ui(14, .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    Text("\(opp.score)").font(.display(24)).foregroundStyle(Theme.orange)
                    Text("score to beat").font(.ui(12)).foregroundStyle(Theme.muted)
                } else if let opp {
                    Text(opp.name).font(.ui(14, .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    Text("playing now").font(.ui(12)).foregroundStyle(Theme.muted)
                } else {
                    let (title, line) = switch model.duel?.mode {
                    case .daily: ("Daily challenge", "Same 5 questions for everyone today")
                    case .quick: ("Solo run", "No one near your rating yet. Others will race this run.")
                    default: ("Your friend", "They get these same 5 questions from your link.")
                    }
                    Text(title).font(.ui(14, .semibold)).foregroundStyle(Theme.text)
                    Text(line).font(.ui(12)).foregroundStyle(Theme.muted).multilineTextAlignment(.trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(
            ZStack {
                Theme.surface
                LinearGradient(stops: [
                    .init(color: Theme.lime.opacity(0.09), location: 0), .init(color: .clear, location: 0.42),
                    .init(color: .clear, location: 0.58), .init(color: Theme.orange.opacity(0.09), location: 1),
                ], startPoint: .leading, endPoint: .trailing)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.line, lineWidth: 2))
        .sticker(20)
    }
}

// A fuse with tick marks, burning down.
struct Fuse: View {
    let fraction: Double
    let urgent: Bool

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line)
                Capsule()
                    .fill(urgent ? Theme.orange : Theme.lime)
                    .overlay {
                        Canvas { ctx, size in
                            var x: CGFloat = 12
                            while x < size.width {
                                ctx.fill(Path(CGRect(x: x, y: 0, width: 2, height: size.height)), with: .color(Theme.ink.opacity(0.4)))
                                x += 14
                            }
                        }
                    }
                    .clipShape(Capsule())
                    .frame(width: max(0, g.size.width * fraction))
                    .animation(.linear(duration: 0.1), value: fraction)
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

// Your friend in a live race: their score and dots as they go, and where
// they are.
struct LiveOpponent: View {
    let player: LivePlayer
    let total: Int

    var body: some View {
        Text(player.name).lineLimit(1).font(.ui(14, .semibold)).foregroundStyle(Theme.text)
        Text("\(player.score)").font(.mono(28)).foregroundStyle(Theme.orange)
            .contentTransition(.numericText(value: Double(player.score)))
            .animation(.snappy, value: player.score)
        ProgressDots(marks: player.marks.map { $0 ? .right : .wrong }, current: player.finished ? -1 : player.answered,
                     total: total, ring: Theme.orange)
        HStack(spacing: 4) {
            if player.finished {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundStyle(Theme.orange)
                Text("Finished")
            } else if !player.present {
                Text("Connection lost…")
            } else {
                BouncingDots(color: Theme.orange, size: 4)
                Text("On question \(min(player.answered + 1, total))")
            }
        }
        .font(.ui(12, .semibold)).foregroundStyle(Theme.muted)
        .frame(height: 16)
    }
}
