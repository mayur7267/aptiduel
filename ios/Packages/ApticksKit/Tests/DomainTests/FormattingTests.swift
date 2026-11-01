import Foundation
import Testing
@testable import Domain

struct FormattingTests {
    @Test func clockRoundsToSeconds() {
        #expect(clock(108_000) == "1:48")
        #expect(clock(59_600) == "1:00")
        #expect(clock(-5) == "0:00")
    }

    @Test func initialsUseFirstAndLastNames() {
        #expect(initials("Asha Verma") == "AV")
        #expect(initials("asha") == "AS")
        #expect(initials("  Asha  K  Verma ") == "AV")
        #expect(initials("") == "?")
    }

    @Test func signedUsesProperMinus() {
        #expect(signed(16) == "+16")
        #expect(signed(-12) == "−12")
        #expect(signed(0) == "±0")
    }

    @Test(arguments: [(899, "Fresher"), (900, "Trainee"), (1299, "Analyst"), (1300, "Consultant"), (1700, "Architect"), (2400, "Architect")])
    func tiers(rating: Int, name: String) {
        #expect(tierFor(rating).name == name)
    }

    @Test func tierProgressTowardsNext() {
        let t = tierFor(1200)
        #expect(t.next?.name == "Consultant")
        #expect(t.toNext == 100)
        #expect(t.progress == 0.5)
        #expect(tierFor(1800).next == nil)
        #expect(tierFor(1800).progress == 1)
    }

    @Test func promotionCrossesATier() {
        #expect(promoted(from: 1290, to: 1306))
        #expect(!promoted(from: 1306, to: 1320))
    }

    @Test func dailyResetIsMidnightIST() {
        // 18:00 UTC is 23:30 IST: 30 minutes left.
        let date = ISO8601DateFormatter().date(from: "2026-10-29T18:00:00Z")!
        #expect(untilIstMidnight(date) == "30m")
        let morning = ISO8601DateFormatter().date(from: "2026-10-29T00:00:00Z")! // 05:30 IST
        #expect(untilIstMidnight(morning) == "18h 30m")
    }

    @Test func batchAndGrouping() {
        #expect(batch(2026) == "Batch ’26")
        #expect(batch(nil) == nil)
        #expect(grouped(1500) == "1,500")
        #expect(grouped(125_000) == "1,25,000")
    }

    @Test func guestNames() {
        #expect(isGuestName("Player 4821"))
        #expect(!isGuestName("Player One"))
    }
}
