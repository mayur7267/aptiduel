import AppCore
import Domain
import Foundation
import NetworkingFakes
import Testing
@testable import FeedbackFeature

@MainActor
struct FeedbackViewModelTests {
    let backend = FakeBackend(latency: .zero)
    private let device = ["app": "1.0 (1)", "os": "iOS 27.0", "device": "iPhone18,1"]

    private func model(_ kind: FeedbackKind, context: [String: String] = [:]) -> FeedbackViewModel {
        FeedbackViewModel(request: FeedbackRequest(kind: kind, context: context), api: backend, account: backend, device: device)
    }

    @Test func needsAFewWords() {
        let m = model(.bug)
        #expect(!m.canSend)
        m.message = "  hi "
        #expect(!m.canSend)
        m.message = "The timer froze"
        #expect(m.canSend)
    }

    @Test func sendsWithTheScreenAndDevice() async throws {
        let m = model(.bug, context: ["screen": "duel"])
        m.message = "The timer froze on question 3"
        m.email = "  asha@college.edu "
        await m.send()
        #expect(m.sent)
        let sent = try #require(backend.feedback.last)
        #expect(sent.kind == .bug)
        #expect(sent.email == "asha@college.edu")
        #expect(sent.context["screen"] == "duel")
        #expect(sent.context["device"] == "iPhone18,1")
        #expect(sent.context["app"] == "1.0 (1)")
    }

    @Test func canSwitchBetweenProblemAndIdea() async {
        let m = model(.bug)
        m.kind = .idea
        m.message = "Add a dark-mode timer"
        await m.send()
        #expect(backend.feedback.last?.kind == .idea)
    }

    @Test func aQuestionReportKeepsTheQuestion() async {
        let m = model(.question, context: ["duel": "d1", "question": "3", "body": "Find the odd one out"])
        m.message = "Two answers are right"
        await m.send()
        #expect(backend.feedback.last?.context["question"] == "3")
        #expect(backend.feedback.last?.kind == .question)
    }

    @Test func messagesAreCappedAt2000() {
        let m = model(.idea)
        m.message = String(repeating: "a", count: 2500)
        #expect(m.message.count == 2000)
    }

    @Test func showsTheServersReason() async {
        for i in 0..<5 {
            let m = model(.idea)
            m.message = "Idea number \(i)"
            await m.send()
        }
        let sixth = model(.idea)
        sixth.message = "One more idea"
        await sixth.send()
        #expect(!sixth.sent)
        #expect(sixth.error?.contains("a lot at once") == true)
    }

    @Test func fillsInTheSavedEmail() async throws {
        try await backend.sendSaveCode("asha@college.edu")
        try await backend.confirmSaveCode("asha@college.edu", code: "123456")
        let m = model(.bug)
        await m.prefillEmail()
        #expect(m.email == "asha@college.edu")
    }
}
