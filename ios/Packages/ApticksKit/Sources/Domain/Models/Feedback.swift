import Foundation

// A message for the team: a problem, an idea, or a report about one
// question. Saved by submit_feedback and emailed by feedback-mail.
public enum FeedbackKind: String, Sendable, Hashable, CaseIterable {
    case bug, idea, question
}

public struct FeedbackDraft: Sendable, Hashable {
    public var kind: FeedbackKind
    public var message: String
    public var email: String?
    public var context: [String: String] // screen, app version, device, the question…

    public init(kind: FeedbackKind, message: String, email: String? = nil, context: [String: String] = [:]) {
        self.kind = kind
        self.message = message
        self.email = email
        self.context = context
    }

    public var trimmedMessage: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }
    public var isSendable: Bool { (3...2000).contains(trimmedMessage.count) }
}
