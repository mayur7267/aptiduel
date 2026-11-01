import AppCore
import Domain
import Foundation
import Networking

// Name, college and batch (port of web/src/app/(app)/profile/profile-form.tsx).
@MainActor
@Observable
public final class ProfileViewModel {
    public static let years = Array(2024...2031)

    public private(set) var me: Me?
    public private(set) var colleges: [College] = []
    public private(set) var duels: [DuelSummary] = []
    public var name = "" {
        didSet { if name.count > 24 { name = String(name.prefix(24)) } }
    }
    public var collegeId: Int?
    public var gradYear: Int?
    public private(set) var saving = false
    public private(set) var saved = false
    public private(set) var error: String?

    private let api: any APIClient
    private let router: AppRouter
    private let sleep: (Duration) async -> Void

    public init(api: any APIClient, router: AppRouter,
                sleep: @escaping (Duration) async -> Void = Wait.real) {
        self.api = api
        self.router = router
        self.sleep = sleep
    }

    public var collegeName: String? { colleges.first { $0.id == collegeId }?.name }
    // Rating after each rated duel, oldest first, ending at today's rating.
    public var ratingHistory: [Int] {
        let rated = duels
            .filter { $0.ratingAfter != nil && !$0.isReplay }
            .sorted { ($0.created ?? .distantPast) < ($1.created ?? .distantPast) }
        var points = rated.first?.ratingBefore.map { [$0] } ?? []
        points += rated.compactMap(\.ratingAfter)
        if let now = me?.rating, points.last != now { points.append(now) }
        return points
    }

    // Rating gained or lost over the last 7 days.
    public var weekChange: Int {
        let weekAgo = Date().addingTimeInterval(-7 * 86_400)
        return duels
            .filter { ($0.created ?? .distantPast) > weekAgo && !$0.isReplay }
            .compactMap { d in d.ratingAfter.flatMap { a in d.ratingBefore.map { a - $0 } } }
            .reduce(0, +)
    }

    public var winRate: Int? {
        guard let me, me.gamesPlayed > 0 else { return nil }
        return Int((Double(me.wins) / Double(me.gamesPlayed) * 100).rounded())
    }

    public var canSave: Bool { !saving && name.trimmingCharacters(in: .whitespaces).count >= 2 }

    public func load() async {
        do {
            async let m = api.me()
            async let list = api.colleges()
            async let recent = try? api.myDuels(limit: 30)
            let (me, colleges, duels) = try await (m, list, recent)
            self.me = me
            self.colleges = colleges
            self.duels = duels ?? []
            name = me.hasGuestName ? "" : me.name
            collegeId = me.collegeId
            gradYear = me.gradYear
            saved = false
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func save() async {
        saving = true
        error = nil
        do {
            me = try await api.updateProfile(name: name.trimmingCharacters(in: .whitespaces), collegeId: collegeId, gradYear: gradYear)
            saved = true
            // Home and the leaderboard pick up the new name and college.
            await sleep(.seconds(0.9))
            router.reload()
        } catch {
            self.error = error.localizedDescription
        }
        saving = false
    }
}
