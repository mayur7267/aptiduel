import Domain
import Foundation

// Opens the feedback sheet from anywhere: Profile, a question in answer
// review, or a shake of the phone.
public struct FeedbackRequest: Identifiable, Sendable, Hashable {
    public let id = UUID()
    public let kind: FeedbackKind
    public let context: [String: String]

    public init(kind: FeedbackKind, context: [String: String] = [:]) {
        self.kind = kind
        self.context = context
    }
}

@MainActor
@Observable
public final class FeedbackState {
    public var request: FeedbackRequest?

    public init() {}

    public func open(_ kind: FeedbackKind, context: [String: String] = [:]) {
        request = FeedbackRequest(kind: kind, context: context)
    }
}
