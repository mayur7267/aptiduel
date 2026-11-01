import AppCore
import Domain
import Foundation
import Networking

// Saving a guest under an email, signing in, signing out and deleting
// (port of web/src/app/(app)/profile/account-panel.tsx).
@MainActor
@Observable
public final class AccountViewModel {
    public private(set) var info: AccountInfo?
    // Save this guest under an email, or sign in to an account saved elsewhere.
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
    public var askingToDelete = false

    private let account: any AccountClient
    private let router: AppRouter

    public init(account: any AccountClient, router: AppRouter) {
        self.account = account
        self.router = router
    }

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespaces) }
    public var canSend: Bool { !busy && trimmedEmail.contains("@") }
    public var canConfirm: Bool { !busy && code.count >= 6 }

    public func load() async {
        info = try? await account.info()
    }

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
            router.accountChanged()
        }
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

    public func signOut() async {
        await run {
            try await account.signOut()
            router.accountChanged()
        }
    }

    public func deleteAccount() async {
        await run {
            try await account.deleteAccount()
            router.accountChanged()
        }
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
