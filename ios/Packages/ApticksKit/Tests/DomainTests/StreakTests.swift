import Foundation
import Testing
@testable import Domain

// When the Streak Tower moment shows (the website follows the same rules).
struct StreakTests {
    @Test func firstLookCelebratesTodaysBlock() {
        #expect(decideStreakCelebration(streak: 5, playedToday: true, seen: nil) == .up(from: 4, to: 5, fresh: false))
        #expect(decideStreakCelebration(streak: 1, playedToday: true, seen: nil) == .up(from: 0, to: 1, fresh: true))
        // Not played yet today: nothing to celebrate yet.
        #expect(decideStreakCelebration(streak: 5, playedToday: false, seen: nil) == nil)
    }

    @Test func aNewBlockIsCelebratedOnce() {
        let seen = StreakSeen(streak: 4, day: "2026-11-21")
        #expect(decideStreakCelebration(streak: 5, playedToday: true, seen: seen) == .up(from: 4, to: 5, fresh: false))
        #expect(decideStreakCelebration(streak: 5, playedToday: true, seen: StreakSeen(streak: 5, day: "2026-11-22")) == nil)
    }

    @Test func aFallenTowerAndANewOne() {
        #expect(decideStreakCelebration(streak: 0, playedToday: false, seen: StreakSeen(streak: 6, day: "x")) == .fell(from: 6))
        // A one-day streak lost isn't worth a moment.
        #expect(decideStreakCelebration(streak: 0, playedToday: false, seen: StreakSeen(streak: 1, day: "x")) == nil)
        // Missed a day, then played: a new tower.
        #expect(decideStreakCelebration(streak: 1, playedToday: true, seen: StreakSeen(streak: 6, day: "x")) == .up(from: 0, to: 1, fresh: true))
    }

    @Test func milestonesAndColours() {
        #expect(Streak.isMilestone(7) && !Streak.isMilestone(8))
        #expect(Streak.next(after: 7) == 14)
        #expect(Streak.next(after: 365) == nil)
        #expect(Streak.title(7) == "Week 1 complete!")
        #expect((1...5).map { Streak.colorIndex(day: $0) } == [0, 1, 2, 3, 0])
    }

    @Test func daysOfAStreak() {
        let now = ISO8601DateFormatter().date(from: "2026-11-22T06:00:00Z")!
        #expect(Streak.days(streak: 3, playedToday: true, now: now) == ["2026-11-20", "2026-11-21", "2026-11-22"])
        #expect(Streak.days(streak: 2, playedToday: false, now: now) == ["2026-11-20", "2026-11-21"])
        #expect(Streak.weekday(daysAgo: 0, now: now) == "SUN")
    }
}
