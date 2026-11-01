import AppCore
import Domain
import Foundation
import Networking

// The feedback sheet: a problem, an idea, or a report about one question.
// The screen it came from, the app version and the device go along, to
// help reproduce problems.
@MainActor
@Observable
public final class FeedbackViewModel {
    public let request: FeedbackRequest
    public var kind: FeedbackKind
    public var message = "" {
        didSet { if message.count > 2000 { message = String(message.prefix(2000)) } }
    }
    public var email = ""
    public private(set) var sending = false
    public private(set) var sent = false
    public private(set) var error: String?

    private let api: any APIClient
    private let account: any AccountClient
    private let device: [String: String]

    public init(request: FeedbackRequest, api: any APIClient, account: any AccountClient, device: [String: String] = DeviceInfo.current) {
        self.request = request
        kind = request.kind
        self.api = api
        self.account = account
        self.device = device
    }

    var draft: FeedbackDraft {
        let mail = email.trimmingCharacters(in: .whitespaces)
        return FeedbackDraft(kind: kind, message: message, email: mail.isEmpty ? nil : mail,
                             context: request.context.merging(device) { mine, _ in mine })
    }

    public var canSend: Bool { !sending && draft.isSendable }

    // A saved account's email fills in the reply address.
    public func prefillEmail() async {
        guard email.isEmpty, let saved = try? await account.info().email else { return }
        if email.isEmpty { email = saved }
    }

    public func send() async {
        guard canSend else { return }
        sending = true
        error = nil
        do {
            try await api.sendFeedback(draft)
            sent = true
        } catch {
            self.error = error.localizedDescription
        }
        sending = false
    }
}
