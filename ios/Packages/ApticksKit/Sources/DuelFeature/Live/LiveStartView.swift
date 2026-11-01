import AppCore
import DesignSystem
import Domain
import SwiftUI
import Tiko

public struct LiveStartView: View {
    @State private var model: LiveStartViewModel

    public init(model: LiveStartViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        Group {
            if let error = model.error {
                VStack(alignment: .leading, spacing: 16) {
                    ErrorNote(error) { Task { await model.retry() } }
                    Button("Back to home") { model.leave() }.font(.ui(14, .semibold)).foregroundStyle(Theme.lime)
                }
                .padding(16)
                .frame(maxHeight: .infinity, alignment: .top)
            } else if let state = model.state {
                countdown(me: state.me.name, opponent: state.opponent?.name ?? "…", left: model.secondsLeft)
            } else {
                Spinner("Loading duel").frame(maxHeight: .infinity)
            }
        }
        .task { await model.poll() }
        .task { await model.runClock() }
    }

    private func countdown(me: String, opponent: String, left: Int) -> some View {
        VStack(spacing: 32) {
            Spacer()
            Label("Live duel", systemImage: "circle.fill")
                .font(.ui(13, .bold)).foregroundStyle(Theme.orange)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Theme.orangeTint))
            HStack(spacing: 14) {
                side(me, label: "You", ring: Theme.lime)
                Text("VS").font(.display(16)).foregroundStyle(Theme.soft)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.raised))
                    .rotationEffect(.degrees(-6))
                side(opponent, label: opponent, ring: Theme.orange)
            }
            .padding(.horizontal, 24)
            if left > 3 {
                Text("Get ready…").font(.display(24)).foregroundStyle(Theme.text)
            } else {
                Text("\(max(1, left))")
                    .font(.display(96)).foregroundStyle(Theme.lime)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: left)
            }
            Text("Same 5 questions, starting together. Go at your own pace: right and fast wins, and you'll see how \(opponent) is doing as you play.")
                .font(.ui(14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.impact(weight: .medium), trigger: left)
    }

    private func side(_ name: String, label: String, ring: Color) -> some View {
        VStack(spacing: 8) {
            Avatar(name: name, size: 72).padding(3).background(Circle().fill(ring))
            Text(label).font(.ui(15, .bold)).foregroundStyle(Theme.text).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
