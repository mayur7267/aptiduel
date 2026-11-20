import AppCore
import DesignSystem
import Domain
import SwiftUI

// Quick Match in a subject, like the website's (web/src/app/(app)/play-card.tsx):
// four binder tabs, one colour each, so the subjects read at a glance; the
// open tab lifts into the card below it. Playing stays one tap.
//
// Picking a tab fills it with its colour from the bottom up, and the colour
// pours down out of the tab into the card with a soft edge, first running
// down like a pour, then widening until it covers the whole card. The old
// card stays underneath until it's covered. With Reduce Motion it's instant.
//
// The choice (and Coding's language) is remembered, with the same keys the
// website uses in the browser.
struct SubjectPlayCard: View {
    let rating: Int
    let coding: SubjectRating?
    let english: SubjectRating?
    let onPlay: (Subject) -> Void

    // GK shows as "coming soon". App Review can reject apps for
    // unfinished features (guideline 2.1): set false to hide them in a build.
    static let showComingSoon = true

    static let pourSeconds = 0.65
    static let riseSeconds = 0.26

    @AppStorage("apticks-subject") private var storedTab = SubjectTab.aptitude.rawValue
    @AppStorage("apticks-code-lang") private var storedLang = CodeLang.c.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // The open tab, kept here (and saved): the card and the tabs always
    // agree, even mid-pour.
    @State private var shown: SubjectTab?
    // The card being poured over, until it's covered.
    @State private var under: SubjectTab?
    // 0 → 1 while the new card pours in; 1 when it's settled.
    @State private var progress: Double = 1
    @State private var pours = 0

