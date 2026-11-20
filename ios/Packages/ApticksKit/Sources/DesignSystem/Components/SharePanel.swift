import Domain
import SwiftUI
import UIKit

// WhatsApp first, because that is where college groups live. `quiet` is
// the compact card version: link field on top, a dark WhatsApp button
// below, for cards that sit next to a lime one.
// `link` is the address when it isn't a challenge's (a shared Daily's
// /d/<code>); `copyText` copies and shares the whole message, grid and
// all, not just the link; `onShare` hears which button was used; and
// `beside` sits next to the WhatsApp button (the Story picture button).
public struct SharePanel<Beside: View>: View {
    let code: String
    let text: String
    var quiet: Bool
    var link: String?
    var label: String
    var copyText: Bool
    var onShare: ((ShareChannel) -> Void)?
    let beside: Beside

    @State private var copied = false
    @Environment(\.openURL) private var openURL

    public init(code: String, text: String, quiet: Bool = false, link: String? = nil,
                label: String = "Challenge on WhatsApp", copyText: Bool = false,
                onShare: ((ShareChannel) -> Void)? = nil, @ViewBuilder beside: () -> Beside) {
        self.code = code
        self.text = text
        self.quiet = quiet
        self.link = link
        self.label = label
        self.copyText = copyText
        self.onShare = onShare
        self.beside = beside()
    }

    private var url: String { link ?? Links.challenge(code) }

    private func copy() {
        onShare?(.copy)
        UIPasteboard.general.string = copyText ? text : url
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }

    private func whatsapp() {
        onShare?(.whatsapp)
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
                    more(border: Theme.field)
                }
                Button(action: whatsapp) {
                    Label("Share on WhatsApp", systemImage: "message.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledStyle(fill: Theme.raised, foreground: Theme.text, border: Theme.field, radius: 14))
            }
        } else {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button(action: whatsapp) {
                        Label(label, systemImage: "message.fill").font(.ui(16, .bold)).lineLimit(1).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FilledStyle(fill: Theme.lime, foreground: Theme.ink, height: 56))
                    beside
                }
                HStack(spacing: 8) {
                    linkField
                    Button(action: copy) {
                        Label(copied ? "Copied" : "Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(FilledStyle(fill: Theme.raised, foreground: Theme.text, border: Theme.line, radius: 12, height: 44))
                    more(border: Theme.line)
                }
            }
        }
    }

    // The system share sheet. A whole message already ends with its link,
    // so it isn't sent twice.
    @ViewBuilder
    private func more(border: Color) -> some View {
        let icon = Image(systemName: "square.and.arrow.up")
            .foregroundStyle(Theme.text)
            .frame(width: 44, height: 44)
            .card(12, fill: Theme.raised, border: border)
        Group {
            if copyText {
                ShareLink(item: text) { icon }
            } else {
                ShareLink(item: URL(string: url)!, message: Text(text)) { icon }
            }
        }
        .simultaneousGesture(TapGesture().onEnded { onShare?(.share) })
        .accessibilityLabel("More ways to share")
    }
}

extension SharePanel where Beside == EmptyView {
    public init(code: String, text: String, quiet: Bool = false, link: String? = nil,
                label: String = "Challenge on WhatsApp", copyText: Bool = false,
                onShare: ((ShareChannel) -> Void)? = nil) {
        self.init(code: code, text: text, quiet: quiet, link: link, label: label, copyText: copyText, onShare: onShare) { EmptyView() }
    }
}
