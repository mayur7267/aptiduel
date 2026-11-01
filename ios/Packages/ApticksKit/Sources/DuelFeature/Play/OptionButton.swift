import DesignSystem
import Domain
import SwiftUI
import Tiko

let KEYS = ["A", "B", "C", "D"]

struct OptionButton: View {
    let index: Int
    let text: String
    let figure: String?
    let phase: DuelPhase
    let chosen: Int?
    let result: AnswerResult?
    let onPick: () -> Void

    var body: some View {
        let revealed = phase == .reveal && result != nil
        let isCorrect = revealed && result?.correctIdx == index
        let isWrongPick = revealed && chosen == index && result?.correct == false
        let isPending = phase == .submitting && chosen == index

        // Like an OMR sheet: a lettered bubble that gets filled in.
        let (fill, border, pop, bubbleFill, bubbleBorder, bubbleText): (Color, Color, Color, Color, Color, Color) =
            isCorrect ? (Theme.limeTint, Theme.lime, Color(hex: "4b5d0c"), Theme.lime, Theme.lime, Theme.ink)
            : isWrongPick ? (Theme.redTint, Theme.red, Color(hex: "5a2230"), Theme.red, Theme.red, Theme.ink)
            : isPending ? (Theme.raised, Theme.text, Color(hex: "232a3b"), Theme.text, Theme.text, Theme.ink)
            : (Theme.surface, Theme.line, revealed ? .clear : Color(hex: "232a3b"), .clear, Theme.lineStrong, Theme.muted)

        let mark = ZStack {
            Circle().fill(bubbleFill)
            Circle().strokeBorder(bubbleBorder, lineWidth: 2)
            if isCorrect {
                Image(systemName: "checkmark").font(.system(size: 12, weight: .black))
            } else {
                Text(KEYS[index]).font(.mono(13))
            }
        }
        .foregroundStyle(bubbleText)
        .frame(width: 30, height: 30)

        Button(action: onPick) {
            Group {
                if let figure {
                    ZStack(alignment: .topLeading) {
                        SVGFigure(svg: figure).padding(22).frame(maxWidth: .infinity, maxHeight: .infinity)
                        mark.padding(8)
                    }
                    .aspectRatio(1, contentMode: .fit)
                } else {
                    HStack(spacing: 14) {
                        mark
                        Text(text).font(.ui(16, .semibold)).foregroundStyle(Theme.text).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(minHeight: 60)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(OptionStyle(fill: fill, border: border, pop: pop))
        .disabled(phase != .question)
        .opacity(revealed && !isCorrect && !isWrongPick ? 0.45 : 1)
        .animation(.easeOut(duration: 0.2), value: revealed)
        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [])
        .accessibilityLabel(figure != nil ? "Option \(KEYS[index])" : "\(KEYS[index]): \(text)")
        .accessibilityValue(isCorrect ? "Correct answer" : isWrongPick ? "Your answer, wrong" : "")
    }
}

struct OptionStyle: ButtonStyle {
    let fill: Color
    let border: Color
    let pop: Color

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let pressed = configuration.isPressed
        configuration.label
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(border, lineWidth: 2))
            .offset(x: pressed ? 3 : 0, y: pressed ? 3 : 0)
            .background(shape.fill(pop).offset(x: 4, y: 4))
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
}
