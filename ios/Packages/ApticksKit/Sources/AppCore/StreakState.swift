import Domain
import Foundation
import Observation

// The Streak Tower moment: when Home loads, the streak is compared with
// the one this device last showed, and a new block (or a fallen tower) is
// celebrated once. Remembered per player in UserDefaults.
@MainActor
@Observable
public final class StreakState {
    public var pending: StreakCelebration?
    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func check(_ me: Me, now: Date = .now) {
        let key = "streak-seen-\(me.id)"
        let seen = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(StreakSeen.self, from: $0) }
        let c = decideStreakCelebration(streak: me.streak, playedToday: me.playedToday, seen: seen)
        if c != nil || seen?.streak != me.streak {
            defaults.set(try? JSONEncoder().encode(StreakSeen(streak: me.streak, day: Streak.istDay(now))), forKey: key)
        }
        if let c { pending = c }
    }

    // Back on Home after the day's first duel: Tiko's note on the streak
    // chip, once a day on this device.
    @ObservationIgnored public var demoNote = false
    public func noteDue(_ me: Me, now: Date = .now) -> Bool {
        if demoNote { demoNote = false; return me.streak > 0 }
        guard me.playedToday, me.streak > 0 else { return false }
        let key = "streak-note-\(me.id)", today = Streak.istDay(now)
        if defaults.string(forKey: key) == today { return false }
        defaults.set(today, forKey: key)
        return true
    }

    public func show(_ c: StreakCelebration) { pending = c }
    public func dismiss() { pending = nil }
}
