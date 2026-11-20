import Domain
import Foundation
import Testing

struct ShareTextTests {
    @Test func gridAndDays() {
        #expect(answerGrid([true, false, true]) == "🟩🟥🟩")
        #expect(shortDay("2026-11-14") == "14 Nov")
        #expect(shortDay("2026-01-05") == "5 Jan")
        #expect(shortDay("nonsense") == "nonsense")
        // 7:00 pm in London on 14 November is already the 15th in India.
        #expect(istToday(ISO8601DateFormatter().date(from: "2026-11-14T19:00:00Z")!) == "2026-11-15")
        #expect(istToday(ISO8601DateFormatter().date(from: "2026-11-14T18:00:00Z")!) == "2026-11-14")
    }

    // The same message the website sends (web/src/lib/format.ts).
    @Test func dailyMessageMatchesTheWebsite() {
        let grid = [true, true, false, true, false]
        #expect(dailyShareText(day: "2026-11-15", correct: 3, totalMs: 42_000, grid: grid, streak: 4, code: "7H75N9") == """
        Apticks Daily · 15 Nov
        🟩🟩🟥🟩🟥  3/5 · 0:42
        🔥 4-day streak

        Same 5 placement questions for everyone today. Can you beat me? https://www.playapticks.in/d/7H75N9
        """)
        // A one-day streak isn't worth mentioning.
        #expect(!dailyShareText(day: "2026-11-15", correct: 3, totalMs: 42_000, grid: grid, streak: 1, code: "X").contains("🔥"))
        #expect(Links.story == "https://www.playapticks.in/?via=story")
    }
}
