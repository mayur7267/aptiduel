import AppCore
import Domain
import Foundation
import NetworkingFakes
import Testing
@testable import HomeFeature

@MainActor
struct DailyCalendarTests {
    // Sunday 1 November 2026, 7 pm in India.
    let clock = ISO8601DateFormatter().date(from: "2026-11-01T13:30:00Z")!

    @Test func aMonthStartsOnMonday() {
        let model = DailyCalendarViewModel(api: FakeBackend(latency: .zero), now: { clock })
        #expect(model.monthTitle == "November 2026")
        #expect(model.weekdays == ["M", "T", "W", "T", "F", "S", "S"])
        let weeks = model.weeks
        // 1 November 2026 is a Sunday: six blanks, then the 1st.
        #expect(weeks[0].prefix(6).allSatisfy { $0.number == nil })
        #expect(weeks[0][6].number == 1 && weeks[0][6].isToday)
        #expect(weeks[1][0].future)
        #expect(weeks.joined().compactMap(\.number).count == 30)
        #expect(weeks.count == 6 && weeks.allSatisfy { $0.count == 7 })
    }

    @Test func thisWeekFromHomeShowsBeforeTheServerAnswers() {
        let model = DailyCalendarViewModel(api: FakeBackend(latency: .zero), now: { clock })
        // Thursday and today (Sunday) done.
        model.seed(week: [false, false, false, true, false, false, true], todayIdx: 6)
        #expect(model.days == ["2026-10-29", "2026-11-01"])
        #expect(model.currentRun == 1)
        #expect(model.doneInMonth == 1)
    }

    @Test func loadsEveryDayAndPagesBackToTheFirst() async {
        let model = DailyCalendarViewModel(api: FakeBackend(latency: .zero, now: { clock }), now: { clock })
        await model.load()
        #expect(model.error == nil)
        // The fake misses Wednesdays and Saturdays, and today is still open.
        #expect(model.days.contains("2026-10-29"))
        #expect(!model.days.contains("2026-10-28"))
        #expect(!model.days.contains(model.today))
        #expect(model.bestRun == 3) // Sunday to Tuesday
        #expect(model.currentRun == 0) // Saturday was missed
        #expect(!model.canGoForward)
        model.previous()
        #expect(model.monthTitle == "October 2026")
        model.previous()
        #expect(model.monthTitle == "September 2026")
        // The first Daily was in September.
        #expect(!model.canGoBack)
        model.previous()
        #expect(model.monthTitle == "September 2026")
        model.next()
        #expect(model.monthTitle == "October 2026")
    }

    @Test func todaysDailyFillsTodayAndHomeStaysOnIt() async throws {
        let backend = FakeBackend(latency: .zero, now: { clock })
        let home = HomeViewModel(api: backend, router: AppRouter())
        await home.load()
        #expect(home.suggestedPage == .daily)
        #expect(!home.dailyJustDone)

        let daily = try await backend.dailyChallenge().duelId
        for i in 0..<5 {
            _ = try await backend.nextQuestion(daily)
            _ = try await backend.submitAnswer(daily, question: i, choice: 0)
        }
        await home.load()
        #expect(home.me?.dailyWeek[6] == true)
        // Back from it: the Daily page, to see the day fill in.
        #expect(home.dailyJustDone)
        #expect(home.suggestedPage == .daily)
        // Next time, on to the goals.
        await home.load()
        #expect(!home.dailyJustDone)
        #expect(home.suggestedPage == .goals)

        let calendar = DailyCalendarViewModel(api: backend, now: { clock })
        await calendar.load()
        #expect(calendar.days.contains(calendar.today))
        #expect(calendar.currentRun == 1)
    }
}
