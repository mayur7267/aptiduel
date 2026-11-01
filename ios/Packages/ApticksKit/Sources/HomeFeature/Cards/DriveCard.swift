import DesignSystem
import Domain
import SwiftUI

// The placement test you're preparing for: set it, count down to it,
// then say how it went.
struct DriveCard: View {
    @Bindable var model: DriveViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.showsForm {
                form
            } else if let drive = model.drive {
                if model.asksHowItWent {
                    howDidItGo(drive)
                } else if model.stage == .answered {
                    thanks(drive)
                } else {
                    countdown(drive)
                }
            }
            if let error = model.error { ErrorNote(error) }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Theme.surface
                RadialGradient(colors: [Theme.violet.opacity(0.14), .clear], center: .topTrailing, startRadius: 0, endRadius: 240)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.line))
        .animation(.snappy, value: model.drive)
        .animation(.snappy, value: model.editing)
    }

    @ViewBuilder
    private var form: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.violet)
                .frame(width: 36, height: 36).background(RoundedRectangle(cornerRadius: 10).fill(Theme.violetTint))
            VStack(alignment: .leading, spacing: 2) {
                Text(model.editing ? "Change your test" : "When's your placement test?").font(.ui(17, .bold)).foregroundStyle(Theme.text)
                Text("We'll count down to it and show what to practise.").font(.ui(13)).foregroundStyle(Theme.muted)
            }
        }
        HStack {
            Text("Company").font(.ui(14, .semibold)).foregroundStyle(Theme.muted)
            Spacer()
            Picker("Company", selection: $model.company) {
                ForEach(COMPANIES) { Text($0.name).tag($0.name) }
                Text(DriveViewModel.other).tag(DriveViewModel.other)
            }
            .tint(Theme.text)
        }
        if model.company == DriveViewModel.other {
            TextField("", text: $model.otherCompany, prompt: Text("Company name").foregroundColor(Theme.faint))
                .padding(.horizontal, 14).frame(minHeight: 44).card(12)
                .accessibilityLabel("Company name")
        }
        DatePicker("Test date", selection: $model.date, in: model.dateRange, displayedComponents: .date)
            .font(.ui(14, .semibold)).foregroundStyle(Theme.muted).tint(Theme.lime)
        HStack(spacing: 16) {
            Button(model.busy ? "Saving…" : model.editing ? "Save" : "Start countdown") { Task { await model.save() } }
                .buttonStyle(.lime)
                .disabled(!model.canSave)
            if model.editing {
                Button("Cancel") { model.cancelEditing() }.font(.ui(14)).foregroundStyle(Theme.muted).underline()
            }
        }
        if model.drive?.company != nil {
            Button("I don't have a test coming up") { Task { await model.clear() } }
                .font(.ui(13)).foregroundStyle(Theme.muted).underline()
        }
    }

    @ViewBuilder
    private func countdown(_ drive: Drive) -> some View {
        let company = drive.company ?? ""
        let today = model.stage == .today
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(today ? "🍀" : "\(drive.daysLeft ?? 0)").font(.display(44)).foregroundStyle(Theme.violet)
            Text(today ? "today" : drive.daysLeft == 1 ? "day to go" : "days to go").font(.ui(14, .semibold)).foregroundStyle(Theme.muted)
        }
        Text(today ? "\(company) is today. All the best!" : "\(company) on \(drive.prettyDate ?? "")")
            .font(.ui(17, .bold)).foregroundStyle(Theme.text)
        Text((drive.practised ?? 0) > 0
            ? "Last 30 days: \(drive.practised ?? 0) \(drive.practised == 1 ? "question" : "questions") on \(company) topics, \(drive.accuracy ?? 0)% right."
            : "No practice on \(company) topics yet. A company duel takes about 3 minutes.")
            .font(.ui(14)).foregroundStyle(Theme.muted)
        if let weak = drive.weakTopics, !weak.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "scope").foregroundStyle(Theme.orange)
                Text("Work on").foregroundStyle(Theme.muted)
                ForEach(weak, id: \.self) { Chip($0, fg: Theme.orange, bg: Theme.orangeTint) }
            }
            .font(.ui(13))
        }
        HStack(spacing: 16) {
            Button { model.practise() } label: {
                HStack(spacing: 4) { Text(today ? "Warm up" : "Practise \(Domain.company(named: drive.company)?.name ?? "now")"); Image(systemName: "chevron.right") }
            }
            .buttonStyle(.lime)
            if today {
                Button("Done already? Tell us how it went") { model.startReporting() }
                    .font(.ui(14, .semibold)).foregroundStyle(Theme.lime)
            } else {
                Button("Change") { model.startEditing() }.font(.ui(14)).foregroundStyle(Theme.muted).underline()
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func howDidItGo(_ drive: Drive) -> some View {
        Text("How did \(drive.company ?? "your test") go?").font(.ui(17, .bold)).foregroundStyle(Theme.text)
        Text("Two taps. Your answer stays private, and it helps us show everyone what a rating means for clearing each test.")
            .font(.ui(13)).foregroundStyle(Theme.muted)
        if model.cleared == nil {
            Text("Did you clear the online test?").font(.ui(14, .semibold)).foregroundStyle(Theme.text)
            HStack(spacing: 8) {
                choice("Cleared it 🎉") { await model.answer("yes") }
                choice("Didn't clear") { await model.answer("no") }
                choice("Didn't take it") { await model.answer("skipped") }
            }
        } else {
            Text("Compared with Apticks, the test was…").font(.ui(14, .semibold)).foregroundStyle(Theme.text)
            HStack(spacing: 8) {
                choice("Easier") { await model.finish(difficulty: "easier") }
                choice("About the same") { await model.finish(difficulty: "same") }
                choice("Harder") { await model.finish(difficulty: "harder") }
            }
            Button("Back") { model.back() }.font(.ui(13)).foregroundStyle(Theme.muted).underline()
        }
    }

    private func choice(_ label: String, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Text(label).font(.ui(13, .semibold)).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
        .buttonStyle(FilledStyle(fill: Theme.raised, foreground: Theme.text, border: Theme.line, radius: 12, height: 52))
        .disabled(model.busy)
    }

    @ViewBuilder
    private func thanks(_ drive: Drive) -> some View {
        let company = drive.company ?? "your test"
        Text(drive.cleared == "yes" ? "🎉" : drive.cleared == "no" ? "💪" : "🙏").font(.system(size: 40))
        Text(drive.cleared == "yes" ? "Congrats on clearing \(company)!"
             : drive.cleared == "no" ? "\(company) wasn't your day. The next one will be." : "Thanks for telling us.")
            .font(.ui(17, .bold)).foregroundStyle(Theme.text)
        Text("Got another test coming? Set it and we'll count down to it.").font(.ui(14)).foregroundStyle(Theme.muted)
        Button("Set your next test") { model.startEditing() }.buttonStyle(.lime)
    }
}
