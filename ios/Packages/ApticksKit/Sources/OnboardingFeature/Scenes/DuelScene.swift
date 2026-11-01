import DesignSystem
import SwiftUI
import Tiko

// Quick Match: Tiko hops onto a question card, thinks, tries option A
// (wrong, so it shakes its head), hops over to B, and B lights up with
// +145 and a burst of confetti while the timer stops.
struct DuelScene: View {
    let start: Date?
    private let size: CGFloat = 54

    // The script, in seconds.
    private enum T {
        static let enter = 0.15
        static let toA = 1.75
        static let toB = 2.95
        static let done = 6.0
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cardW = min(w - 48, 340)
            let cardX = (w - cardW) / 2
            let cardTop = h * 0.2
            let cardH = h * 0.74
            let gap: CGFloat = 10
            let optW = (cardW - 32 - gap) / 2
            let optH: CGFloat = 46
            let row1 = cardTop + cardH - 16 - 2 * optH - gap
            let optionA = CGPoint(x: cardX + 16 + optW / 2, y: row1)
            let optionB = CGPoint(x: cardX + 16 + optW * 1.5 + gap, y: row1)
            let perch = CGPoint(x: cardX + 44, y: cardTop)
            let hops = [
                TikoHop(from: CGPoint(x: -40, y: cardTop - 30), to: perch, start: T.enter, height: 70),
                TikoHop(from: perch, to: optionA, start: T.toA, height: 60),
                TikoHop(from: optionA, to: optionB, start: T.toB, height: 55),
            ]

            SceneTimeline(start: start, length: T.done) { t in
                let answered = t > hops[2].touchdown
                let wrong = t > hops[1].touchdown
                ZStack {
                    card(t: t, x: cardX, top: cardTop, width: cardW, height: cardH, answered: answered)
                    option("A", "20%", at: optionA, width: optW, height: optH, state: wrong && !answered ? .wrong : .idle)
                    option("B", "25%", at: optionB, width: optW, height: optH, state: answered ? .right : .idle)
                    option("C", "16%", at: CGPoint(x: optionA.x, y: row1 + optH + gap), width: optW, height: optH, state: .idle)
                    option("D", "30%", at: CGPoint(x: optionB.x, y: row1 + optH + gap), width: optW, height: optH, state: .idle)

                    // +145 floats up off the right answer.
                    if answered {
                        let k = phase(t, hops[2].touchdown, hops[2].touchdown + 1.1, .easeOut)
                        Text("+145")
                            .font(.mono(22))
                            .foregroundStyle(Theme.lime)
                            .shadow(color: Theme.lime.opacity(0.5), radius: 8)
                            .scaleEffect(0.6 + 0.5 * min(1, k * 2.5))
                            .opacity(k < 0.75 ? 1 : 1 - (k - 0.75) / 0.25)
                            .position(x: optionB.x + 46, y: row1 - 30 - 60 * k)
                    }
                    Burst(t: t - hops[2].touchdown, at: CGPoint(x: optionB.x, y: row1), count: 22, power: 0.8)
                    TikoActor(pose: pose(t, hops), size: size, play: play(t, hops))
                    if t > hops[0].end + 0.1 && t < T.toA {
                        Speech(text: "Hmm…").position(x: perch.x + 52, y: perch.y - 70)
                    }
                    if wrong && t < T.toB {
                        Speech(text: "Nope!", tone: Theme.redSoft).position(x: optionA.x + 34, y: row1 - 72)
                    }
                }
                .frame(width: w, height: h)
            }
            .sceneHaptics(start, [(hops[0].touchdown, .light), (hops[1].touchdown, .soft), (hops[2].touchdown, .medium)])
        }
    }

    private func pose(_ t: Double, _ hops: [TikoHop]) -> TikoPose {
        if t < hops[0].end { return .on(hops[0], at: t, mood: .happy) }
        if t < hops[1].start { return TikoPose(feet: hops[0].to, mood: .think, still: false) }
        if t < hops[1].end { return .on(hops[1], at: t, mood: .point) }
        if t < hops[2].start { return TikoPose(feet: hops[1].to, mood: .sad) }
        if t < hops[2].end { return .on(hops[2], at: t, mood: .happy) }
        return TikoPose(feet: hops[2].to, mood: .cheer, still: false)
    }

    private func play(_ t: Double, _ hops: [TikoHop]) -> TikoPlay? {
        if t > hops[2].end { return TikoPlay(move: .boing, key: 2) }
        if t > hops[1].end + 0.05 && t < hops[2].start { return TikoPlay(move: .droop, key: 1) }
        return nil
    }

    private func card(t: Double, x: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat, answered: Bool) -> some View {
        // The fuse burns while Tiko decides, and stops at the answer.
        let left = answered ? 0.62 : 1 - 0.38 * phase(t, 0.9, T.toB + 0.45, .linear)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Question 1 of 5").font(.ui(12, .semibold)).foregroundStyle(Theme.muted)
                Spacer()
                Text(answered ? "You 145" : "You 0")
                    .font(.mono(12))
                    .foregroundStyle(answered ? Theme.lime : Theme.soft)
                    .contentTransition(.numericText())
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(Theme.lime).frame(width: g.size.width * left)
                }
            }
            .frame(height: 6)
            Text("The cost price of 20 articles equals the selling price of 16. Profit %?")
                .font(.ui(15, .semibold))
                .foregroundStyle(Theme.text)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(16)
        .frame(width: width, height: height)
        .card(20, border: Theme.line, width: 2)
        .sticker(20)
        .position(x: x + width / 2, y: top + height / 2)
    }

    private enum OptionState { case idle, wrong, right }

    private func option(_ key: String, _ text: String, at top: CGPoint, width: CGFloat, height: CGFloat, state: OptionState) -> some View {
        let (fill, border, bubble, ink): (Color, Color, Color, Color) = switch state {
        case .idle: (Theme.raised, Theme.field, .clear, Theme.muted)
        case .wrong: (Theme.redTint, Theme.red, Theme.red, Theme.ink)
        case .right: (Theme.limeTint, Theme.lime, Theme.lime, Theme.ink)
        }
        return HStack(spacing: 8) {
            ZStack {
                Circle().fill(bubble)
                Circle().strokeBorder(state == .idle ? Theme.lineStrong : bubble, lineWidth: 2)
                if state == .right {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .black))
                } else {
                    Text(key).font(.mono(11))
                }
            }
            .foregroundStyle(ink)
            .frame(width: 24, height: 24)
            Text(text).font(.ui(15, .semibold)).foregroundStyle(Theme.text)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: height)
        .card(14, fill: fill, border: border, width: 2)
        .scaleEffect(state == .right ? 1.04 : 1)
        .animation(.pop, value: state == .right)
        .position(x: top.x, y: top.y + height / 2)
    }
}
