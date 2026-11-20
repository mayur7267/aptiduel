import DesignSystem
import Domain
import SwiftUI
import Tiko
import UIKit

// A 9:16 picture of your result for an Instagram Story or WhatsApp Status,
// drawn like the website's (web/src/components/story-card.tsx). It's made
// as soon as the result opens, so the share sheet comes up on the first
// tap. Nobody can tap a Story picture, so the address is printed big, and
// your link is copied for Instagram's Link sticker.
struct StoryButton: View {
    let data: StoryData
    // Hears the tap, before the share sheet opens.
    let onShare: () -> Void
    @State private var picture: Image?

    var body: some View {
        Group {
            if let picture {
                ShareLink(item: picture, preview: SharePreview("My Apticks score", image: picture)) { label }
                    .simultaneousGesture(TapGesture().onEnded {
                        UIPasteboard.general.string = Links.story
                        onShare()
                    })
            } else {
                // Drawing takes a moment; the button holds its place.
                label.opacity(0.6)
            }
        }
        .buttonStyle(FilledStyle(fill: Theme.surface, foreground: Theme.text, border: Theme.line, height: 56))
        .accessibilityLabel("Share a story picture of your score")
        .task(id: data) { picture = StoryCanvas.render(data) }
    }

    private var label: some View {
        Label {
            Text("Story picture").font(.ui(15, .semibold)).lineLimit(1).fixedSize()
        } icon: {
            Image(systemName: "photo").foregroundStyle(Theme.violet)
        }
    }
}

// The picture itself, laid out in points on a 360 x 640 canvas and
// rendered at 3x: 1080 x 1920. Instagram covers about the top and bottom
// 83 points with its own bars, so everything sits between.
struct StoryCanvas: View {
    let data: StoryData

    static let size = CGSize(width: 360, height: 640)

    @MainActor
    static func render(_ data: StoryData) -> Image? {
        let renderer = ImageRenderer(content: StoryCanvas(data: data).environment(\.colorScheme, .dark))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage.map { Image(uiImage: $0) }
    }

    // The lime card.
    private let card = CGRect(x: 26.7, y: 143.3, width: 306.6, height: 293.3)

    var body: some View {
        ZStack(alignment: .topLeading) {
            backdrop
            logo
            sticker
            ask
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(Theme.ink)
    }

    // The website's dark grid.
    private var backdrop: some View {
        Canvas { ctx, size in
            var path = Path()
            for x in stride(from: 30.0, to: size.width, by: 30) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 30.0, to: size.height, by: 30) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(path, with: .color(Theme.surface), lineWidth: 0.7)
        }
    }

    private var logo: some View {
        HStack(spacing: 7) {
            Mark(size: 35)
            (Text("Ap").foregroundColor(Theme.text) + Text("ticks").foregroundColor(Theme.lime))
                .font(.display(24))
        }
        .offset(x: 32, y: 87)
    }

    private var sticker: some View {
        let x = card.minX + 21.3
        return ZStack(alignment: .topLeading) {
            // Raised like a sticker.
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.limePop)
                .frame(width: card.width, height: card.height)
                .offset(x: card.minX + 5.3, y: card.minY + 5.3)
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.lime)
                .frame(width: card.width, height: card.height)
                .offset(x: card.minX, y: card.minY)

            Text(data.chip)
                .font(.mono(11.3))
                .foregroundStyle(Theme.lime)
                .padding(.horizontal, 7.3)
                .frame(height: 21.3)
                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.ink))
                .rotationEffect(.degrees(-3), anchor: .leading)
                .offset(x: x, y: card.minY + 14)

            Text(data.headline)
                .font(.display(30.7))
                .foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.5)
                .frame(width: card.width - 42.7, alignment: .leading)
                .offset(x: x, y: card.minY + 44)

            Text("\(data.correct)/5")
                .font(.display(90))
                .foregroundStyle(Theme.ink)
                .offset(x: card.minX + 18.7, y: card.minY + 70)

            Text("\(data.time) · \(data.score) pts")
                .font(.mono(16.7))
                .foregroundStyle(Theme.limeInk)
                .offset(x: x, y: card.minY + 174)

            HStack(spacing: 7.3) {
                ForEach(Array(data.grid.prefix(5).enumerated()), id: \.offset) { _, ok in
                    RoundedRectangle(cornerRadius: 8.7, style: .continuous)
                        .fill(ok ? Theme.ink : Theme.red)
                        .frame(width: 38.7, height: 38.7)
                        .overlay(Image(systemName: ok ? "checkmark" : "xmark")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(ok ? Theme.lime : Theme.ink))
                }
            }
            .offset(x: x, y: card.minY + 206)

            if let extra = data.extra {
                Text(extra)
                    .font(.ui(15.3, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: card.width - 42.7 - 76.7, alignment: .leading)
                    .offset(x: x, y: card.minY + 259)
            }

            // Tiko, cheering on the card's corner.
            TikoView(mood: .cheer, size: 96, still: true, interactive: false)
                .offset(x: Self.size.width - 122, y: card.maxY - 78)
        }
    }

    // The ask, and where to go.
    private var ask: some View {
        VStack(spacing: 0) {
            Text("Can you beat me?")
                .font(.display(30.7))
                .foregroundStyle(Theme.text)
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(height: 40)
            Text("playapticks.in")
                .font(.display(25.3))
                .foregroundStyle(Theme.lime)
                .padding(.horizontal, 16)
                .frame(height: 41.3)
                .overlay(Capsule().strokeBorder(Theme.lime, lineWidth: 2))
                .padding(.top, 0.7)
            // Ends about 557 pt down, clear of Instagram's reply bar.
            Text("5 placement-style questions · 3 minutes · free")
                .font(.ui(12.7, .semibold))
                .foregroundStyle(Theme.muted)
                .padding(.top, 8)
        }
        .frame(width: Self.size.width)
        .offset(y: 452)
    }
}
