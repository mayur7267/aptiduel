import AppCore
import Domain
import Foundation
import Networking
import Tiko

public enum HomeAction: Sendable {
    case challenge, daily
}

@MainActor
@Observable
public final class HomeViewModel {
    public private(set) var me: Me?
    public private(set) var duels: [DuelSummary] = []
    public private(set) var board: Board?
    public private(set) var error: String?
    public private(set) var busy: HomeAction?

    // The placement test you're preparing for.
    public let drive: DriveViewModel

    private let api: any APIClient
    let router: AppRouter

    public init(api: any APIClient, router: AppRouter) {
        self.api = api
        self.router = router
        drive = DriveViewModel(api: api, router: router)
    }

    public func load() async {
        do {
            async let m = api.me()
            async let d = api.myDuels(limit: 8)
            async let b = api.leaderboard(.college, limit: 5)
            let (me, duels, board) = try await (m, d, b)
            self.me = me
            self.duels = duels
            self.board = board
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        await drive.load()
    }

    // A live room, and its lobby to share the link from. Guests sign in
    // there first, since friend duels are between saved accounts.
    public func startChallenge() {
        router.open(.newRoom)
    }

    public func startDaily() async {
        guard busy == nil else { return }
        busy = .daily
        error = nil
        do {
            router.open(.duel(try await api.dailyChallenge().duelId))
        } catch {
            self.error = error.localizedDescription
        }
        busy = nil
    }

    // Your newest challenge link, while it can still be accepted (7 days).
    func latestChallenge(now: Date) -> DuelSummary? {
        duels.first { d in
            guard d.code != nil, let created = d.created else { return false }
            return now.timeIntervalSince(created) < 7 * 86_400
        }
    }

    // What Tiko says on the home tab: the most useful nudge first.
    var nudge: CompanionPage {
        guard let me else { return CompanionPage() }
        if me.gamesPlayed == 0 { return CompanionPage(mood: .wave, say: "Start your first duel and I'll cheer you on!") }
        if me.streak > 0 && !me.playedToday {
            return CompanionPage(mood: .think, say: "Your \(me.streak)-day streak needs a duel today!")
        }
        if me.quests.daily == 0 { return CompanionPage(mood: .point, say: "Today's Daily Challenge is waiting for you.") }
        if me.quests.quickWins >= 2 && me.quests.accepted >= 1 {
            return CompanionPage(mood: .cheer, say: "Every goal done today. You're on fire!")
        }
        return CompanionPage(mood: .happy)
    }
}
