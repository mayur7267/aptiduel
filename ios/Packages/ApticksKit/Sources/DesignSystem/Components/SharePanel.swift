import Domain
import SwiftUI
import UIKit

// WhatsApp first, because that is where college groups live. `quiet` is
// the compact card version: link field on top, a dark WhatsApp button
// below, for cards that sit next to a lime one.
public struct SharePanel: View {
    let code: String
    let text: String
    var quiet: Bool

    @State private var copied = false
    @Environment(\.openURL) private var openURL

    public init(code: String, text: String, quiet: Bool = false) {
        self.code = code
        self.text = text
        self.quiet = quiet
    }

    private var url: String { Links.challenge(code) }

    private func copy() {
        UIPasteboard.general.string = url
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }

    private func whatsapp() {
        var c = URLComponents(string: "https://wa.me/")!
        c.queryItems = [URLQueryItem(name: "text", value: text)]
        if let link = c.url { openURL(link) }
    }

    private var linkField: some View {
        Text(url.replacingOccurrences(of: "https://", with: ""))
            .font(.ui(14))
            .foregroundStyle(Theme.soft)
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .card(12, fill: Theme.ink, border: Theme.field)
    }

    public var body: some View {
        if quiet {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your duel link").font(.ui(12, .semibold)).foregroundStyle(Theme.muted)
                HStack(spacing: 8) {
                    linkField
                    Button(action: copy) {
                        Group {
                            if copied { Text("Copied").font(.ui(12, .semibold)) } else { Image(systemName: "doc.on.doc") }
                        }
                        .foregroundStyle(Theme.text)
                        .frame(minWidth: 44, minHeight: 44)
                        .padding(.horizontal, copied ? 8 : 0)
                        .card(12, fill: Theme.raised, border: Theme.field)
                    }
                    .accessibilityLabel(copied ? "Link copied" : "Copy link")
                    ShareLink(item: URL(string: url)!, message: Text(text)) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Theme.text)
                            .frame(width: 44, height: 44)
                            .card(12, fill: Theme.raised, border: Theme.field)
                    }
                    .accessibilityLabel("More ways to share")
                }
                Button(action: whatsapp) {
                    Label("Share on WhatsApp", systemImage: "message.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledStyle(fill: Theme.raised, foreground: Theme.text, border: Theme.field, radius: 14))
            }
        } else {
            VStack(spacing: 10) {
                Button(action: whatsapp) {
                    Label("Challenge on WhatsApp", systemImage: "message.fill").font(.ui(16, .bold)).frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledStyle(fill: Theme.lime, foreground: Theme.ink, height: 56))
                HStack(spacing: 8) {
                    linkField
                    Button(action: copy) {
                        Label(copied ? "Copied" : "Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(FilledStyle(fill: Theme.raised, foreground: Theme.text, border: Theme.line, radius: 12, height: 44))
                    ShareLink(item: URL(string: url)!, message: Text(text)) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Theme.text)
                            .frame(width: 44, height: 44)
                            .card(12, fill: Theme.raised, border: Theme.line)
                    }
                    .accessibilityLabel("More ways to share")
                }
            }
        }
    }
}
