import DesignSystem
import Domain
import SwiftUI

private let DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
private let MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

// A tear-off calendar page showing today's date.
struct CalendarPage: View {
    let date: Date
    var body: some View {
        let cal = Calendar.current
        VStack(spacing: 0) {
            Text(MONTHS[cal.component(.month, from: date) - 1])
                .font(.mono(9))
                .tracking(1)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 18)
                .background(Theme.violet)
                .overlay(alignment: .top) {
                    HStack {
                        Circle().fill(Theme.ink.opacity(0.5)).frame(width: 5, height: 5)
                        Spacer()
                        Circle().fill(Theme.ink.opacity(0.5)).frame(width: 5, height: 5)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
                }
            Text("\(cal.component(.day, from: date))")
                .font(.display(20))
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 3)
        }
        .frame(width: 50)
        .background(Theme.text)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .sticker(10, pop: Theme.violetStrong, offset: 3)
        .rotationEffect(.degrees(6))
        .accessibilityHidden(true)
    }
}

// Today's set, the week as a row of answer-sheet bubbles, and the button.
struct DailyPage: View {
    let me: Me
    let now: Date
    let busy: HomeAction?
    let onPlay: () -> Void
    let onCalendar: () -> Void

    var body: some View {
        let doneToday = me.quests.daily > 0
        PinnedBottom {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily Challenge").font(.display(19)).foregroundStyle(Theme.text)
                    (Text("Same 5 for everyone · ").foregroundColor(Theme.violetSoft.opacity(0.8))
                        + Text("new in \(untilIstMidnight(now))").font(.mono(12, .medium)).foregroundColor(Theme.violet))
                        .font(.ui(13))
                }
                Spacer(minLength: 0)
                Button(action: onCalendar) { CalendarPage(date: now) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Daily calendar")
            }
            HStack {
                Text("THIS WEEK").font(.mono(10)).tracking(1.2).foregroundStyle(Theme.violetSoft.opacity(0.6))
                Spacer()
                Button(action: onCalendar) {
                    HStack(spacing: 3) {
                        Text("View all")
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.ui(12, .semibold))
                .foregroundStyle(Theme.violet)
                .padding(.vertical, -8)
                .accessibilityLabel("View all days")
            }
            .padding(.bottom, -4)
            // The week as an OMR row: a bubble per day, filled in when done.
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let done = i < me.dailyWeek.count && me.dailyWeek[i]
                    let today = i == me.todayIdx
                    Group {
                        if done {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(Theme.ink)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Theme.lime))
                                .popIn(Double(i) * 0.06)
                        } else {
                            Text(String(DAYS[i].prefix(1)))
                                .font(.mono(11))
                                .foregroundStyle(today ? Theme.lime : Theme.faint)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().strokeBorder(today ? Theme.lime : .white.opacity(0.15),
                                                               style: StrokeStyle(lineWidth: 2, dash: today ? [4, 3] : [])))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(DAYS[i] + (done ? ", done" : today ? ", today" : ""))
                }
            }
        } bottom: {
            Button(busy == .daily ? "Opening…" : doneToday ? "See today's rank" : "Play today's set", action: onPlay)
                .buttonStyle(doneToday
                    ? PressableStyle(fill: Theme.violetTint, foreground: Theme.violetSoft, pop: Color(hex: "2c2660"),
                                     border: Theme.violet.opacity(0.4), height: 44)
                    : PressableStyle(fill: Theme.text, foreground: Theme.ink, pop: Theme.violetStrong, height: 44))
                .disabled(busy != nil)
        }
        .sensoryFeedback(.success, trigger: doneToday) { was, now in !was && now }
        .deckPage(
            LinearGradient(stops: [.init(color: Theme.violetDeep, location: 0), .init(color: Theme.surface, location: 0.7)],
                           startPoint: UnitPoint(x: 0.25, y: 0), endPoint: UnitPoint(x: 0.75, y: 1)),
            border: Theme.violetStrong, pop: Color(hex: "2c2660"))
    }
}
