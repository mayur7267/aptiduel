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
                .font(.mono(10))
                .tracking(1)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 20)
                .background(Theme.violet)
                .overlay(alignment: .top) {
                    HStack {
                        Circle().fill(Theme.ink.opacity(0.5)).frame(width: 6, height: 6)
                        Spacer()
                        Circle().fill(Theme.ink.opacity(0.5)).frame(width: 6, height: 6)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 2)
                }
            Text("\(cal.component(.day, from: date))")
                .font(.display(24))
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 4)
        }
        .frame(width: 58)
        .background(Theme.text)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .sticker(12, pop: Theme.violetStrong)
        .rotationEffect(.degrees(6))
        .accessibilityHidden(true)
    }
}

struct DailyCard: View {
    let me: Me
    let now: Date
    let busy: HomeAction?
    let onPlay: () -> Void

    var body: some View {
        let doneToday = me.quests.daily > 0
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Challenge").font(.display(20)).foregroundStyle(Theme.text)
                    Text("5 questions · same for everyone").font(.ui(14)).foregroundStyle(Theme.violetSoft.opacity(0.8))
                    Text("New set in \(untilIstMidnight(now))").font(.mono(12, .medium)).foregroundStyle(Theme.violet)
                }
                Spacer()
                CalendarPage(date: now)
            }
            // The week as an OMR row: a bubble per day, filled in when done.
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let done = i < me.dailyWeek.count && me.dailyWeek[i]
                    let today = i == me.todayIdx
                    Group {
                        if done {
                            Image(systemName: "checkmark").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.ink)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Theme.lime))
                                .popIn(Double(i) * 0.06)
                        } else {
                            Text(String(DAYS[i].prefix(1)))
                                .font(.mono(11))
                                .foregroundStyle(today ? Theme.lime : Theme.faint)
                                .frame(width: 30, height: 30)
                                .overlay(Circle().strokeBorder(today ? Theme.lime : .white.opacity(0.15),
                                                               style: StrokeStyle(lineWidth: 2, dash: today ? [4, 3] : [])))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(DAYS[i] + (done ? ", done" : today ? ", today" : ""))
                }
            }
            .padding(.top, 4)
            Button(busy == .daily ? "Opening…" : doneToday ? "See today's rank" : "Play today's set", action: onPlay)
                .buttonStyle(doneToday
                    ? PressableStyle(fill: Theme.violetTint, foreground: Theme.violetSoft, pop: Color(hex: "2c2660"), border: Theme.violet.opacity(0.4))
                    : PressableStyle(fill: Theme.text, foreground: Theme.ink, pop: Theme.violetStrong))
                .disabled(busy != nil)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(stops: [.init(color: Theme.violetDeep, location: 0), .init(color: Theme.surface, location: 0.7)],
                           startPoint: UnitPoint(x: 0.25, y: 0), endPoint: UnitPoint(x: 0.75, y: 1))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.violetStrong, lineWidth: 2))
        .sticker(22, pop: Color(hex: "2c2660"))
    }
}
