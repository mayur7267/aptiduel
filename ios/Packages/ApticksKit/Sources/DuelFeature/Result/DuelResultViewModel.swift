import AppCore
import Domain
import Foundation
import Networking

// After a duel (port of web/src/app/duel/[id]/result/duel-result.tsx).
@MainActor
@Observable
public final class DuelResultViewModel {
    public let duelId: String
    public private(set) var duel: Duel?
    public private(set) var error: String?
    public private(set) var ownCode: String?
    public private(set) var sharing = false
    public var showReview = false
    // Live duels: the rematch room, once either player has asked for one.
    public private(set) var rematchId: String?
    public private(set) var rematching = false
    // Your profile: the streak for the Daily share, and your college and
    // year so saving a name here doesn't clear them.
    public private(set) var profile: Me?
    public private(set) var savingName = false
    public private(set) var nameError: String?
    // Set once a Story picture went to the share sheet: its link was copied.
    public private(set) var storyShared = false

    private let api: any APIClient
    private let router: AppRouter
    private let sleep: (Duration) async -> Void

    public init(duelId: String, api: any APIClient, router: AppRouter,
                sleep: @escaping (Duration) async -> Void = Wait.real) {
        self.duelId = duelId
        self.api = api
        self.router = router
        self.sleep = sleep
    }

    // The link to share: your own challenge's, or one made from this run.
    public var shareCode: String? { duel?.isCreator == true ? duel?.code : ownCode }
    // After company practice, "play again" means the same company.
    public var rematch: Company? { company(named: duel?.company) }

    public func load() async {
        do {
            let d = try await api.duel(duelId)
            if d.me.finished { duel = d } else { router.open(.duel(duelId)) }
        } catch {
            self.error = error.localizedDescription
        }
        if duel != nil, profile == nil { profile = try? await api.me() }
    }

    // Ask for a name only while the profile still has the made-up one
    // ("Player 1586"), and only once it has loaded.
    public var askForName: Bool { profile?.hasGuestName == true }

    public func saveName(_ name: String) async {
        guard let profile, !savingName else { return }
        savingName = true
        nameError = nil
        do {
            self.profile = try await api.updateProfile(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines), collegeId: profile.collegeId, gradYear: profile.gradYear)
            // So the share messages carry the new name.
            if let d = try? await api.duel(duelId) { duel = d }
        } catch {
            nameError = error.localizedDescription
        }
        savingName = false
    }

    public var story: StoryData? { duel.flatMap { StoryData(duel: $0) } }

    // Today's Daily for WhatsApp: the grid, never the questions.
    public var dailyText: String? {
        guard let duel, duel.mode == .daily, let grid = StoryData.grid(duel) else { return nil }
        return dailyShareText(day: istToday(), correct: duel.me.correct, totalMs: duel.me.totalMs,
                              grid: grid, streak: profile?.streak ?? 0, code: duel.code)
    }

    // Counted in the background; a failed count never gets in the way.
    public func logShare(_ kind: ShareKind, _ channel: ShareChannel) {
        let api = api, id = duelId
        Task { try? await api.logShare(kind, channel, duelId: id) }
    }

    public func sharedStory() {
        storyShared = true
        logShare(.story, .share)
    }

    public func retry() async {
        error = nil
        await load()
    }

    // Keep checking while an opponent can still arrive or finish: every
    // couple of seconds in a live race, every 8 otherwise.
    public func poll() async {
        while duel?.awaitingOpponent == true, !Task.isCancelled {
            await sleep(isLive ? .seconds(2) : .seconds(8))
            if Task.isCancelled { return }
            if let d = try? await api.duel(duelId) { duel = d }
        }
    }

    public func makeShareCode() async {
        sharing = true
        do {
            ownCode = try await api.shareCode(duelId).code
        } catch {
            self.error = error.localizedDescription
        }
        sharing = false
    }

    public var isLive: Bool { duel?.mode == .live }

    // Live duels: notice when the other player asks for a rematch.
    public func watchRematch() async {
        while isLive, !Task.isCancelled {
            if let s = try? await api.liveState(duelId) { rematchId = s.rematchId }
            await sleep(.milliseconds(2500))
        }
    }

    // Asking again just returns the room the other player made.
    public func rematchLive() async {
        rematching = true
        do {
            router.open(.challenge(try await api.liveRematch(duelId).code))
        } catch {
            self.error = error.localizedDescription
        }
        rematching = false
    }

    public func openPlayer(_ id: String) { router.open(.player(id)) }
    // Again in the same subject: Coding stays Coding.
    public func playAgain() {
        let subject = duel?.playedSubject ?? .aptitude
        router.open(subject == .aptitude ? .matchmaking(rematch) : .subjectMatch(subject))
    }
    public func close(to tab: AppTab? = nil) { router.close(to: tab) }
}
