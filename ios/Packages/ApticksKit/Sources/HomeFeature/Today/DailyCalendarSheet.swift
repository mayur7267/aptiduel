import DesignSystem
import Domain
import SwiftUI

// Every day you finished the Daily Challenge, a month at a time. Days in
// a row join into one band, so a run reads at a glance.
struct DailyCalendarSheet: View {
    let model: DailyCalendarViewModel
    let me: Me
    let busy: HomeAction?
    let onPlay: () -> Void
    @State private var height: CGFloat = 600

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily calendar").font(.display(20)).foregroundStyle(Theme.text)
                Text("Every day you finished the Daily Challenge.").font(.ui(14)).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 10) {
                stat(model.currentRun, "in a row", icon: "flame.fill", color: Theme.orange)
                stat(model.bestRun, "best run", icon: "trophy.fill", color: Theme.violet)
                stat(model.total, "all time", icon: "checkmark.circle.fill", color: Theme.lime)
            }
            month
            if let error = model.error { ErrorNote(error) { Task { await model.load() } } }
            if me.quests.daily == 0 {
                Button(busy == .daily ? "Opening…" : "Play today's set", action: onPlay)
                    .buttonStyle(PressableStyle(fill: Theme.text, foreground: Theme.ink, pop: Theme.violetStrong))
                    .disabled(busy != nil)
            }
        }
        .padding(24)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.surface)
        .presentationCornerRadius(28)
        .task {
            model.seed(week: me.dailyWeek, todayIdx: me.todayIdx)
            await model.load()
        }
    }

    private var month: some View {
        VStack(spacing: 10) {
            HStack {
                arrow("chevron.left", label: "Previous month", enabled: model.canGoBack) { model.previous() }
                Spacer()
                VStack(spacing: 2) {
                    Text(model.monthTitle).font(.ui(16, .bold)).foregroundStyle(Theme.text)
                    Text(model.doneInMonth == 1 ? "1 day done" : "\(model.doneInMonth) days done")
                        .font(.ui(12)).foregroundStyle(Theme.muted)
                }
                Spacer()
                arrow("chevron.right", label: "Next month", enabled: model.canGoForward) { model.next() }
            }
            HStack(spacing: 0) {
                ForEach(Array(model.weekdays.enumerated()), id: \.offset) { _, d in
                    Text(d).font(.mono(11)).foregroundStyle(Theme.faint).frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            VStack(spacing: 6) {
                ForEach(model.weeks, id: \.first?.id) { week in
                    HStack(spacing: 0) {
                        ForEach(Array(week.enumerated()), id: \.element.id) { i, day in
                            cell(day, joinsLeft: day.done && i > 0 && week[i - 1].done,
                                 joinsRight: day.done && i < 6 && week[i + 1].done)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 24).onEnded { v in
                if v.translation.width < -40 { withAnimation(.snappy) { model.next() } }
                if v.translation.width > 40 { withAnimation(.snappy) { model.previous() } }
            })
        }
        .padding(14)
        .card(18, fill: Theme.raised)
        .animation(.snappy, value: model.month)
    }

    private func cell(_ day: DailyCalendarViewModel.Day, joinsLeft: Bool, joinsRight: Bool) -> some View {
        let band = Theme.lime.opacity(0.3)
        return ZStack {
            HStack(spacing: 0) {
                Rectangle().fill(joinsLeft ? band : .clear)
                Rectangle().fill(joinsRight ? band : .clear)
            }
            .frame(height: 28)
            if let n = day.number {
                Text("\(n)")
                    .font(.mono(13, day.done ? .heavy : .medium))
                    .foregroundStyle(day.done ? Theme.ink : day.isToday ? Theme.lime : day.future ? Theme.faint.opacity(0.45) : Theme.muted)
                    .frame(width: 36, height: 36)
                    .background { if day.done { Circle().fill(Theme.lime) } }
                    .overlay {
                        if day.isToday && !day.done {
                            Circle().strokeBorder(Theme.lime, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.number.map { "\(model.monthTitle.split(separator: " ").first ?? "") \($0)" } ?? "")
        .accessibilityValue(day.done ? "Done" : day.isToday ? "Today" : "")
        .accessibilityHidden(day.number == nil)
    }

    private func stat(_ value: Int, _ label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
            Text("\(value)").font(.mono(22)).foregroundStyle(Theme.text)
                .contentTransition(.numericText(value: Double(value)))
            Text(label).font(.ui(12)).foregroundStyle(Theme.muted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(16, fill: Theme.raised)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }

    private func arrow(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { action() } } label: {
            Image(systemName: icon).font(.system(size: 14, weight: .bold))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.surface))
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Theme.text : Theme.faint.opacity(0.4))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
