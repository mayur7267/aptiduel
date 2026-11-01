import Domain
import Foundation

// What features need from the backend. Features depend on these
// interfaces only; the app chooses the implementation (NetworkingLive for
// the real thing, NetworkingFakes for previews and tests).

@MainActor
public protocol APIClient: AnyObject, Sendable {
    func me() async throws -> Me
    func myDuels(limit: Int) async throws -> [DuelSummary]
    func leaderboard(_ scope: BoardScope, limit: Int) async throws -> Board
    func colleges() async throws -> [College]
    func updateProfile(name: String, collegeId: Int?, gradYear: Int?) async throws -> Me

    func quickMatch() async throws -> MatchStart
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
    func createRoom() async throws -> RoomRef
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

    // Saved for the team and emailed to them.
    func sendFeedback(_ feedback: FeedbackDraft) async throws
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

// An error with a message that's fine to show the player.
public struct AppError: LocalizedError, Sendable, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
