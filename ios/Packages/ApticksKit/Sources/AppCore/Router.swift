import Domain
import SwiftUI

public enum AppTab: Hashable, Sendable {
    case home, daily, ranks, profile
}

// Full-screen flows over the tabs, like the website's /play and /duel pages.
public enum Screen: Hashable, Sendable {
    case matchmaking(Company?)
    case duel(String)
    case result(String)
    case challenge(String) // a link: a live room's lobby, or a recorded challenge
    case newRoom // open a live room (signing in first if you're a guest)
    case live(String) // a live friend duel in play
    case player(String) // someone's public profile
}

// One presented flow. Its screen changes in place (matchmaking → duel →
// result) without dismissing and re-presenting the cover.
@MainActor
@Observable
public final class FlowSession: Identifiable {
    public let id = UUID()
    public var screen: Screen
    init(_ screen: Screen) { self.screen = screen }
}

// Navigation for the whole app: which tab is showing and which flow, if
// any, is presented over it. View models navigate through it, so they can
// be tested without views.
@MainActor
@Observable
public final class AppRouter {
    public var tab: AppTab = .home
    public var flow: FlowSession?
    // Bumped when tab data should reload: after a flow closes, or the
    // account changing.
    public private(set) var refresh = 0

    public init() {}

    public func open(_ screen: Screen) {
        if let flow {
            withAnimation(.easeInOut(duration: 0.25)) { flow.screen = screen }
        } else {
            flow = FlowSession(screen)
        }
    }

    public func close(to tab: AppTab? = nil) {
        flow = nil
        if let tab { self.tab = tab }
        refresh += 1
    }

    public func reload() { refresh += 1 }

    public func accountChanged() {
        tab = .home
        refresh += 1
    }

    // A link opened the app: a challenge, a duel or its result, or a match.
    // Ignored during a duel, whose clock keeps running on the server.
    public func handle(_ url: URL) {
        if case .duel = flow?.screen { return }
        if case .live = flow?.screen { return }
        switch Links.route(from: url) {
        case let .challenge(code): open(.challenge(code))
        case let .duel(id): open(.duel(id))
        case let .result(id): open(.result(id))
        case let .play(company): open(.matchmaking(company))
        case nil: break
        }
    }
}
