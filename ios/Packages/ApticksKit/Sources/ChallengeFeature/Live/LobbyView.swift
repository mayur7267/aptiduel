import AppCore
import DesignSystem
import Domain
import SwiftUI
import Tiko

struct LobbyView: View {
    let model: LobbyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Live duel · room \(model.code)", systemImage: "circle.fill")
                .labelStyle(PulseDot())
                .font(.ui(13, .bold))
                .foregroundStyle(Theme.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.orangeTint))

            Text(model.title)
                .font(.display(30)).foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            Text(model.line).font(.ui(17)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Versus(me: model.state?.me.name ?? model.hostName, friend: model.opponent?.present == true ? model.opponent?.name : nil)
                .padding(.top, 36)

            switch model.state?.status {
            case .async:
                Button("Play your turn") { model.playYourTurn() }.buttonStyle(.lime)
            case .closed:
                Button("Back to home") { model.leave() }.buttonStyle(.lime)
            default:
                waiting
            }
            if let error = model.error { ErrorNote(error) }
        }
        .animation(.snappy, value: model.state)
    }

    @ViewBuilder
    private var waiting: some View {
        if model.isHost, model.opponent == nil {
            SharePanel(code: model.code, text: model.shareText)
            (Text("Or tell them the room code: ") + Text(model.code).font(.mono(15, .bold)).tracking(3).foregroundColor(Theme.text))
                .font(.ui(14)).foregroundStyle(Theme.muted)
        }
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            let elapsed = max(0, Int(tl.date.timeIntervalSince(model.since)))
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    BouncingDots(color: Theme.orange)
                    Text("Waiting \(elapsed / 60):\(String(format: "%02d", elapsed % 60))")
                        .font(.mono(14)).foregroundStyle(Theme.faint)
                }
                // Nobody has to wait forever: play now, and the other side races your run later.
                if model.offersPlayNow(at: tl.date) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Can't wait?").font(.ui(15, .semibold)).foregroundStyle(Theme.text)
                        Text("Play now and \(model.opponent?.name ?? (model.isHost ? "your friend" : model.hostName)) races your run when they open the link. It counts the same.")
                            .font(.ui(14)).foregroundStyle(Theme.muted)
                        Button(model.busy == .playNow ? "Starting…" : "Play now") { Task { await model.playNow() } }
                            .buttonStyle(.secondary)
                            .disabled(model.busy != nil)
                    }
                    .padding(16)
                    .card(16)
                }
            }
        }
        if model.isHost {
            Button(model.busy == .close ? "Closing…" : "Close this room") { Task { await model.close() } }
                .font(.ui(14)).foregroundStyle(Theme.muted).underline()
                .disabled(model.busy != nil)
        }
    }
}

// You against the friend, who is a question mark until they arrive.
struct Versus: View {
    let me: String
    let friend: String?

    var body: some View {
        HStack(spacing: 12) {
            seat(me, label: "You")
            Text("VS")
                .font(.display(14)).foregroundStyle(Theme.soft)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.raised))
                .rotationEffect(.degrees(-6))
            if let friend {
                seat(friend, label: "Friend").transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: 8) {
                    Text("?")
                        .font(.display(26)).foregroundStyle(Theme.faint)
                        .frame(width: 64, height: 64)
                        .overlay(Circle().strokeBorder(Theme.lineStrong, style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
                        .phaseAnimator([0.45, 1]) { view, opacity in view.opacity(opacity) } animation: { _ in .easeInOut(duration: 1) }
                    Text("Waiting…").font(.ui(12, .semibold)).foregroundStyle(Theme.faint)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(22)
        .card(28)
        .sticker(28, pop: Color(hex: "4a2612"))
        .overlay(alignment: .topTrailing) {
            TikoView(mood: friend == nil ? .think : .cheer, size: 72)
                .offset(x: -14, y: -TikoView.height(for: 72) + 10)
        }
    }

    private func seat(_ name: String, label: String) -> some View {
        VStack(spacing: 8) {
            Avatar(name: name, size: 64)
            Text(name).font(.ui(14, .bold)).foregroundStyle(Theme.text).lineLimit(1)
            Text(label.uppercased()).font(.mono(10, .bold)).tracking(1.2).foregroundStyle(Theme.faint)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PulseDot: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 7)).symbolEffect(.pulse)
            configuration.title
        }
    }
}
