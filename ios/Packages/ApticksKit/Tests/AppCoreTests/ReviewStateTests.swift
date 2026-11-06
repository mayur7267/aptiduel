import Foundation
import Testing
@testable import AppCore

@MainActor
struct ReviewStateTests {
    // A fresh store for every test.
    private func state() -> ReviewState {
        ReviewState(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    private let day: TimeInterval = 86_400
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func asksOnTheThirdWin() {
        let s = state()
        #expect(!s.recordWin(in: "a", now: start))
        #expect(!s.recordWin(in: "b", now: start))
        #expect(s.recordWin(in: "c", now: start))
    }

    @Test func theSameDuelCountsOnce() {
        let s = state()
        #expect(!s.recordWin(in: "a", now: start))
        #expect(!s.recordWin(in: "a", now: start))
        #expect(!s.recordWin(in: "a", now: start))
        #expect(!s.recordWin(in: "b", now: start))
        // Only two different wins so far, however often the first was shown.
        #expect(s.recordWin(in: "c", now: start))
    }

    @Test func waitsNinetyDaysBeforeAskingAgain() {
        let s = state()
        for id in ["a", "b"] { _ = s.recordWin(in: id, now: start) }
        #expect(s.recordWin(in: "c", now: start))
        #expect(!s.recordWin(in: "d", now: start.addingTimeInterval(30 * day)))
        #expect(!s.recordWin(in: "e", now: start.addingTimeInterval(89 * day)))
        #expect(s.recordWin(in: "f", now: start.addingTimeInterval(91 * day)))
    }

    @Test func neverMoreThanThreeAsksInAYear() {
        let s = state()
        var asks: [Int] = []
        // A win every 40 days for over three years.
        for i in 0..<30 {
            let d = i * 40
            if s.recordWin(in: "duel-\(i)", now: start.addingTimeInterval(Double(d) * day)) { asks.append(d) }
        }
        for a in asks { #expect(asks.filter { $0 > a - 365 && $0 <= a }.count <= 3) }
        #expect(zip(asks, asks.dropFirst()).allSatisfy { $1 - $0 >= 90 })
        #expect(asks.count > 3) // later years still get asked
    }

    @Test func rememberedAcrossLaunches() {
        let suite = UUID().uuidString
        let first = ReviewState(defaults: UserDefaults(suiteName: suite)!)
        for id in ["a", "b"] { _ = first.recordWin(in: id, now: start) }
        let second = ReviewState(defaults: UserDefaults(suiteName: suite)!)
        #expect(second.recordWin(in: "c", now: start))
    }

    @Test func reviewLinkNeedsAnAppStoreId() {
        // Until the app has an App Store ID there is nothing to link to.
        #expect(AppStore.id == nil)
        #expect(AppStore.reviewURL == nil)
    }
}
