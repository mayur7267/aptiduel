import DesignSystem
import Domain
import SwiftUI

// A company's initials on its brand colour: "TCS", "HCL", "TM", "I".
struct CompanyMark: View {
    let company: Company
    var size: CGFloat = 36

    private var initials: String {
        let words = company.name.split(separator: " ")
        guard let first = words.first else { return "" }
        if first.count <= 4 && first == first.uppercased() { return String(first) }
        return words.prefix(2).compactMap { $0.first.map(String.init) }.joined()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * (initials.count > 2 ? 0.28 : 0.36), weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Color(hex: String(company.hex.dropFirst()))))
            .accessibilityHidden(true)
    }
}

// Your test's company first, then the rest in their usual order.
func companiesFor(test: String?) -> [Company] {
    guard let mine = company(named: test) else { return COMPANIES }
    return [mine] + COMPANIES.filter { $0 != mine }
}

// Company practice: opens the list of companies.
struct CompanyTile: View {
    let test: String?
    let onOpen: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let shown = companiesFor(test: test).prefix(3)
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: -8) {
                    ForEach(Array(shown.enumerated()), id: \.element) { i, c in
                        CompanyMark(company: c, size: 32)
                            .overlay(Circle().strokeBorder(Theme.surface, lineWidth: 2.5))
                            .zIndex(Double(3 - i))
                    }
                    Text("+\(COMPANIES.count - shown.count)")
                        .font(.mono(11))
                        .foregroundStyle(Theme.violetSoft)
                        .frame(height: 32)
                        .padding(.horizontal, 8)
                        .background(Capsule().fill(Theme.violetTint))
                        .overlay(Capsule().strokeBorder(Theme.surface, lineWidth: 2.5))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Company prep").font(.display(15)).foregroundStyle(Theme.text).lineLimit(1).minimumScaleFactor(0.8)
                    Text(company(named: test).map { "Your test: \($0.name)" } ?? "Only their tests' topics")
                        .font(.ui(12)).foregroundStyle(Theme.muted)
                }
                .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                ZStack {
                    Theme.surface
                    RadialGradient(colors: [Theme.violet.opacity(0.18), .clear], center: .topTrailing, startRadius: 0, endRadius: 180)
                }
                .clipShape(shape)
            )
            .overlay(shape.strokeBorder(Theme.violet.opacity(0.35), lineWidth: 2))
            .contentShape(shape)
        }
        .buttonStyle(CardPressStyle(radius: 20, pop: Theme.violetStrong))
        .accessibilityLabel("Company prep")
        .accessibilityHint("Pick a company for a duel on its test's topics")
    }
}

// Every company, two to a row. Tapping one starts its duel.
struct CompanySheet: View {
    let test: String?
    let onPick: (Company) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Company prep").font(.display(20)).foregroundStyle(Theme.text)
                    Text("A rated duel using only the topics on that company's aptitude test.")
                        .font(.ui(14)).foregroundStyle(Theme.muted)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(companiesFor(test: test)) { c in
                        let mine = c.name == test
                        Button { onPick(c) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    CompanyMark(company: c)
                                    Spacer(minLength: 0)
                                    if mine { Chip("Your test", fg: Theme.violet, bg: Theme.violetTint, size: 10) }
                                }
                                Text(c.name).font(.ui(15, .bold)).foregroundStyle(Theme.text).lineLimit(1)
                                Text(c.blurb).font(.ui(12)).foregroundStyle(Theme.muted)
                                    .lineLimit(2, reservesSpace: true)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card(16, fill: Theme.raised, border: mine ? Theme.violet : Theme.line, width: mine ? 2 : 1)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(c.name)
                        .accessibilityHint(c.blurb)
                    }
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.surface)
        .presentationCornerRadius(28)
    }
}
