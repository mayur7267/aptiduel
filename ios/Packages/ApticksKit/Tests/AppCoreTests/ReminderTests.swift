import Foundation
import Testing
@testable import AppCore

// The notification centre, in memory.
actor FakeReminderCenter: ReminderCenter {
    var status: Bool?
    let grants: Bool
    private(set) var scheduled: [String: Reminder] = [:]

    init(status: Bool? = nil, grants: Bool = true) {
        self.status = status
        self.grants = grants
    }

    func authorized() async -> Bool? { status }
    func requestAuthorization() async -> Bool {
        status = grants
        return grants
    }
    func pending() async -> [String] { Array(scheduled.keys) }
    func remove(_ ids: [String]) async { ids.forEach { scheduled[$0] = nil } }
    func add(_ reminder: Reminder) async { scheduled[reminder.id] = reminder }
    func ids() -> [String] { scheduled.keys.sorted() }
    func block() { status = false }
}

@MainActor
struct ReminderTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return c
    }()

    // Thursday 19 November 2026 in India.
    func at(_ time: String) -> Date { ISO8601DateFormatter().date(from: "2026-11-19T\(time):00+05:30")! }

    @Test func aWeekOfEveningsStartingToday() {
        let plan = ReminderPlan.next(now: at("10:00"), calendar: calendar, doneToday: false, streak: 3)
        #expect(plan.count == 7)
        #expect(plan.first?.id == "apticks-daily-2026-11-19")
        #expect(plan.last?.id == "apticks-daily-2026-11-25")
        #expect(plan.allSatisfy { $0.fire.hour == 20 && $0.fire.minute == 0 })
        // Only the next reminder can count on the streak.
        #expect(plan[0].body.contains("3-day streak"))
        #expect(!plan[1].body.contains("streak"))
    }

    @Test func noneOnADayAlreadyPlayedOrPast8pm() {
        let done = ReminderPlan.next(now: at("10:00"), calendar: calendar, doneToday: true, streak: 4)
        #expect(done.first?.id == "apticks-daily-2026-11-20")
        #expect(done.count == 6)
        #expect(done[0].body.contains("4-day streak"))
        let late = ReminderPlan.next(now: at("21:00"), calendar: calendar, doneToday: false, streak: 0)
        #expect(late.first?.id == "apticks-daily-2026-11-20")
        #expect(!late[0].body.contains("streak"))
    }

    private func state(_ center: FakeReminderCenter) -> ReminderState {
        let suite = "reminders-\(UUID().uuidString)"
        return ReminderState(defaults: UserDefaults(suiteName: suite)!, center: center, calendar: calendar, now: { at("10:00") })
    }

    @Test func turningOnAsksThenSchedules() async {
        let center = FakeReminderCenter()
        let reminders = state(center)
        #expect(reminders.shouldOffer)
        #expect(await reminders.turnOn(doneToday: true, streak: 2))
        #expect(reminders.on && !reminders.shouldOffer)
        #expect(await center.ids().first == "apticks-daily-2026-11-20")

        // Home learns today isn't done after all (say, a new day): today returns.
        await reminders.update(doneToday: false, streak: 2)
        #expect(await center.ids().first == "apticks-daily-2026-11-19")

        await reminders.turnOff()
        #expect(await center.ids().isEmpty)
        await reminders.update(doneToday: false, streak: 2)
        #expect(await center.ids().isEmpty)
    }

    @Test func sayingNoIsRemembered() async {
        let center = FakeReminderCenter(grants: false)
        let reminders = state(center)
        #expect(await reminders.turnOn() == false)
        #expect(!reminders.on && reminders.blocked && !reminders.shouldOffer)
        #expect(await center.ids().isEmpty)
    }

    @Test func turnedOffInSettingsStopsScheduling() async {
        let center = FakeReminderCenter(status: true)
        let reminders = state(center)
        await reminders.turnOn()
        await center.block()
        await reminders.update(doneToday: false, streak: 0)
        #expect(reminders.blocked)
    }
}
