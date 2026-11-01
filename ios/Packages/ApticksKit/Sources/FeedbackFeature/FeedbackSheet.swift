import AppCore
import DesignSystem
import Domain
import SwiftUI
import Tiko

private struct Copy {
    let title: String
    let hint: String
    let placeholder: String
    let mood: TikoMood

    static func `for`(_ kind: FeedbackKind) -> Copy {
        switch kind {
        case .bug: Copy(title: "Report a problem", hint: "What went wrong, and what did you expect to happen?",
                        placeholder: "The timer froze on question 3 when I…", mood: .confused)
        case .idea: Copy(title: "Suggest a feature", hint: "What would make Apticks better for you?",
                         placeholder: "It would be great if I could…", mood: .think)
        case .question: Copy(title: "Report this question", hint: "Is the answer wrong, or is something unclear?",
                             placeholder: "Option B should be right because…", mood: .point)
        }
    }
}

public struct FeedbackSheet: View {
    @State private var model: FeedbackViewModel
    @FocusState private var writing: Bool
    @Environment(\.dismiss) private var dismiss

    public init(model: FeedbackViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()
            if model.sent { thanks.transition(.scale(scale: 0.9).combined(with: .opacity)) } else { form }
        }
        .animation(.snappy, value: model.sent)
        .task { await model.prefillEmail() }
        .sensoryFeedback(.success, trigger: model.sent) { _, now in now }
    }

    private var form: some View {
        let copy = Copy.for(model.kind)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    TikoView(mood: copy.mood, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(copy.title).font(.display(18)).foregroundStyle(Theme.text)
                        Text(copy.hint).font(.ui(14)).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                    CloseButton { dismiss() }
                }

                if model.request.kind != .question {
                    Picker("What is this about?", selection: $model.kind) {
                        Text("🐞 Problem").tag(FeedbackKind.bug)
                        Text("💡 Idea").tag(FeedbackKind.idea)
                    }
                    .pickerStyle(.segmented)
                } else if let body = model.request.context["body"] {
                    (Text("Q\(model.request.context["question"] ?? "") · ").bold().foregroundColor(Theme.muted) + Text(body))
                        .font(.ui(14))
                        .foregroundStyle(Theme.soft)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(12, fill: Theme.raised)
                }

                VStack(alignment: .trailing, spacing: 6) {
                    TextField("", text: $model.message, prompt: Text(copy.placeholder).foregroundColor(Theme.faint), axis: .vertical)
                        .lineLimit(5...10)
                        .font(.ui(16))
                        .foregroundStyle(Theme.text)
                        .focused($writing)
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
                        .card(14, fill: Theme.ink)
                    Text("\(model.message.count)/2000").font(.ui(12)).monospacedDigit().foregroundStyle(Theme.faint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    (Text("Your email ").bold() + Text("(optional, so we can reply)").foregroundColor(Theme.muted))
                        .font(.ui(14)).foregroundStyle(Theme.text)
                    TextField("", text: $model.email, prompt: Text("you@college.edu").foregroundColor(Theme.faint))
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.ui(15))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 46)
                        .card(12, fill: Theme.ink)
                }

                if let error = model.error {
                    Text(error).font(.ui(14)).foregroundStyle(Theme.redSoft)
                }

                Button { Task { await model.send() } } label: {
                    HStack(spacing: 8) {
                        if model.sending { ProgressView().tint(Theme.ink) }
                        Text(model.sending ? "Sending…" : "Send")
                    }
                    .font(.ui(16, .heavy))
                }
                .buttonStyle(PressableStyle(fill: Theme.lime, foreground: Theme.ink, pop: Theme.limePop, radius: 16, height: 54))
                .disabled(!model.canSend)
                .opacity(model.canSend || model.sending ? 1 : 0.55)

                Text("The screen you were on, the app version and your phone model are sent along, to help us fix things.")
                    .font(.ui(12)).foregroundStyle(Theme.faint).frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { writing = true }
    }

    private var thanks: some View {
        VStack(spacing: 12) {
            TikoView(mood: .cheer, size: 100, play: TikoPlay(move: .boing, key: 1))
            Text("Thank you!").font(.display(24)).foregroundStyle(Theme.text)
            Text(model.draft.email == nil ? "We read every message." : "We read every message, and we'll reply if we need more details.")
                .font(.ui(15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 300)
            Button("Done") { dismiss() }
                .buttonStyle(FilledStyle(fill: Theme.lime, foreground: Theme.ink, radius: 14, height: 48))
                .padding(.top, 8)
        }
        .padding(24)
    }
}

// Presents the sheet for a FeedbackState. Applied both at the root and
// inside full-screen flows, `active` picks whichever is on top.
private struct FeedbackPresenter: ViewModifier {
    let state: FeedbackState
    let active: Bool
    let make: (FeedbackRequest) -> FeedbackViewModel

    func body(content: Content) -> some View {
        content.sheet(item: Binding(get: { active ? state.request : nil }, set: { state.request = $0 })) { request in
            FeedbackSheet(model: make(request))
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
    }
}

extension View {
    public func feedbackSheet(_ state: FeedbackState, active: Bool, model: @escaping (FeedbackRequest) -> FeedbackViewModel) -> some View {
        modifier(FeedbackPresenter(state: state, active: active, make: model))
    }
}
