import Foundation

// Where Apticks lives on the App Store. Once the app record exists in App
// Store Connect, put its Apple ID in `id` and Profile gains a "Rate Apticks"
// row that opens the write-a-review page.
public enum AppStore {
    public static let id: String? = nil

    public static var reviewURL: URL? {
        id.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }
}

// When to ask for an App Store rating. Apple shows its rating sheet at most
// three times a year and decides for itself whether to show it, so the ask
// waits for a good moment: the third win seen on this phone, then no more
// than once every 90 days. Losses and draws never count.
@MainActor
@Observable
public final class ReviewState {
    private enum Key {
        static let wins = "apticks-review-wins"
        static let lastDuel = "apticks-review-last-duel"
        static let asks = "apticks-review-asks"
    }

    static let winsNeeded = 3
    static let gap: TimeInterval = 90 * 86_400
    static let yearlyLimit = 3

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // Call when a win is on screen. True when this is the moment to ask,
    // and then the ask is on record. The same duel counts once, however
    // often its result is shown.
    public func recordWin(in duelId: String, now: Date = .now) -> Bool {
        guard defaults.string(forKey: Key.lastDuel) != duelId else { return false }
        defaults.set(duelId, forKey: Key.lastDuel)
        let wins = defaults.integer(forKey: Key.wins) + 1
        defaults.set(wins, forKey: Key.wins)

        let yearAgo = now.addingTimeInterval(-365 * 86_400).timeIntervalSince1970
        let asks = (defaults.array(forKey: Key.asks) as? [Double] ?? []).filter { $0 > yearAgo }
        let lastAsk = asks.max() ?? -.infinity
        guard wins >= Self.winsNeeded,
              asks.count < Self.yearlyLimit,
              now.timeIntervalSince1970 - lastAsk >= Self.gap
        else { return false }

        defaults.set(asks + [now.timeIntervalSince1970], forKey: Key.asks)
        return true
    }
}
