import AppCore
import Domain
import Foundation
import Networking

// The Quick Match lobby (port of web/src/app/play/matchmaking.tsx): a
// short search, then the opponent reveal and a 3-2-1 countdown into the
// duel. With a company, the questions all come from that company's test
// pattern.
@MainActor
@Observable
public final class MatchmakingViewModel {
    public let company: Company?
    public let subject: Subject
    public private(set) var me: Me?
    public private(set) var duel: Duel?
    public private(set) var error: String?
    public private(set) var statusIndex = 0
    public private(set) var count = 3
    public private(set) var attempt = 0
    // An unfinished match comes back instead of a new one.
    public private(set) var resumed = false

    private let api: any APIClient
    private let router: AppRouter
    private let sleep: (Duration) async -> Void
    private let searchTime: ClosedRange<Double>

    public init(company: Company?, subject: Subject = .aptitude, api: any APIClient, router: AppRouter,
                sleep: @escaping (Duration) async -> Void = Wait.real,
                searchTime: ClosedRange<Double> = 1.8...3.3) {
        self.company = company
        self.subject = subject
        self.api = api
        self.router = router
        self.sleep = sleep
        self.searchTime = searchTime
    }

    public var status: String {
        let lines = company.map {
            ["Picking \($0.name) pattern questions", "Finding a bot near your rating", "Lining up a fair match"]
        } ?? {
            switch subject {
            case .coding: ["Looking for coders near your rating", "Checking recent runs", "Picking 5 programs on 5 topics"]
            case .english: ["Looking for players near your English rating", "Checking recent runs", "Picking 5 questions on 5 topics"]
            case .aptitude: ["Looking for players near your rating", "Checking recent runs", "Lining up a fair match"]
            }
        }()
        return lines[statusIndex % lines.count]
    }

    public var label: String {
        if let duel, resumed {
            return "Unfinished \(duel.company.map { "\($0) practice" } ?? duel.playedSubject.quickMatchName)"
        }
        return company.map { "\($0.name) practice" } ?? subject.quickMatchName
    }

    public func find() async {
        // A short, varied search so a match feels found rather than instant.
        let wait = Double.random(in: searchTime)
        let minimum = Task { await sleep(.seconds(wait)) }
        Task { me = try? await api.me() }
        do {
            let m = if let company { try await api.companyMatch(company.name) } else { try await api.quickMatch(subject) }
            let d = try await api.duel(m.duelId)
            await minimum.value
            resumed = (m.resumed ?? false) || d.me.answered > 0
            duel = d
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func runStatus() async {
        while duel == nil, error == nil, !Task.isCancelled {
            await sleep(.milliseconds(1100))
            statusIndex += 1
        }
    }

    // A resumed match's clock is already running, so it skips the countdown.
    public func runCountdown() async {
        guard let duel else { return }
        while !Task.isCancelled {
            await sleep(.milliseconds(resumed ? 1400 : 900))
            if Task.isCancelled { return }
            if resumed || count <= 1 {
                router.open(.duel(duel.id))
                return
            }
            count -= 1
        }
    }

    public func retry() {
        error = nil
        attempt += 1
    }

    public func cancel() { router.close() }
}
