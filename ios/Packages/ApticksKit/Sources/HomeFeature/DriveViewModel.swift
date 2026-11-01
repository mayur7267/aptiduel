import AppCore
import Domain
import Foundation
import Networking

// The placement test you're preparing for (port of web/src/app/(app)/
// drive-card.tsx): a countdown, your practice on that company's topics,
// and afterwards, two taps on how it went. Those answers, with your
// rating, will tell everyone what a rating means for clearing a test.
@MainActor
@Observable
public final class DriveViewModel {
    public static let other = "Another company"

    public private(set) var drive: Drive?
    public private(set) var editing = false
    public var company = COMPANIES[0].name
    public var otherCompany = ""
    public var date: Date
    // The first answer ("yes" or "no"), before the difficulty question.
    public private(set) var cleared: String?
    // On the day itself: telling us early.
    public private(set) var reporting = false
    public private(set) var busy = false
    public private(set) var error: String?

    private let api: any APIClient
    private let router: AppRouter
    private let now: () -> Date

    public init(api: any APIClient, router: AppRouter, now: @escaping () -> Date = Date.init) {
        self.api = api
        self.router = router
        self.now = now
        date = now().addingTimeInterval(14 * 86_400)
    }

    public var stage: Drive.Stage { drive?.stage ?? .unset }
    public var showsForm: Bool { stage == .unset || editing }
    public var asksHowItWent: Bool { stage == .howDidItGo || reporting }
    public var dateRange: ClosedRange<Date> { now().addingTimeInterval(-30 * 86_400)...now().addingTimeInterval(365 * 86_400) }

    private var chosenCompany: String {
        company == Self.other ? otherCompany.trimmingCharacters(in: .whitespaces) : company
    }

    public var canSave: Bool { !busy && chosenCompany.count >= 2 }

    public func load() async {
        if let d = try? await api.myDrive() { drive = d }
    }

    public func startEditing() {
        if let current = drive?.company {
            if COMPANIES.contains(where: { $0.name == current }) {
                company = current
            } else {
                company = Self.other
                otherCompany = current
            }
        }
        // A past test's date is no use for the next one.
        date = now().addingTimeInterval(14 * 86_400)
        if case let .upcoming(days) = stage { date = now().addingTimeInterval(Double(days) * 86_400) }
        editing = true
        error = nil
    }

    public func cancelEditing() { editing = false }

    public func save() async {
        await run { try await api.setDrive(company: chosenCompany, on: Drive.dayString(date)) }
    }

    public func clear() async {
        await run { try await api.setDrive(company: nil, on: nil) }
    }

    public func startReporting() { reporting = true }

    public func answer(_ cleared: String) async {
        if cleared == "skipped" {
            await run { try await api.submitDriveResult(cleared: "skipped", difficulty: nil) }
        } else {
            self.cleared = cleared
        }
    }

    public func back() { cleared = nil }

    public func finish(difficulty: String) async {
        guard let cleared else { return }
        await run { try await api.submitDriveResult(cleared: cleared, difficulty: difficulty) }
    }

    // A company duel for the test's company, or a quick match for others.
    public func practise() { router.open(.matchmaking(Domain.company(named: drive?.company))) }

    private func run(_ work: () async throws -> Drive) async {
        busy = true
        error = nil
        do {
            drive = try await work()
            editing = false
            reporting = false
            cleared = nil
        } catch {
            self.error = error.localizedDescription
        }
        busy = false
    }
}
