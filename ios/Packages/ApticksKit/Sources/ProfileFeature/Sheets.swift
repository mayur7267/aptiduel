import AppCore
import DesignSystem
import Domain
import SwiftUI
import Tiko

// What the Profile tab's tiles open.

private struct SheetHeader: View {
    let title: String
    var mood: TikoMood = .happy
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            TikoView(mood: mood, size: 48)
            Text(title).font(.display(22)).foregroundStyle(Theme.text)
            Spacer()
            CloseButton { dismiss() }
        }
    }
}

struct EditProfileSheet: View {
    let model: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SheetHeader(title: "Your profile", mood: .wave)
                ProfileForm(model: model)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: model.saved) { _, saved in
            guard saved else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                dismiss()
            }
        }
    }
}

struct AccountSheet: View {
    let model: AccountViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SheetHeader(title: "Account", mood: model.info?.guest == false ? .cheer : .think)
                AccountPanel(model: model)
                    .padding(.top, -28)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// Replay the home tour or the intro, or switch Tiko the companion off and on.
struct TikoSheet: View {
    @Environment(AppRouter.self) private var router
    @Environment(CompanionState.self) private var companion
    @Environment(TourState.self) private var tour
    @Environment(OnboardingState.self) private var onboarding
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(title: "Tiko")
            Text("Your little buddy in the corner. Tap Tiko for a tip, or five times fast for a surprise.")
                .font(.ui(15)).foregroundStyle(Theme.muted)
            row("Replay the app tour", icon: "map.fill") {
                tour.replayRequested = true
                router.tab = .home
                dismiss()
            }
            row("Replay the intro", icon: "sparkles") {
                dismiss()
                onboarding.replay()
            }
            Toggle(isOn: Binding(get: { !companion.off }, set: { companion.off = !$0 })) {
                Label("Show Tiko in the corner", systemImage: "face.smiling.inverse").font(.ui(16, .semibold)).foregroundStyle(Theme.text)
            }
            .tint(Theme.lime)
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .card(16, fill: Theme.raised)
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func row(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon).font(.ui(16, .semibold)).foregroundStyle(Theme.text)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .card(16, fill: Theme.raised)
        }
        .buttonStyle(Press())
    }
}

// Pick a company to practise for.
struct PracticeSheet: View {
    let onPick: (Company) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(title: "Practise for…", mood: .think)
                Text("A rated duel using only the topics on that company's aptitude test.")
                    .font(.ui(14)).foregroundStyle(Theme.muted)

                VStack(spacing: 10) {
                    ForEach(COMPANIES) { c in
                        if c.comingSoon {
                            HStack(spacing: 12) {
                                Text(c.emoji)
                                    .font(.system(size: 20))
                                    .frame(width: 38, height: 38)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: c.hex).opacity(0.18)))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: c.hex).opacity(0.4), lineWidth: 1))
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(c.name).font(.ui(15, .bold)).foregroundStyle(Theme.text.opacity(0.6))
                                        Text("SOON")
                                            .font(.mono(9, .bold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Theme.ink)
                                            .foregroundStyle(Theme.muted)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    Text(c.blurb).font(.ui(12)).foregroundStyle(Theme.muted.opacity(0.7))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 56)
                            .card(16, fill: Theme.raised.opacity(0.5))
                            .opacity(0.7)
                        } else {
                            Button { onPick(c) } label: {
                                HStack(spacing: 12) {
                                    Text(c.emoji)
                                        .font(.system(size: 20))
                                        .frame(width: 38, height: 38)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: c.hex).opacity(0.22)))
                                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: c.hex).opacity(0.5), lineWidth: 1))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.name).font(.ui(16, .bold)).foregroundStyle(Theme.text)
                                        Text(c.blurb).font(.ui(12)).foregroundStyle(Theme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "bolt.fill").foregroundStyle(Theme.lime)
                                }
                                .padding(.horizontal, 14)
                                .frame(minHeight: 58)
                                .card(16, fill: Theme.raised)
                            }
                            .buttonStyle(Press())
                        }
                    }
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }
}
