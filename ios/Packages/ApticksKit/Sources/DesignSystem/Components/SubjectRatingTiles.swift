import Domain
import SwiftUI

// A player's rating in each subject, side by side, in the subjects' colours
// (Home's tabs: Aptitude lime, Coding violet, English orange). On your own
// profile a tile picks which rating the chart below shows. Port of
// web/src/components/subject-ratings.tsx.
public struct SubjectRatingTiles: View {
    let ratings: SubjectRatings
    let selected: Subject?
    let mine: Bool
    let onSelect: ((Subject) -> Void)?

    public init(ratings: SubjectRatings, selected: Subject? = nil, mine: Bool = false, onSelect: ((Subject) -> Void)? = nil) {
        self.ratings = ratings
        self.selected = selected
        self.mine = mine
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(Subject.allCases, id: \.self) { s in
                if let onSelect {
                    Button { onSelect(s) } label: { tile(s) }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected == s ? [.isSelected, .isButton] : .isButton)
                } else {
                    tile(s)
                }
            }
        }
        .animation(.snappy(duration: 0.2), value: selected)
    }

    private func tile(_ s: Subject) -> some View {
        let r = ratings[s]
        let played = (r?.games ?? 0) > 0
        let on = selected == s
        let look = Self.look(s)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(look.glyph)
                Text(s.label.uppercased())
            }
            .font(.mono(10, .bold))
            .foregroundStyle(on ? Theme.ink : look.fill)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Text(played ? grouped(r!.rating) : "—")
                .font(.display(20))
                .foregroundStyle(on ? Theme.ink : Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            // Tier and games on their own lines, so "Consultant · 12 games"
            // isn't cut short on a narrow phone.
            Group {
                if played {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tierFor(r!.rating).name)
                        Text("\(r!.games) \(r!.games == 1 ? "game" : "games")")
                    }
                } else {
                    Text(mine ? "Play your first" : "Not played yet")
                }
            }
            .font(.ui(11, .semibold))
            .foregroundStyle(on ? Theme.ink.opacity(0.8) : Theme.muted)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? look.fill : Theme.ink.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(on ? look.edge : Theme.line, lineWidth: 2))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(played ? "\(s.label) rating \(r!.rating), \(tierFor(r!.rating).name), \(r!.games) games"
                            : "\(s.label), not played yet")
    }

    public static func look(_ s: Subject) -> (glyph: String, fill: Color, edge: Color) {
        switch s {
        case .aptitude: ("Σ", Theme.lime, Theme.limeEdge)
        case .coding: ("</>", Theme.violet, Color(hex: "8676e6"))
        case .english: ("Aa", Theme.orange, Color(hex: "d4683a"))
        }
    }
}
