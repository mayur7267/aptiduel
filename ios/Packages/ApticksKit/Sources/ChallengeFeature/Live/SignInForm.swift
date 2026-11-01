import DesignSystem
import SwiftUI

// The email-code form for SignInModel.
struct SignInForm: View {
    @Bindable var model: SignInModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.signingIn ? "Sign in" : "Create your account").font(.display(20)).foregroundStyle(Theme.text)
            Text(model.signingIn
                ? "Sign in with the email you used before, on the app or the website."
                : "Friend duels are between real accounts, so you both know who you're playing. Add your email: your rating so far comes with you.")
                .font(.ui(14)).foregroundStyle(Theme.muted).lineSpacing(2)

            if !model.sent {
                HStack(spacing: 10) {
                    TextField("", text: $model.email, prompt: Text("you@college.edu").foregroundColor(Theme.faint))
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .card(12)
                        .accessibilityLabel("Email")
                    Button(model.busy ? "Sending…" : "Send code") { Task { await model.sendCode() } }
                        .buttonStyle(.lime)
                        .disabled(!model.canSend)
                }
            } else {
                (Text("We sent a code to ") + Text(model.email.trimmingCharacters(in: .whitespaces)).bold().foregroundColor(Theme.text) + Text("."))
                    .font(.ui(14)).foregroundStyle(Theme.soft)
                HStack(spacing: 10) {
                    TextField("", text: $model.code, prompt: Text("Code from the email").foregroundColor(Theme.faint))
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.mono(16, .medium))
                        .tracking(3)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .card(12)
                        .accessibilityLabel("Code")
                    Button(model.busy ? "Checking…" : "Confirm") { Task { await model.confirm() } }
                        .buttonStyle(.lime)
                        .disabled(!model.canConfirm)
                }
                Button("Use a different email") { model.useDifferentEmail() }
                    .font(.ui(14)).foregroundStyle(Theme.muted).underline()
            }

            if let error = model.error { ErrorNote(error) }

            Button(model.signingIn ? "New here? Create an account" : "Already have an account? Sign in") { model.switchMode() }
                .font(.ui(14, .semibold))
                .foregroundStyle(Theme.lime)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(20)
    }
}
