import Foundation
import UserNotifications

// An evening nudge on days you haven't played the Daily. The phone sets
// them itself (no server or push): the next week's 8 pm reminders are
// planned whenever the app learns how today is going, so a day you've
// already played gets none, and if you stop opening the app they stop
// after a week instead of nagging for ever.
nonisolated public struct Reminder: Equatable, Sendable {
    public let id: String
    public let fire: DateComponents
    public let title: String
    public let body: String
}

nonisolated public enum ReminderPlan {
    public static let hour = 20
    public static let prefix = "apticks-daily-"
    public static let days = 7

    public static func next(now: Date, calendar: Calendar, doneToday: Bool, streak: Int) -> [Reminder] {
        let today = calendar.startOfDay(for: now)
        var plan: [Reminder] = []
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                  fire > now,
                  !(offset == 0 && doneToday)
            else { continue }
            var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            parts.calendar = calendar
            parts.timeZone = calendar.timeZone
            // Only the next one can count on the streak still being alive.
            let body = plan.isEmpty && streak >= 2
                ? "Don't lose your \(streak)-day streak 🔥 5 questions, about 3 minutes."
                : "5 new placement questions, the same for everyone. About 3 minutes."
            let key = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            plan.append(Reminder(id: prefix + key, fire: parts, title: "Today's Daily is ready ⚡", body: body))
        }
        return plan
    }
}

// The system's notification centre, behind a protocol for tests.
nonisolated public protocol ReminderCenter: Sendable {
    func authorized() async -> Bool?  // nil: never asked
    func requestAuthorization() async -> Bool
    func pending() async -> [String]
    func remove(_ ids: [String]) async
    func add(_ reminder: Reminder) async
}

nonisolated public struct SystemReminderCenter: ReminderCenter {
    public init() {}

    private var center: UNUserNotificationCenter { .current() }

    public func authorized() async -> Bool? {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: nil
        case .denied: false
        default: true
        }
    }

    public func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    public func pending() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    public func remove(_ ids: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    public func add(_ reminder: Reminder) async {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: reminder.fire, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
    }
}

@MainActor
@Observable
public final class ReminderState {
    private enum Key {
        static let on = "apticks-reminder-on"
        static let offered = "apticks-reminder-offered"
    }

    public private(set) var on: Bool
    // The offer after a Daily was answered (yes or no), so it isn't repeated.
    public private(set) var offered: Bool
    // Notifications are off for Apticks in Settings: only Settings can fix it.
    public private(set) var blocked = false

    private let defaults: UserDefaults
    private let center: any ReminderCenter
    private let calendar: Calendar
    private let now: () -> Date
    private var last: (doneToday: Bool, streak: Int) = (false, 0)

    public init(defaults: UserDefaults = .standard, center: any ReminderCenter = SystemReminderCenter(),
                calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.center = center
        self.calendar = calendar
        self.now = now
        on = defaults.bool(forKey: Key.on)
        offered = defaults.bool(forKey: Key.offered)
    }

    // Offer reminders once, after a finished Daily.
    public var shouldOffer: Bool { !on && !offered }

    public func dismissOffer() {
        offered = true
        defaults.set(true, forKey: Key.offered)
    }

    // Asks the system the first time. False if the player said no. Pass
    // how today is going when it's known (on a Daily's result).
    @discardableResult
    public func turnOn(doneToday: Bool? = nil, streak: Int? = nil) async -> Bool {
        if let doneToday { last.doneToday = doneToday }
        if let streak { last.streak = streak }
        dismissOffer()
        let allowed = await center.authorized() == true ? true : await center.requestAuthorization()
        blocked = !allowed
        guard allowed else { return false }
        on = true
        defaults.set(true, forKey: Key.on)
        await reschedule()
        return true
    }

    public func turnOff() async {
        on = false
        defaults.set(false, forKey: Key.on)
        await center.remove(await ours())
    }

    // Call whenever the app learns how today is going (home loading).
    public func update(doneToday: Bool, streak: Int) async {
        last = (doneToday, streak)
        await reschedule()
    }

    private func ours() async -> [String] {
        await center.pending().filter { $0.hasPrefix(ReminderPlan.prefix) }
    }

    private func reschedule() async {
        guard on else { return }
        // Turned off in Settings since: nothing would show.
        let allowed = await center.authorized()
        blocked = allowed == false
        guard allowed == true else { return }
        await center.remove(await ours())
        for r in ReminderPlan.next(now: now(), calendar: calendar, doneToday: last.doneToday, streak: last.streak) {
            await center.add(r)
        }
    }
}
