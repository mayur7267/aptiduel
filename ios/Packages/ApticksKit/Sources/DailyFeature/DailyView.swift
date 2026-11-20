import AppCore
import DesignSystem
import Domain
import SwiftUI
import Tiko

public struct DailyView: View {
    let model: DailyViewModel
    @Environment(AppRouter.self) private var router

    public init(model: DailyViewModel) { self.model = model }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Logo()
                Text("Daily Challenge").font(.display(24)).foregroundStyle(Theme.text)
                if let error = model.error {
                    ErrorNote(error) { Task { await model.load() } }
                } else if model.duel != nil || model.ready {
                    card(model.duel).rise()
                } else {
                    Spinner("Opening today's challenge")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .refreshable { await Task { await model.load() }.value }
        .task(id: router.refresh) { await model.load() }
    }

    private func card(_ duel: Duel?) -> some View {
        let finished = model.finished
        return VStack(alignment: .leading, spacing: 16) {
            TikoView(mood: finished ? .cheer : .wave, size: 76)
            VStack(alignment: .leading, spacing: 6) {
                Text(finished ? "Done for today" : "Today's Daily Challenge")
                    .font(.display(22)).foregroundStyle(Theme.text)
                Text(finished
                    ? "You scored \(duel?.me.correct ?? 0)/5 in \(clock(duel?.me.totalMs ?? 0)). A new set opens in \(untilIstMidnight(Date()))."
                    : "5 questions, the same for everyone today. You get one try, and the clock starts when you press Start.")
                    .font(.ui(15)).foregroundStyle(Theme.violetSoft.opacity(0.8))
            }
            Button(finished ? "See today's rank" : model.starting ? "Starting…" : "Start") {
                if finished { model.open() } else { Task { await model.start() } }
            }
            .buttonStyle(PressableStyle(fill: Theme.text, foreground: Theme.ink, pop: Theme.violetStrong, radius: 16, fullWidth: false))
            .disabled(model.starting)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(stops: [.init(color: Theme.violetDeep, location: 0), .init(color: Theme.surface, location: 0.7)],
                           startPoint: UnitPoint(x: 0.25, y: 0), endPoint: UnitPoint(x: 0.75, y: 1))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.violetStrong, lineWidth: 2))
    }
}
