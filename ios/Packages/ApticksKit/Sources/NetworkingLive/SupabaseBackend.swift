import Domain
import Foundation
import Networking
import Supabase

// The real backend: the same Supabase database functions the website
// calls. The session is kept in the Keychain, so a player keeps their
// guest account (and rating) on this device.
@MainActor
public final class SupabaseBackend: APIClient, AccountClient {
    private let client: SupabaseClient
    private var signingIn: Task<Void, Error>?

    public init(url: URL, key: String) {
        client = SupabaseClient(supabaseURL: url, supabaseKey: key, options: .init(auth: .init(emitLocalSessionAsInitialSession: true)))
    }

    // MARK: Session

    // Every player starts as a guest: an anonymous account is created on
    // first use and kept on this device.
    private func ensureSession() async throws {
        if client.auth.currentSession != nil { return }
        if let signingIn { return try await signingIn.value }
        let task = Task { _ = try await client.auth.signInAnonymously() }
        signingIn = task
        defer { signingIn = nil }
        do {
            try await task.value
        } catch {
            throw friendly(error)
        }
    }

    private func call(_ fn: String, _ params: [String: AnyJSON] = [:], retried: Bool = false) async throws -> Data {
        try await ensureSession()
        do {
            return try await client.rpc(fn, params: params).execute().data
        } catch let error as PostgrestError {
            // The account was deleted on another device: drop its session
            // here too and carry on as a fresh guest.
            if error.message == "This account was deleted.", !retried {
                try? await client.auth.signOut(scope: .local)
                return try await call(fn, params, retried: true)
            }
            throw AppError(error.message)
        } catch {
            throw friendly(error)
        }
    }

    private func rpc<T: Decodable>(_ fn: String, _ params: [String: AnyJSON] = [:]) async throws -> T {
        try decode(fn, try await call(fn, params))
    }

    private func decode<T: Decodable>(_ what: String, _ data: Data) throws -> T {
        do {
            return try Wire.decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("Couldn't decode \(what):", error, String(decoding: data.prefix(600), as: UTF8.self))
            #endif
            throw AppError("Something went wrong loading this. Try again.")
        }
    }

