import Domain
import Foundation
import Networking

// The sign-in step before a friend duel: friend duels are between saved
// accounts. Create one (this guest, saved under an email, keeping its
// rating) or sign in to one from another device, with a code by email.
@MainActor
@Observable
public final class SignInModel {
    public private(set) var signingIn = false
    public var email = ""
    public var code = "" {
        didSet {
            let digits = String(code.filter(\.isNumber).prefix(10))
            if digits != code { code = digits }
        }
    }
    public private(set) var sent = false
    public private(set) var busy = false
    public private(set) var error: String?

    private let account: any AccountClient
    private let onDone: () async -> Void

    public init(account: any AccountClient, onDone: @escaping () async -> Void) {
        self.account = account
        self.onDone = onDone
    }

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespaces) }
    public var canSend: Bool { !busy && trimmedEmail.contains("@") }
    public var canConfirm: Bool { !busy && code.count >= 6 }

    public func sendCode() async {
        await run {
            if signingIn { try await account.sendSignInCode(trimmedEmail) } else { try await account.sendSaveCode(trimmedEmail) }
            sent = true
        }
    }

    public func confirm() async {
        await run {
            if signingIn {
                try await account.confirmSignInCode(trimmedEmail, code: code)
            } else {
                try await account.confirmSaveCode(trimmedEmail, code: code)
            }
        }
        if error == nil { await onDone() }
    }

    public func useDifferentEmail() {
        sent = false
        code = ""
    }

    public func switchMode() {
        signingIn.toggle()
        sent = false
        code = ""
        error = nil
    }

    private func run(_ work: () async throws -> Void) async {
        busy = true
        error = nil
        do {
            try await work()
        } catch {
            self.error = error.localizedDescription
        }
        busy = false
    }
}
