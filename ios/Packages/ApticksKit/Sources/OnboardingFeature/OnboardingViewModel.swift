import AppCore
import Domain
import Foundation
import Networking

// The first-launch intro: six pages, the fifth asking for a name and
// college so friends know who beat them.
@MainActor
@Observable
public final class OnboardingViewModel {
    public enum Page: Int, CaseIterable, Identifiable {
        case hello, duel, challenge, climb, name, ready
        public var id: Int { rawValue }
    }

    public private(set) var page: Page = .hello
    public var name = "" {
        didSet { if name.count > 24 { name = String(name.prefix(24)) } }
    }
    public var collegeId: Int?
    public private(set) var colleges: [College] = []
    public private(set) var saving = false
    public private(set) var error: String?
    private var savedName: String?
    private var savedCollege: Int?

    private let api: any APIClient
    private let router: AppRouter
    private let onboarding: OnboardingState

    public init(api: any APIClient, router: AppRouter, onboarding: OnboardingState) {
        self.api = api
        self.router = router
        self.onboarding = onboarding
    }

    public var nameIsValid: Bool { name.trimmingCharacters(in: .whitespaces).count >= 2 }
    public var collegeName: String? { colleges.first { $0.id == collegeId }?.name }
    public var isLast: Bool { page == .ready }

    // Loads colleges, and the name if this account already has one.
    public func prepare() async {
        async let me = try? api.me()
        async let list = try? api.colleges()
        let (m, c) = await (me, list)
        colleges = c ?? []
        if let m, !m.hasGuestName, name.isEmpty {
            name = m.name
            savedName = m.name
        }
        if let m, collegeId == nil {
            collegeId = m.collegeId
            savedCollege = m.collegeId
        }
    }

    public func go(to page: Page) {
        error = nil
        self.page = page
    }

    public func next() async {
        if page == .name {
            guard await saveProfile() else { return }
        }
        if let after = Page(rawValue: page.rawValue + 1) { go(to: after) }
    }

    public func back() {
        if let before = Page(rawValue: page.rawValue - 1) { go(to: before) }
    }

    // Saves the name and college if they changed. Names are optional here.
    @discardableResult
    func saveProfile() async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard nameIsValid, trimmed != savedName || collegeId != savedCollege else { return true }
        saving = true
        error = nil
        defer { saving = false }
        do {
            let me = try await api.updateProfile(name: trimmed, collegeId: collegeId, gradYear: nil)
            savedName = me.name
            savedCollege = me.collegeId
            router.reload()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    public enum Exit {
        case play, explore, signIn
    }

    public func finish(_ exit: Exit) async {
        if exit != .signIn { await saveProfile() }
        onboarding.finish()
        switch exit {
        case .play: router.open(.matchmaking(nil))
        case .explore: router.tab = .home
        case .signIn: router.tab = .profile
        }
    }
}
