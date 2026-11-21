import Domain
import Foundation

// What features need from the backend. Features depend on these
// interfaces only; the app chooses the implementation (NetworkingLive for
// the real thing, NetworkingFakes for previews and tests).

@MainActor
public protocol APIClient: AnyObject, Sendable {
    func me() async throws -> Me
    func myDuels(limit: Int) async throws -> [DuelSummary]
    // A board per subject (0025_subject_ranks.sql).
    func leaderboard(_ scope: BoardScope, limit: Int, subject: Subject) async throws -> Board
    // The colleges people play for (older servers: every college).
    func colleges() async throws -> [College]
    // About 34,000 colleges in 224 countries, best match first
    // (0027_world_colleges.sql); country is a hint, the player's own.
    func searchColleges(_ query: String, country: String?) async throws -> [College]
    // A college that isn't on the list; returns its id (or the id of the
    // same college if someone added it already).
    func addCollege(name: String, city: String?, country: String) async throws -> Int
    func updateProfile(name: String, collegeId: Int?, gradYear: Int?) async throws -> Me

    // A Quick Match in a subject (0022_subjects.sql). Aptitude uses the
    // original call, so it also works against a database without 0022.
    func quickMatch(_ subject: Subject) async throws -> MatchStart
    // Your rating and games in each subject.
    func mySubjects() async throws -> SubjectRatings
    func companyMatch(_ company: String) async throws -> MatchStart
    func dailyChallenge() async throws -> DuelRef
    func duel(_ id: String) async throws -> Duel
    func nextQuestion(_ duelId: String) async throws -> QuestionView
    func submitAnswer(_ duelId: String, question: Int, choice: Int?) async throws -> AnswerResult

    func createChallenge() async throws -> NewChallenge
    func shareCode(_ duelId: String) async throws -> ShareCode
    func challenge(_ code: String) async throws -> Challenge?
    func challengeStatus(_ code: String) async throws -> ChallengeStatus?
    func joinChallenge(_ code: String) async throws -> DuelRef

    // Live friend duels (supabase/migrations/0013_live_duels.sql). Opening
    // and joining a room need a saved account.
    func createRoom(_ subject: Subject) async throws -> RoomRef
    // The host changes the subject until the friend joins
    // (0023_room_subjects.sql).
    func setRoomSubject(_ duelId: String, _ subject: Subject) async throws
    func joinRoom(_ code: String) async throws -> JoinedRoom
    // Also tells the server you're here: a player gone for 45 s forfeits
    // the rest of the race. Questions go through nextQuestion/submitAnswer.
    func liveState(_ duelId: String) async throws -> LiveState
    // Stop waiting: the room becomes an ordinary challenge you play now.
    func livePlayNow(_ duelId: String) async throws -> DuelRef
    func liveCancel(_ duelId: String) async throws
    func liveRematch(_ duelId: String) async throws -> RoomRef

    // Anyone's public profile; nil if there's no such player.
    func profile(_ id: String) async throws -> PublicProfile?

    // The placement test you're preparing for (0015_drives.sql). A nil
    // company clears it. The result is how it went: "yes", "no" or
    // "skipped", and "easier", "same" or "harder".
    func myDrive() async throws -> Drive
    func setDrive(company: String?, on day: String?) async throws -> Drive
    func submitDriveResult(cleared: String, difficulty: String?) async throws -> Drive

    // The days you finished the Daily Challenge: IST dates (yyyy-MM-dd),
    // oldest first, over the last 400 days (0016_daily_calendar.sql).
    func dailyDays() async throws -> [String]

    // Saved for the team and emailed to them.
    func sendFeedback(_ feedback: FeedbackDraft) async throws

    // A tap on a share button, for the share counts (0021_share_cards.sql).
    // Only your own duels are recorded against a duel.
    func logShare(_ kind: ShareKind, _ channel: ShareChannel, duelId: String?) async throws
}

// A guest account lives only on this device. Adding an email keeps the
// same account (and rating), so it can be signed in to anywhere.
@MainActor
public protocol AccountClient: AnyObject, Sendable {
    func info() async throws -> AccountInfo
    // Guest → saved account. The code goes to the new address.
    func sendSaveCode(_ email: String) async throws
    func confirmSaveCode(_ email: String, code: String) async throws
    // Sign in to an account saved elsewhere. Only existing accounts.
    func sendSignInCode(_ email: String) async throws
    func confirmSignInCode(_ email: String, code: String) async throws
    func signOut() async throws
    // Erases the profile, duels and rating.
    func deleteAccount() async throws
}

extension APIClient {
    public func quickMatch() async throws -> MatchStart { try await quickMatch(.aptitude) }
    public func createRoom() async throws -> RoomRef { try await createRoom(.aptitude) }
    public func leaderboard(_ scope: BoardScope, limit: Int) async throws -> Board {
        try await leaderboard(scope, limit: limit, subject: .aptitude)
    }
}

// An error with a message that's fine to show the player.
extension Error {
    // A request given up part-way because its screen moved on (SwiftUI
    // cancelled a pull-to-refresh, a view went away). Nothing went wrong,
    // so there's nothing to tell the player.
    public var isCancellation: Bool {
        if self is CancellationError { return true }
        if let url = self as? URLError, url.code == .cancelled { return true }
        let ns = self as NSError
        return ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled
    }
}

// What a failed request tells the player: a plain message for the usual
// network problems, the server's own message otherwise. A cancellation
// passes through untouched, so screens can tell it apart and say nothing
// (wrapped in an AppError it read "Swift.CancellationError error 1." on
// the first pull-to-refresh after every launch).
public func friendlyError(_ error: Error) -> Error {
    if error is AppError || error.isCancellation { return error }
    if let url = error as? URLError {
        switch url.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return AppError("You're offline. Check your connection and try again.")
        case .timedOut, .cannotConnectToHost, .cannotFindHost:
            return AppError("Couldn't reach Apticks. Try again in a moment.")
        default:
            break
        }
    }
    return AppError(error.localizedDescription)
}

public struct AppError: LocalizedError, Sendable, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