    private func friendly(_ error: Error) -> Error {
        if error is AppError { return error }
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

    private static func id(_ v: Int?) -> AnyJSON { v.map { .integer($0) } ?? .null }

    // MARK: APIClient

    public func me() async throws -> Me { try await rpc("get_me") }
    public func myDuels(limit: Int) async throws -> [DuelSummary] { try await rpc("my_duels", ["p_limit": .integer(limit)]) }
    public func leaderboard(_ scope: BoardScope, limit: Int) async throws -> Board {
        try await rpc("leaderboard", ["p_scope": .string(scope.rawValue), "p_limit": .integer(limit)])
    }
    public func colleges() async throws -> [College] {
        try await ensureSession()
        do {
            return try decode("colleges", try await client.from("colleges").select("id, name").order("name").execute().data)
        } catch {
            throw friendly(error)
        }
    }
    public func updateProfile(name: String, collegeId: Int?, gradYear: Int?) async throws -> Me {
        try await rpc("update_profile", ["p_name": .string(name), "p_college_id": Self.id(collegeId), "p_grad_year": Self.id(gradYear)])
    }

    public func quickMatch() async throws -> MatchStart { try await rpc("quick_match") }
    public func companyMatch(_ company: String) async throws -> MatchStart { try await rpc("company_match", ["p_company": .string(company)]) }
    public func dailyChallenge() async throws -> DuelRef { try await rpc("daily_challenge") }
    public func duel(_ id: String) async throws -> Duel { try await rpc("get_duel", ["p_duel_id": .string(id)]) }
    public func nextQuestion(_ duelId: String) async throws -> QuestionView { try await rpc("next_question", ["p_duel_id": .string(duelId)]) }
    public func submitAnswer(_ duelId: String, question: Int, choice: Int?) async throws -> AnswerResult {
        try await rpc("submit_answer", ["p_duel_id": .string(duelId), "p_q_index": .integer(question), "p_choice": Self.id(choice)])
    }

    public func createChallenge() async throws -> NewChallenge { try await rpc("create_challenge") }
    public func shareCode(_ duelId: String) async throws -> ShareCode { try await rpc("challenge_from_duel", ["p_duel_id": .string(duelId)]) }
    public func challenge(_ code: String) async throws -> Challenge? { try await rpc("get_challenge", ["p_code": .string(code)]) }
    public func challengeStatus(_ code: String) async throws -> ChallengeStatus? { try await rpc("challenge_status", ["p_code": .string(code)]) }
    public func joinChallenge(_ code: String) async throws -> DuelRef { try await rpc("join_challenge", ["p_code": .string(code)]) }

    public func createRoom() async throws -> RoomRef { try await rpc("create_room") }
    public func joinRoom(_ code: String) async throws -> JoinedRoom { try await rpc("join_room", ["p_code": .string(code)]) }
    public func liveState(_ duelId: String) async throws -> LiveState { try await rpc("live_state", ["p_duel_id": .string(duelId)]) }
    public func livePlayNow(_ duelId: String) async throws -> DuelRef { try await rpc("live_play_now", ["p_duel_id": .string(duelId)]) }
    public func liveCancel(_ duelId: String) async throws { _ = try await call("live_cancel", ["p_duel_id": .string(duelId)]) }
    public func liveRematch(_ duelId: String) async throws -> RoomRef { try await rpc("live_rematch", ["p_duel_id": .string(duelId)]) }

    public func profile(_ id: String) async throws -> PublicProfile? { try await rpc("get_profile", ["p_id": .string(id)]) }

    public func myDrive() async throws -> Drive { try await rpc("my_drive") }
    public func setDrive(company: String?, on day: String?) async throws -> Drive {
        try await rpc("set_drive", ["p_company": company.map { .string($0) } ?? .null, "p_drive_on": day.map { .string($0) } ?? .null])
    }
    public func submitDriveResult(cleared: String, difficulty: String?) async throws -> Drive {
        try await rpc("submit_drive_result", ["p_cleared": .string(cleared), "p_difficulty": difficulty.map { .string($0) } ?? .null])
    }

    public func dailyDays() async throws -> [String] { try await rpc("daily_days") }

    public func sendFeedback(_ feedback: FeedbackDraft) async throws {
        _ = try await call("submit_feedback", [
            "p_kind": .string(feedback.kind.rawValue),
            "p_message": .string(feedback.trimmedMessage),
            "p_email": feedback.email.map { .string($0) } ?? .null,
            "p_platform": .string("ios"),
            "p_context": .object(feedback.context.mapValues { .string($0) }),
        ])
    }

    // MARK: AccountClient

    public func info() async throws -> AccountInfo {
        try await ensureSession()
        let user = client.auth.currentUser
        let email = user?.email ?? ""
        return AccountInfo(guest: user?.isAnonymous ?? true, email: email.isEmpty ? nil : email)
    }

    public func sendSaveCode(_ email: String) async throws {
        try await ensureSession()
        do {
            _ = try await client.auth.update(user: UserAttributes(email: email))
        } catch {
            if error.localizedDescription.range(of: "already", options: .caseInsensitive) != nil {
                throw AppError("That email already has an account. Sign in with it instead.")
            }
            throw friendly(error)
        }
    }

    public func confirmSaveCode(_ email: String, code: String) async throws {
        do {
            _ = try await client.auth.verifyOTP(email: email, token: code, type: .emailChange)
            // A fresh token, so the server sees a saved account (friend duels).
            _ = try await client.auth.refreshSession()
        } catch {
            throw friendly(error)
        }
    }

    public func sendSignInCode(_ email: String) async throws {
        do {
            try await client.auth.signInWithOTP(email: email, shouldCreateUser: false)
        } catch {
            if error.localizedDescription.range(of: "signups not allowed|not found", options: [.regularExpression, .caseInsensitive]) != nil {
                throw AppError("No saved account uses that email.")
            }
            throw friendly(error)
        }
    }

    public func confirmSignInCode(_ email: String, code: String) async throws {
        do {
            _ = try await client.auth.verifyOTP(email: email, token: code, type: .email)
        } catch {
            throw friendly(error)
        }
    }

    public func signOut() async throws {
        do {
            try await client.auth.signOut()
        } catch {
            // Signed out here even if the server call failed.
            try? await client.auth.signOut(scope: .local)
            throw friendly(error)
        }
    }

    // The session is cleared locally, since its user no longer exists.
    public func deleteAccount() async throws {
        _ = try await call("delete_me")
        try? await client.auth.signOut(scope: .local)
    }
}
