import AppCore
import DesignSystem
import SwiftUI
import Tiko

// First-run tour of the home tab. Tiko hops from card to card along a
// real arc, sits on each one and explains it in a speech bubble. Nothing
// is dimmed or blocked: the app stays usable and Skip is always there.
// Cards opt in with .tourTarget("name"). Seen once per install; Profile
// can replay it.

private let GAP: CGFloat = 8

// A hop in progress, on the wall clock.
private struct Hop {
    let path: TikoHop
    let began: Date

    init(from: CGPoint, to: CGPoint, start: Date) {
        path = TikoHop(from: from, to: to)
        began = start
    }

    var duration: Double { path.duration }
    func values(at now: Date) -> [Double] { path.values(at: now.timeIntervalSince(began)) }
}

public struct TikoTour: View {
    @Environment(TourState.self) private var tour
    @Environment(AppRouter.self) private var app
    @Environment(CompanionState.self) private var companion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hop: Hop?
    @State private var landed = false
    @State private var lastSpot: CGPoint?
    @State private var screen: CGSize = .zero
    @State private var topInset: CGFloat = 0
    @State private var bubbleHeight: CGFloat = 0

    private let size = COMPANION_SIZE
    private var height: CGFloat { TikoView.height(for: size) }

    public init() {}

    public var body: some View {
        GeometryReader { outer in
            ZStack(alignment: .topLeading) {
                if tour.open {
                    let s = TOUR_STEPS[tour.step]
                    let rest = currentSpot ?? lastSpot ?? .zero
                    TimelineView(.animation(paused: hop == nil)) { tl in
                        let v = hop.map { $0.values(at: tl.date) } ?? [rest.x, rest.y, 1, 1]
                        TikoView(mood: s.mood, size: size, still: !landed)
                            .scaleEffect(x: v[2], y: v[3], anchor: .bottom)
                            .offset(x: v[0], y: v[1])
                    }
                    .opacity(lastSpot == nil ? 0 : 1)

                    if let spot = currentSpot {
                        bubble(s, at: spot)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .ignoresSafeArea()
            .onAppear { topInset = outer.safeAreaInsets.top }
            .onChange(of: outer.safeAreaInsets.top) { _, v in topInset = v }
        }
        .onGeometryChange(for: CGSize.self, of: { $0.frame(in: .global).size }) { screen = $0 }
        .task(id: tour.open ? tour.step : -1) { await moveToStep() }
        .onChange(of: tour.open) { _, open in companion.touring = open }
        // The tour belongs to the home tab; leaving it puts the tour away
        // (it comes back next time, as it was never finished).
        .onChange(of: app.tab) { _, tab in if tab != .home && tour.open { close(done: false) } }
        .onChange(of: app.flow != nil) { _, presented in if presented && tour.open { close(done: true) } }
    }

    // Standing on its card, following it while the page scrolls.
    private var currentSpot: CGPoint? {
        guard tour.open, landed, lastSpot != nil else { return nil }
        return spot(for: TOUR_STEPS[tour.step])
    }

    // On the target's top edge near its right corner, or at the
    // companion's dock for the intro and the ending.
    private func spot(for step: TourStep) -> CGPoint {
        if let name = step.target, let r = tour.frames[name], r.width > 0, r.maxY > 0, r.minY < screen.height {
            let x = min(max(r.maxX - size - 14, GAP), screen.width - size - GAP)
            let y = min(max(r.minY - height + 10, topInset + GAP), screen.height - height - GAP)
            return CGPoint(x: x, y: y)
        }
        if let dock = tour.frames["dock"], dock.width > 0 { return dock.origin }
        return CGPoint(x: screen.width - size - 20, y: screen.height - height - 120)
    }

    // Bring the step's card into view, then hop there.
    private func moveToStep() async {
        guard tour.open else { return }
        // Take off from where Tiko stands now.
        if landed, let here = currentSpot { lastSpot = here }
        landed = false
        let s = TOUR_STEPS[tour.step]
        if let target = s.target {
            tour.scrollTarget = target
        }
        try? await Task.sleep(for: .milliseconds(s.target != nil ? 450 : 50))
        if Task.isCancelled { return }
        let to = spot(for: s)
        let from = lastSpot ?? to
        lastSpot = to
        if reduceMotion || hypot(to.x - from.x, to.y - from.y) < 2 {
            landed = true
            return
        }
        let h = Hop(from: from, to: to, start: Date())
        hop = h
        try? await Task.sleep(for: .seconds(h.duration))
        hop = nil
        landed = true
    }

    private func next() {
        if let here = currentSpot { lastSpot = here }
        landed = false
        tour.step += 1
    }

    private func close(done: Bool) {
        if done { tour.done = true }
        tour.open = false
        tour.step = 0
        tour.scrollTarget = nil
        tour.replayRequested = false
        landed = false
        lastSpot = nil
        hop = nil
    }

    // Beside Tiko (left if there's room, else right, else above),
    // bottom-aligned with Tiko's feet, and always on screen.
    private func bubble(_ s: TourStep, at p: CGPoint) -> some View {
        let w = min(300, screen.width - 2 * GAP - 16)
        let h = bubbleHeight
        var x: CGFloat
        var y = p.y + height - h
        if p.x - GAP - w >= GAP {
            x = p.x - GAP - w
        } else if p.x + size + GAP + w <= screen.width - GAP {
            x = p.x + size + GAP
        } else {
            x = min(max(p.x + size / 2 - w / 2, GAP), screen.width - w - GAP)
            y = p.y - h - GAP
            if y < topInset + GAP { y = p.y + height + GAP }
        }
        y = min(max(y, topInset + GAP), screen.height - h - GAP)
        let last = tour.step == TOUR_STEPS.count - 1

        return VStack(alignment: .leading, spacing: 0) {
            Text(s.title).font(.display(15)).foregroundStyle(Theme.text)
            Text(s.text).font(.ui(14)).foregroundStyle(Theme.soft).lineSpacing(3).padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                HStack(spacing: 4) {
                    ForEach(TOUR_STEPS.indices, id: \.self) { i in
                        Circle().fill(i == tour.step ? Theme.lime : Theme.lineStrong).frame(width: 6, height: 6)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Step \(tour.step + 1) of \(TOUR_STEPS.count)")
                Spacer()
                Button(last ? "Later" : "Skip") { close(done: true) }
                    .font(.ui(12, .semibold))
                    .fixedSize()
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 34)
                Button(last ? "Find a match" : tour.step == 0 ? "Show me" : "Next") {
                    if last {
                        close(done: true)
                        app.open(.matchmaking(nil))
                    } else {
                        next()
                    }
                }
                .buttonStyle(FilledStyle(fill: Theme.lime, foreground: Theme.ink, radius: 10, height: 34))
                .font(.ui(12, .bold))
                .lineLimit(1)
                .fixedSize()
            }
            .padding(.top, 12)
        }
        .padding(16)
        .frame(width: w, alignment: .leading)
        .card(16, border: Theme.line, width: 2)
        .sticker(16)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { bubbleHeight = $0 }
        .opacity(h > 0 ? 1 : 0)
        .popIn()
        .id(tour.step)
        .offset(x: x, y: y)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("App tour")
    }
}
