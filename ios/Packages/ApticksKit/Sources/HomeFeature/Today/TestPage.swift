import DesignSystem
import Domain
import SwiftUI

// The placement test you're preparing for: count down to it, then say
// how it went. Setting or changing it opens a sheet, so the page stays
// the size of the others in the deck.
struct TestPage: View {
    @Bindable var model: DriveViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let drive = model.drive, model.stage != .unset {
                if model.asksHowItWent {
                    howDidItGo(drive)
                } else if model.stage == .answered {
                    thanks(drive)
                } else {
                    countdown(drive)
                }
            } else {
                prompt
            }
            if let error = model.error, !model.editing { ErrorNote(error) }
        }
        .deckPage(
            ZStack {
                Theme.surface
                RadialGradient(colors: [Theme.violet.opacity(0.16), .clear], center: .topTrailing, startRadius: 0, endRadius: 240)
            },
            border: Theme.line)
        .animation(.snappy, value: model.drive)
        .animation(.snappy, value: model.cleared)
        .sheet(isPresented: Binding(get: { model.editing }, set: { if !$0 { model.cancelEditing() } })) {
            DriveForm(model: model)
        }
    }

    private var prompt: some View {
        PinnedBottom {
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.clock").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.violet)
                    .frame(width: 36, height: 36).background(RoundedRectangle(cornerRadius: 10).fill(Theme.violetTint))
                Text("When's your placement test?").font(.display(16)).foregroundStyle(Theme.text)
            }
            Text("Pick the company and the date. We'll count down and show what to practise.")
                .font(.ui(13)).foregroundStyle(Theme.muted)
        } bottom: {
            Button("Set my test") { model.startEditing() }
                .buttonStyle(PressableStyle(fill: Theme.lime, foreground: Theme.ink, pop: Theme.limePop, height: 44))
        }
    }

    private func countdown(_ drive: Drive) -> some View {
        let company = drive.company ?? ""
        let today = model.stage == .today
        return PinnedBottom {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    Text(today ? "🍀" : "\(drive.daysLeft ?? 0)").font(.display(36)).foregroundStyle(Theme.violet)
                    Text(today ? "today" : drive.daysLeft == 1 ? "day to go" : "days to go")
                        .font(.ui(11, .semibold)).foregroundStyle(Theme.muted)
                }
                .frame(minWidth: 76)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.violetTint))
                VStack(alignment: .leading, spacing: 4) {
                    Text(today ? "\(company) is today. All the best!" : "\(company) on \(drive.prettyDate ?? "")")
                        .font(.ui(16, .bold)).foregroundStyle(Theme.text)
                    Text((drive.practised ?? 0) > 0
                        ? "Last 30 days: \(drive.practised ?? 0) \(drive.practised == 1 ? "question" : "questions"), \(drive.accuracy ?? 0)% right."
                        : "No practice on its topics yet. A company duel takes about 3 minutes.")
                        .font(.ui(13)).foregroundStyle(Theme.muted)
                    if let weak = drive.weakTopics, !weak.isEmpty {
                        (Text(Image(systemName: "scope")) + Text(" Work on ") + Text(weak.joined(separator: ", ")).bold())
                            .font(.ui(13)).foregroundStyle(Theme.orange).lineLimit(2)
                    }
                }
            }
        } bottom: {
            HStack(spacing: 16) {
                Button { model.practise() } label: {
                    HStack(spacing: 4) {
                        Text(today ? "Warm up" : "Practise \(Domain.company(named: drive.company)?.name ?? "now")").lineLimit(1)
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(PressableStyle(fill: Theme.lime, foreground: Theme.ink, pop: Theme.limePop, height: 44, fullWidth: false))
                if today {
                    Button("Done? Tell us how it went") { model.startReporting() }
                        .font(.ui(13, .semibold)).foregroundStyle(Theme.lime)
                } else {
                    Button("Change") { model.startEditing() }.font(.ui(14)).foregroundStyle(Theme.muted).underline()
                }
            }
        }
    }

    private func howDidItGo(_ drive: Drive) -> some View {
        PinnedBottom {
            Text("How did \(drive.company ?? "your test") go?").font(.display(17)).foregroundStyle(Theme.text)
            Text("Two taps, kept private. It helps show what a rating means for clearing each test.")
                .font(.ui(13)).foregroundStyle(Theme.muted)
        } bottom: {
            if model.cleared == nil {
                Text("Did you clear the online test?").font(.ui(14, .semibold)).foregroundStyle(Theme.text)
                HStack(spacing: 8) {
                    choice("Cleared it 🎉") { await model.answer("yes") }
                    choice("Didn't clear") { await model.answer("no") }
                    choice("Didn't take it") { await model.answer("skipped") }
                }
            } else {
                HStack {
                    Text("Compared with Apticks, it was…").font(.ui(14, .semibold)).foregroundStyle(Theme.text)
                    Spacer()
                    Button("Back") { model.back() }.font(.ui(13)).foregroundStyle(Theme.muted).underline()
                }
                HStack(spacing: 8) {
                    choice("Easier") { await model.finish(difficulty: "easier") }
                    choice("About the same") { await model.finish(difficulty: "same") }
                    choice("Harder") { await model.finish(difficulty: "harder") }
                }
            }
        }
    }

    private func choice(_ label: String, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Text(label).font(.ui(13, .semibold)).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
        .buttonStyle(FilledStyle(fill: Theme.raised, foreground: Theme.text, border: Theme.line, radius: 12, height: 50))
        .disabled(model.busy)
    }

    private func thanks(_ drive: Drive) -> some View {
        let company = drive.company ?? "your test"
        return PinnedBottom {
            Text(drive.cleared == "yes" ? "🎉" : drive.cleared == "no" ? "💪" : "🙏").font(.system(size: 32))
            Text(drive.cleared == "yes" ? "Congrats on clearing \(company)!"
                 : drive.cleared == "no" ? "\(company) wasn't your day. The next one will be." : "Thanks for telling us.")
                .font(.ui(16, .bold)).foregroundStyle(Theme.text)
            Text("Got another test coming? Set it and we'll count down to it.").font(.ui(13)).foregroundStyle(Theme.muted)
        } bottom: {
            Button("Set your next test") { model.startEditing() }
                .buttonStyle(PressableStyle(fill: Theme.lime, foreground: Theme.ink, pop: Theme.limePop, height: 44))
        }
    }
}