    private var tabs: [SubjectTab] { SubjectTab.allCases.filter { Self.showComingSoon || !$0.soon } }
    private var tab: SubjectTab {
        let t = shown ?? SubjectTab(rawValue: storedTab) ?? .aptitude
        return tabs.contains(t) ? t : .aptitude
    }
    private var lang: CodeLang { CodeLang(rawValue: storedLang) ?? .c }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: PourShape.gap) {
                ForEach(tabs) { t in
                    SubjectTabButton(tab: t, on: t == tab) { select(t) }
                }
            }
            .padding(.horizontal, PourShape.inset)
            .tourTarget("subjects")
            .zIndex(1)

            // Every subject's card, hidden, sets the size: the tallest wins,
            // so all four cards are the same height and switching never jumps.
            ZStack {
                ForEach(tabs) { panel($0).hidden() }
            }
            .accessibilityHidden(true)
            .overlay(alignment: .top) {
                ZStack(alignment: .top) {
                    if let under {
                        panel(under).allowsHitTesting(false).accessibilityHidden(true)
                    }
                    panel(tab)
                        .mask {
                            PourShape(progress: progress, slot: tabs.firstIndex(of: tab) ?? 0, slots: tabs.count)
                                .fill()
                                // Soft while pouring; crisp once settled.
                                .blur(radius: under == nil ? 0 : 14)
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func panel(_ t: SubjectTab) -> some View {
        switch t {
        case .aptitude: QuickMatchCard(rating: rating) { onPlay(.aptitude) }
        case .coding: CodingCard(lang: lang, coding: coding, onPlay: { onPlay(.coding) }, onLang: { storedLang = $0.rawValue })
        case .english: EnglishCard(english: english) { onPlay(.english) }
        case .gk: SoonCard(tab: t) { select(.aptitude) }
        }
    }

    private func select(_ t: SubjectTab) {
        let old = tab
        guard t != old else { return }
        storedTab = t.rawValue
        // The swap itself never animates: the old card goes underneath and
        // the new one starts fully hidden, then pours in.
        var swap = Transaction()
        swap.disablesAnimations = true
        if reduceMotion {
            withTransaction(swap) {
                under = nil
                shown = t
                progress = 1
            }
            return
        }
        pours += 1
        let pour = pours
        withTransaction(swap) {
            under = old
            shown = t
            progress = 0
        }
        DispatchQueue.main.async {
            withAnimation(.timingCurve(0.5, 0, 0.25, 1, duration: Self.pourSeconds)) {
                progress = 1
            } completion: {
                // Another tap may have started a newer pour meanwhile.
                if pours == pour { under = nil }
            }
        }
    }
}

// The window the new card shows through: an ellipse centred on the middle
// of the tab's bottom edge, tall and narrow while it runs down, then wide
// enough to cover the whole card. Blurred, its edge is a soft gradient.
// A Shape, so SwiftUI animates `progress` frame by frame.
nonisolated struct PourShape: Shape {
    var progress: Double
    let slot: Int
    let slots: Int

    // Where the tabs sit on the card's flat top edge.
    static let inset: CGFloat = 20
    static let gap: CGFloat = 6

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        if progress >= 1 { return Path(rect.insetBy(dx: -60, dy: -60)) }
        let s = Self.slot(slot, of: slots, width: rect.width)
        let size = Self.size(progress, w: rect.width, h: rect.height, mid: s.mid, tab: s.width)
        return Path(ellipseIn: CGRect(x: rect.minX + s.mid - size.width / 2, y: rect.minY - size.height / 2,
                                      width: size.width, height: size.height))
    }

    // The middle of a tab and its width, across the card.
    static func slot(_ i: Int, of count: Int, width: CGFloat) -> (mid: CGFloat, width: CGFloat) {
        let w = max(0, (width - 2 * inset - CGFloat(count - 1) * gap) / CGFloat(max(count, 1)))
        return (inset + CGFloat(i) * (w + gap) + w / 2, w)
    }

    static func size(_ p: Double, w: CGFloat, h: CGFloat, mid: CGFloat, tab: CGFloat) -> CGSize {
        let start = CGSize(width: tab * 0.6, height: 0)
        let pour = CGSize(width: tab * 1.5, height: h * 1.3)
        let full = CGSize(width: 5.2 * max(mid, w - mid), height: 5.2 * h)
        let lerp = { (a: CGSize, b: CGSize, t: CGFloat) in
            CGSize(width: a.width + (b.width - a.width) * t, height: a.height + (b.height - a.height) * t)
        }
        let t = CGFloat(max(0, min(1, p)))
        return t < 0.38 ? lerp(start, pour, t / 0.38) : lerp(pour, full, (t - 0.38) / 0.62)
    }
}

// MARK: Tabs

private struct TabLook {
    let base: Color, fill: Color
    let onEdge: Color, offEdge: Color
    let onText: Color, offText: Color

    init(_ tab: SubjectTab) {
        switch tab {
        case .aptitude:
            (base, fill, onEdge, offEdge, onText, offText) = (Theme.limeTint, Theme.lime, Theme.limeEdge, Color(hex: "3d4a14"), Theme.ink, Theme.lime)
        case .coding:
            (base, fill, onEdge, offEdge, onText, offText) = (Theme.violetTint, Theme.violet, CodingCard.edge, Theme.violetStrong, Theme.ink, Theme.violet)
        case .english:
            (base, fill, onEdge, offEdge, onText, offText) = (Theme.orangeTint, Theme.orange, EnglishCard.edge, Color(hex: "5a3420"), Theme.ink, Theme.orange)
        case .gk:
            (base, fill, onEdge, offEdge, onText, offText) = (Color(hex: "0e1a21"), SoonCard.gkFill, SoonCard.gkEdge, Color(hex: "1f3a48"),
                                                            SoonCard.gkAccent, SoonCard.gkAccent.opacity(0.8))
        }
    }
}

// A tab's outline: rounded on top, and open at the bottom when stroked so
// the open tab runs straight into its card.
nonisolated private struct TabShape: Shape {
    var open = false

    func path(in r: CGRect) -> Path {
        let c: CGFloat = 14
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.addQuadCurve(to: CGPoint(x: r.minX + c, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + c), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        if !open { p.closeSubpath() }
        return p
    }
}

private struct SubjectTabButton: View {
    let tab: SubjectTab
    let on: Bool
    let action: () -> Void

    var body: some View {
        let look = TabLook(tab)
        Button(action: action) {
            VStack(spacing: 4) {
                Text(tab.glyph).font(.mono(17))
                Text(tab.label).font(.ui(12, .bold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(on ? look.onText : look.offText)
            .frame(maxWidth: .infinity)
            .frame(height: on ? 60 : 52)
            .background {
                ZStack(alignment: .bottom) {
                    TabShape().fill(look.base)
                    // The open colour rises from the bottom edge.
                    TabShape().fill(look.fill).scaleEffect(x: 1, y: on ? 1 : 0, anchor: .bottom)
                }
            }
            .overlay { TabShape(open: true).stroke(on ? look.onEdge : look.offEdge, lineWidth: 2) }
            .overlay(alignment: .topTrailing) {
                if tab.soon {
                    Text("SOON")
                        .font(.mono(8))
                        .tracking(0.8)
                        .foregroundStyle(Theme.soft)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Theme.ink))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.lineStrong, lineWidth: 1))
                        .rotationEffect(.degrees(6))
                        .offset(x: -2, y: -8)
                }
            }
            .contentShape(TabShape())
        }
        .buttonStyle(.plain)
        // The open tab overlaps the card's top border, so they read as one.
        .offset(y: on ? 2 : 0)
        .animation(.easeOut(duration: SubjectPlayCard.riseSeconds), value: on)
        .accessibilityLabel(tab.soon ? "\(tab.label), coming soon" : tab.label)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: Cards

// Coding's card: violet, with the language you read code in.
struct CodingCard: View {
    let lang: CodeLang
    let coding: SubjectRating?
    let onPlay: () -> Void
    let onLang: (CodeLang) -> Void

    static let edge = Color(hex: "8676e6")
    static let pop = Color(hex: "4b3fa6")
    static let ink = Color(hex: "241d5c")

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onPlay) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1V1 · CODING")
                            .font(.mono(11))
                            .tracking(1.2)
                            .foregroundStyle(Theme.lime)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.ink))
                            .rotationEffect(.degrees(-3))
                            .padding(.bottom, 2)
                        Text("Quick Match").font(.display(22)).foregroundStyle(Theme.ink)
                        Text("Read the code, call the output · 4 min").font(.ui(13, .medium)).foregroundStyle(Self.ink)
                        Label(ratingLine, systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.ui(12, .bold))
                            .foregroundStyle(Self.ink.opacity(0.8))
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    VStack(spacing: 2) {
                        Image(systemName: "bolt.fill").font(.system(size: 22, weight: .black))
                        Text("PLAY").font(.display(11))
                    }
                    .foregroundStyle(Theme.violet)
                    .frame(width: 62, height: 62)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.ink))
                    .sticker(18, pop: Self.pop)
                    .rotationEffect(.degrees(6))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Coding Quick Match")
            .accessibilityHint("5 short programs: say what each one prints. About 4 minutes.")

            Spacer(minLength: 12)
            HStack(spacing: 6) {
                ForEach(CodeLang.allCases) { l in
                    Button { onLang(l) } label: {
                        Text(l.label)
                            .font(.mono(12))
                            .foregroundStyle(l == lang ? Theme.violet : Theme.ink)
                            .padding(.horizontal, 9)
                            .frame(height: 30)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(l == lang ? Theme.ink : Theme.ink.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show code in \(l.label)")
                    .accessibilityAddTraits(l == lang ? [.isSelected, .isButton] : .isButton)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            ZStack {
                shape.fill(Self.pop).offset(x: 4, y: 4)
                shape.fill(Theme.violet)
                Stripes(color: Theme.ink.opacity(0.04)).clipShape(shape)
            }
        }
        .overlay(shape.strokeBorder(Self.edge, lineWidth: 2))
    }

    private var ratingLine: String {
        guard let coding, coding.games > 0 else { return "C, C++, Java, Python or pseudocode" }
        return "Coding rating \(coding.rating)"
    }
}

// GK until it's ready: what's coming, and a way back to play.
struct SoonCard: View {
    let tab: SubjectTab
    let onBack: () -> Void

    static let gkFill = Color(hex: "10222c")
    static let gkEdge = Color(hex: "2f6f8f")
    static let gkAccent = Color(hex: "6cc7ff")

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("COMING SOON")
                    .font(.mono(11))
                    .tracking(1.2)
                    .foregroundStyle(Self.gkAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.ink))
                    .rotationEffect(.degrees(-3))
                Text(tab.label).font(.display(22)).foregroundStyle(Theme.text)
                Text("Static GK and current affairs for bank and government exams.")
                    .font(.ui(13))
                    .foregroundStyle(Theme.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button(action: onBack) {
                Label("Play Aptitude meanwhile", systemImage: "bolt.fill").font(.ui(14, .bold))
            }
            .buttonStyle(FilledStyle(fill: Theme.ink, foreground: Theme.text, border: Theme.line, radius: 12, height: 44))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            ZStack {
                shape.fill(Color(hex: "0b1a22")).offset(x: 4, y: 4)
                shape.fill(Self.gkFill)
            }
        }
        .overlay(shape.strokeBorder(Self.gkEdge, lineWidth: 2))
    }
}

