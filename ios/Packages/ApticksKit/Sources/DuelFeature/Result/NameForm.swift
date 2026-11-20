import DesignSystem
import SwiftUI

// A guest is "Player 4821" until they pick a name. Asked here, where
// they're about to share, instead of sending them off to Profile.
struct NameForm: View {
    let current: String
    let saving: Bool
    let error: String?
    let save: (String) -> Void
    @State private var name = ""
    @FocusState private var focused: Bool

    private var valid: Bool { name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("What should friends call you?").font(.ui(14, .semibold)).foregroundStyle(Theme.text)
                Text("They'll see “\(current)” otherwise.").font(.ui(14)).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 8) {
                TextField("", text: $name, prompt: Text("Your first name").foregroundStyle(Theme.faint))
                    .font(.ui(15))
                    .foregroundStyle(Theme.text)
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .focused($focused)
                    .onSubmit { if valid { save(name) } }
                    .onChange(of: name) { _, new in if new.count > 24 { name = String(new.prefix(24)) } }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .card(12, fill: Theme.ink, border: Theme.field)
                Button(saving ? "Saving…" : "Save") {
                    focused = false
                    save(name)
                }
                .buttonStyle(FilledStyle(fill: Theme.lime, foreground: Theme.ink, radius: 12, height: 44))
                .disabled(saving || !valid)
                .opacity(saving || !valid ? 0.6 : 1)
            }
            if let error { Text(error).font(.ui(13)).foregroundStyle(Theme.redSoft) }
        }
        .padding(16)
        .card(16)
    }
}
