import Foundation
import Tiko

// Tiko the companion's size in the corner. Screens leave room for it.
public let COMPANION_SIZE: CGFloat = 64

// How Tiko the companion looks and what it says on a tab.
public struct CompanionPage: Equatable, Sendable {
    public var mood: TikoMood?
    public var say: String?

    public init(mood: TikoMood? = nil, say: String? = nil) {
        self.mood = mood
        self.say = say
    }
}

// Tabs set their own entry; the tour hides the companion while its own
// Tiko is hopping around. The player can switch Tiko off from Profile.
@MainActor
@Observable
public final class CompanionState {
    private static let offKey = "apticks-tiko-off"

    public var pages: [AppTab: CompanionPage] = [:]
    public var touring = false
    public var off = UserDefaults.standard.bool(forKey: offKey) {
        didSet { UserDefaults.standard.set(off, forKey: Self.offKey) }
    }

    public init() {}
}
