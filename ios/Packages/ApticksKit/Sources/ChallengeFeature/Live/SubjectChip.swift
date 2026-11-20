import DesignSystem
import Domain
import SwiftUI

// Which subject a friend duel is in, in its colour (Home's tabs: Aptitude
// lime, Coding violet). Port of the chips in web/src/app/c/[code]/
// live-room.tsx.
struct SubjectChip: View {
    let subject: Subject

    var body: some View {
        let look = SubjectLook(subject)
        HStack(spacing: 7) {
            Text(look.glyph).font(.mono(14))
            Text("\(subject.label) duel").font(.ui(14, .bold))
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(look.fill))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(look.edge, lineWidth: 2))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(subject.label) duel")
    }

    // What the duel is, for the invite.
    static func line(_ s: Subject) -> String {
        switch s {
        case .coding:
            "You race through the same 5 short programs, starting together: say what each one prints. Fast and right wins. About 4 minutes."
        case .english:
            "You race through the same 5 English questions, starting together: vocabulary, grammar and usage. Fast and right wins. About 3 minutes."
        case .aptitude:
            "You race through the same 5 placement questions, starting together. Fast and right wins. About 3 minutes."
        }
    }

    // A recorded challenge's invite.
    static func intro(_ s: Subject) -> String {
        switch s {
        case .coding: "5 short programs: say what each one prints. About 4 minutes. No sign-up. Just tap play."
        case .english: "5 English questions: vocabulary, grammar and usage. About 3 minutes. No sign-up. Just tap play."
        case .aptitude: "5 placement-style questions. About 3 minutes. No sign-up. Just tap play."
        }
    }

    static func points(_ s: Subject) -> String {
        switch s {
        case .coding: "C, C++, Java, Python or pseudocode"
        case .english: "Vocabulary, grammar, usage"
        case .aptitude: "Quant and reasoning"
        }
    }
}

// The host's choice while waiting: the friend sees it change.
struct SubjectPicker: View {
    let subject: Subject
    let onPick: (Subject) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUBJECT").font(.mono(11)).tracking(1.2).foregroundStyle(Theme.faint)
            HStack(spacing: 8) {
                ForEach(Subject.allCases, id: \.self) { s in
                    let look = SubjectLook(s)
                    let on = s == subject
                    Button { onPick(s) } label: {
                        HStack(spacing: 7) {
                            Text(look.glyph).font(.mono(15))
                            Text(s.label).font(.ui(15, .bold))
                        }
                        .foregroundStyle(on ? Theme.ink : look.fill)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? look.fill : Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(on ? look.edge : Theme.line, lineWidth: 2))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(s.label)
                    .accessibilityIdentifier("room-subject-\(s.rawValue)")
                    .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
                }
            }
            .animation(.snappy(duration: 0.2), value: subject)
        }
    }
}

private struct SubjectLook {
    let glyph: String
    let fill: Color
    let edge: Color

    init(_ s: Subject) {
        switch s {
        case .aptitude: (glyph, fill, edge) = ("Σ", Theme.lime, Theme.limeEdge)
        case .coding: (glyph, fill, edge) = ("</>", Theme.violet, Color(hex: "8676e6"))
        case .english: (glyph, fill, edge) = ("Aa", Theme.orange, Color(hex: "d4683a"))
        }
    }
}
