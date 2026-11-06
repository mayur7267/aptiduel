import Domain
import Foundation
import Networking

// The calendar behind the Daily card: every day you finished the Daily
// Challenge, a month at a time. Days are IST, like the server's.
@MainActor
@Observable
public final class DailyCalendarViewModel {
    public struct Day: Identifiable, Hashable, Sendable {
        public let id: String // yyyy-MM-dd, or "blank-n" around the month
        public let number: Int? // nil for the blanks
        public let done: Bool
        public let isToday: Bool
        public let future: Bool
    }

    public private(set) var days: Set<String> = []
    public private(set) var error: String?
    // The first of the month on show.
    public private(set) var month: Date

    private let api: any APIClient
    private let now: () -> Date

    nonisolated static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        c.firstWeekday = 2 // Monday, like the week on the card
        c.locale = Locale(identifier: "en_IN")
        return c
    }()

    private var cal: Calendar { Self.calendar }

    public init(api: any APIClient, now: @escaping () -> Date = Date.init) {
        self.api = api
        self.now = now
        month = Self.calendar.dateInterval(of: .month, for: now())!.start
    }

    // This week from home, which already has it, so the calendar never
    // opens empty; then the rest from the server.
    public func seed(week: [Bool], todayIdx: Int) {
        for (i, done) in week.enumerated() where done {
            if let d = cal.date(byAdding: .day, value: i - todayIdx, to: now()) { days.insert(key(d)) }
        }
    }

    public func load() async {
        do {
            days.formUnion(try await api.dailyDays())
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: The month on show

    public var today: String { key(now()) }

    public var monthTitle: String {
        let f = DateFormatter()
        f.calendar = cal
        f.timeZone = cal.timeZone
        f.locale = cal.locale
        f.dateFormat = "LLLL yyyy"
        return f.string(from: month)
    }

    // Monday first.
    public var weekdays: [String] {
        let s = cal.veryShortStandaloneWeekdaySymbols
        return Array(s[1...] + s[..<1])
    }

    // The month in six weeks of seven, blanks before the 1st and after
    // the last, so the calendar keeps its height from month to month.
    public var weeks: [[Day]] {
        let count = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        let today = today
        var cells = (0..<lead).map { Day(id: "blank-\($0)", number: nil, done: false, isToday: false, future: false) }
        for n in 1...count {
            let k = key(cal.date(byAdding: .day, value: n - 1, to: month)!)
            cells.append(Day(id: k, number: n, done: days.contains(k), isToday: k == today, future: k > today))
        }
        while cells.count < 42 {
            cells.append(Day(id: "blank-\(cells.count)", number: nil, done: false, isToday: false, future: false))
        }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    public var doneInMonth: Int { weeks.joined().filter(\.done).count }

    private var thisMonth: Date { cal.dateInterval(of: .month, for: now())!.start }

    // Back as far as your first Daily.
    private var firstMonth: Date {
        guard let first = days.min().flatMap(date(from:)) else { return thisMonth }
        return min(cal.dateInterval(of: .month, for: first)!.start, thisMonth)
    }

    public var canGoBack: Bool { month > firstMonth }
    public var canGoForward: Bool { month < thisMonth }

    public func previous() {
        if canGoBack { month = cal.date(byAdding: .month, value: -1, to: month)! }
    }

    public func next() {
        if canGoForward { month = cal.date(byAdding: .month, value: 1, to: month)! }
    }

    // MARK: Runs

    public var total: Int { days.count }

    // The most days in a row.
    public var bestRun: Int {
        let dates = days.sorted().compactMap(date(from:))
        var best = 0
        var run = 0
        var last: Date?
        for d in dates {
            run = last.map { cal.dateComponents([.day], from: $0, to: d).day == 1 } == true ? run + 1 : 1
            best = max(best, run)
            last = d
        }
        return best
    }

    // Days in a row up to today, or up to yesterday while today's is open.
    public var currentRun: Int {
        var day = days.contains(today) ? now() : cal.date(byAdding: .day, value: -1, to: now())!
        var run = 0
        while days.contains(key(day)) {
            run += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return run
    }

    // MARK: Private

    private var format: DateFormatter {
        let f = DateFormatter()
        f.calendar = cal
        f.timeZone = cal.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    private func key(_ date: Date) -> String { format.string(from: date) }
    private func date(from key: String) -> Date? { format.date(from: key) }
}
