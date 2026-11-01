import DesignSystem
import Domain
import SwiftUI

struct AccountPanel: View {
    @Bindable var model: AccountViewModel

    var body: some View {
        if let info = model.info {
            ProfileSection {
                if info.guest { saveAccount } else { signedIn(info.email) }
            }
            ProfileSection { deleteAccount }
        }
    }

    private func signedIn(_ email: String?) -> some View {
        Group {
            Text("Account").font(.display(18)).foregroundStyle(Theme.text)
            (Text("Saved to ") + Text(email ?? "").bold().foregroundColor(Theme.text)
                + Text(". Sign in with this email to play on any device, including the website."))
                .font(.ui(14)).foregroundStyle(Theme.muted)
            if let error = model.error { ErrorNote(error) }
            Button(model.busy ? "Signing out…" : "Sign out") { Task { await model.signOut() } }
                .buttonStyle(.secondary)
                .disabled(model.busy)
        }
    }

    // Two ways in: save this guest under an email, or sign in to an
    // account saved elsewhere (which leaves this guest behind).
    @ViewBuilder
    private var saveAccount: some View {
        Text(model.signingIn ? "Sign in" : "Save your account").font(.display(18)).foregroundStyle(Theme.text)
        Text(model.signingIn
            ? "Sign in to an account you saved on another device or the website. This phone's guest progress will be left behind."
            : "You're playing as a guest, so your rating lives only on this phone. Add your email to keep it and play on other devices.")
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
                Button(model.busy ? "Checking…" : "Confirm") { Task { await model.confirm() } }
                    .buttonStyle(.lime)
                    .disabled(!model.canConfirm)
            }
            Button("Use a different email") { model.useDifferentEmail() }
                .font(.ui(14)).foregroundStyle(Theme.muted).underline()
        }

        if let error = model.error { ErrorNote(error) }

        Button(model.signingIn ? "Save this guest instead" : "Already saved an account? Sign in") { model.switchMode() }
            .font(.ui(14, .semibold))
            .foregroundStyle(Theme.lime)
    }

    @ViewBuilder
    private var deleteAccount: some View {
        Text("Delete account").font(.display(18)).foregroundStyle(Theme.text)
        Text("Removes your name, college, email and rating, and signs you out for good. Duels you played stay in your opponents' history as \"Deleted player\". This can't be undone.")
            .font(.ui(14)).foregroundStyle(Theme.muted)
        if !model.askingToDelete {
            Button("Delete account") { withAnimation(.snappy) { model.askingToDelete = true } }
                .buttonStyle(FilledStyle(fill: Theme.raised, foreground: Theme.redSoft))
        } else {
            HStack(spacing: 12) {
                Button(model.busy ? "Deleting…" : "Delete forever") { Task { await model.deleteAccount() } }
                    .buttonStyle(FilledStyle(fill: Theme.red, foreground: Theme.ink))
                    .disabled(model.busy)
                Button("Keep my account") { withAnimation(.snappy) { model.askingToDelete = false } }
                    .buttonStyle(.secondary)
                    .disabled(model.busy)
            }
        }
    }
}
