import AppCore
import DesignSystem
import Domain
import SwiftUI

// The pages of home's Today deck.
public enum TodayPage: String, CaseIterable, Hashable, Sendable {
    case daily, goals, test
}

extension View {
    // A page of the Today deck. Pages stretch to the tallest one, so the
    // deck keeps its height while you swipe.
    func deckPage(_ fill: some View, border: Color = Theme.line, pop: Color = Theme.pop) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(fill.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(border, lineWidth: 2))
            .sticker(22, pop: pop)
    }
}

// A deck page's content, with its buttons pinned to the bottom. Unlike a
// Spacer, this adds no height of its own, so the deck stays compact.
struct PinnedBottom<Top: View, Bottom: View>: View {
    @ViewBuilder var top: Top
    @ViewBuilder var bottom: Bottom

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) { top }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            bottom
        }
    }
}

// Today's Daily Challenge, goals and placement test as one swipeable
// card. The tabs above say what's on each page before you swipe to it.
struct TodayDeck: View {
    let me: Me
    let now: Date
    let busy: HomeAction?
    let drive: DriveViewModel
    @Binding var page: TodayPage?
    let onDaily: () -> Void
    let onCalendar: () -> Void
    let onGoal: (Goal.Action) -> Void
    @Namespace private var tabs

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                tab(.daily, "Daily", label: "Daily Challenge", dot: me.quests.daily == 0)
                tab(.goals, "Goals", label: "Today's goals", detail: "\(me.goalsDone)/\(me.goals.count)")
                tab(.test, "Test", label: "Placement test", detail: testDetail, dot: drive.stage == .howDidItGo)
                Spacer(minLength: 0)
            }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 24) {
                    DailyPage(me: me, now: now, busy: busy, onPlay: onDaily, onCalendar: onCalendar)
                        .tourTarget("daily")
                        .containerRelativeFrame(.horizontal)
                        .id(TodayPage.daily)
                    GoalsPage(me: me, busy: busy, onAction: onGoal)
                        .tourTarget("goals")
                        .containerRelativeFrame(.horizontal)
                        .id(TodayPage.goals)
                    TestPage(model: drive)
                        .containerRelativeFrame(.horizontal)
                        .id(TodayPage.test)
                }
                .fixedSize(horizontal: false, vertical: true)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .padding(.horizontal, -16)
        }
    }

    private var testDetail: String? {
        switch drive.stage {
        case let .upcoming(days): "\(days)d"
        case .today: "today"
        default: nil
        }
    }

    private func tab(_ p: TodayPage, _ title: String, label: String, detail: String? = nil, dot: Bool = false) -> some View {
        let selected = (page ?? .daily) == p
        return Button {
            withAnimation(.snappy) { page = p }
        } label: {
            HStack(spacing: 5) {
                Text(title).font(.ui(13, .bold))
                if let detail {
                    Text(detail).font(.mono(12, .semibold)).foregroundStyle(selected ? Theme.lime : Theme.faint)
                }
                if dot { Circle().fill(Theme.lime).frame(width: 6, height: 6) }
            }
            .foregroundStyle(selected ? Theme.text : Theme.muted)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background {
                if selected {
                    Capsule().fill(Theme.raised)
                        .overlay(Capsule().strokeBorder(Theme.lineStrong))
                        .matchedGeometryEffect(id: "tab", in: tabs)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(detail ?? "")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: selected) { _, now in now }
    }
}