// English's card: orange, with what the questions cover along the bottom
// (where Coding has its languages).
struct EnglishCard: View {
    let english: SubjectRating?
    let onPlay: () -> Void

    static let edge = Color(hex: "d4683a")
    static let pop = Color(hex: "9c4a1f")
    static let ink = Color(hex: "4a1f08")

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1V1 · ENGLISH")
                            .font(.mono(11))
                            .tracking(1.2)
                            .foregroundStyle(Theme.lime)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.ink))
                            .rotationEffect(.degrees(-3))
                            .padding(.bottom, 2)
                        Text("Quick Match").font(.display(22)).foregroundStyle(Theme.ink)
                        Text("Words, grammar and usage · 3 min").font(.ui(13, .medium)).foregroundStyle(Self.ink)
                        Label(ratingLine, systemImage: "character.book.closed")
                            .font(.ui(12, .bold))
                            .foregroundStyle(Self.ink.opacity(0.8))
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    VStack(spacing: 2) {
                        Image(systemName: "bolt.fill").font(.system(size: 22, weight: .black))
                        Text("PLAY").font(.display(11))
                    }
                    .foregroundStyle(Theme.orange)
                    .frame(width: 62, height: 62)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.ink))
                    .sticker(18, pop: Self.pop)
                    .rotationEffect(.degrees(6))
                }
                Spacer(minLength: 12)
                Text("Synonyms · Idioms · Grammar · Voice")
                    .font(.mono(12))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.ink.opacity(0.1)))
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                ZStack {
                    shape.fill(Self.pop).offset(x: 4, y: 4)
                    shape.fill(Theme.orange)
                    Stripes(color: Theme.ink.opacity(0.04)).clipShape(shape)
                }
            }
            .overlay(shape.strokeBorder(Self.edge, lineWidth: 2))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("English Quick Match")
        .accessibilityHint("5 questions on vocabulary, grammar and usage. About 3 minutes.")
    }

    private var ratingLine: String {
        guard let english, english.games > 0 else { return "A rating of its own" }
        return "English rating \(english.rating)"
    }
}