// Setting or changing the test: company and date.
struct DriveForm: View {
    @Bindable var model: DriveViewModel
    // The sheet fits the form, which grows for "Another company".
    @State private var height: CGFloat = 340

    // No countdown running: this starts one.
    private var fresh: Bool { model.stage == .unset || model.stage == .answered }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "calendar").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.violet)
                    .frame(width: 38, height: 38).background(RoundedRectangle(cornerRadius: 11).fill(Theme.violetTint))
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.stage == .unset ? "When's your placement test?" : fresh ? "When's your next test?" : "Change your test")
                        .font(.ui(17, .bold)).foregroundStyle(Theme.text)
                    Text("We'll count down to it and show what to practise.").font(.ui(13)).foregroundStyle(Theme.muted)
                }
            }
            VStack(spacing: 0) {
                HStack {
                    Text("Company").font(.ui(15, .semibold)).foregroundStyle(Theme.soft)
                    Spacer()
                    Picker("Company", selection: $model.company) {
                        ForEach(COMPANIES) { Text($0.name).tag($0.name) }
                        Text(DriveViewModel.other).tag(DriveViewModel.other)
                    }
                    .tint(Theme.text)
                }
                .frame(minHeight: 50)
                Rectangle().fill(Theme.line).frame(height: 1)
                DatePicker("Test date", selection: $model.date, in: model.dateRange, displayedComponents: .date)
                    .font(.ui(15, .semibold)).foregroundStyle(Theme.soft).tint(Theme.lime)
                    .frame(minHeight: 50)
            }
            .padding(.horizontal, 14)
            .card(14, fill: Theme.raised)
            if model.company == DriveViewModel.other {
                TextField("", text: $model.otherCompany, prompt: Text("Company name").foregroundColor(Theme.faint))
                    .padding(.horizontal, 14).frame(minHeight: 48).card(14, fill: Theme.raised)
                    .accessibilityLabel("Company name")
            }
            if let error = model.error { ErrorNote(error) }
            Button(model.busy ? "Saving…" : fresh ? "Start countdown" : "Save") { Task { await model.save() } }
                .buttonStyle(PressableStyle(fill: Theme.lime, foreground: Theme.ink, pop: Theme.limePop))
                .disabled(!model.canSave)
            HStack {
                Button("Cancel") { model.cancelEditing() }.font(.ui(14)).foregroundStyle(Theme.muted)
                Spacer()
                if model.drive?.company != nil {
                    Button("I don't have a test coming up") { Task { await model.clear() } }
                        .font(.ui(13)).foregroundStyle(Theme.muted).underline()
                }
            }
        }
        .padding(24)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.surface)
        .presentationCornerRadius(28)
    }
}
