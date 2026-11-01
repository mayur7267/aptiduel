import AppCore
import DesignSystem
import Domain
import SwiftUI
import Tiko

// The Profile tab, as a page from a placement student's folder: your
// player card swinging on a lanyard, your rating on graph paper, a
// report card, a sticker book and sticky notes. Editing, the account and
// Tiko's settings open in sheets.
public struct ProfileView: View {
    let profile: ProfileViewModel
    let account: AccountViewModel
    @Environment(AppRouter.self) private var router
    @Environment(FeedbackState.self) private var feedback
    @State private var sheet: ProfileSheet?
    @State private var tilt = Tilt()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(profile: ProfileViewModel, account: AccountViewModel) {
        self.profile = profile
        self.account = account
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Logo()
                    Spacer()
                    RedPen(text: "tap, drag or tilt your card", size: 13, tilt: -2)
                }

                if let me = profile.me {
                    page(me)
                } else if let error = profile.error {
                    ErrorNote(error) { Task { await profile.load() } }
                } else {
                    Spinner()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .refreshable { await reload() }
        // Load afresh each visit, and after the account changes.
        .task(id: router.refresh) { await reload() }
        .onAppear { if !reduceMotion { tilt.start() } }
        .onDisappear { tilt.stop() }
        .sheet(item: $sheet) { which in
            Group {
                switch which {
                case .edit: EditProfileSheet(model: profile)
                case .account: AccountSheet(model: account)
                case .tiko: TikoSheet()
                case .practice: PracticeSheet { company in
                    sheet = nil
                    router.open(.matchmaking(company))
                }
                }
            }
            .presentationDetents(which == .practice ? [.medium, .large] : [.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.surface)
            .preferredColorScheme(.dark)
        }
    }

    private func reload() async {
        async let p: Void = profile.load()
        async let a: Void = account.load()
        _ = await (p, a)
    }

    private func page(_ me: Me) -> some View {
        let saved = account.info?.guest == false
        return VStack(spacing: 14) {
            IDBadge(me: me, saved: saved, tilt: tilt) { sheet = .edit }
            ProgressGraph(me: me, history: profile.ratingHistory, rating: me.rating, weekChange: profile.weekChange, winRate: profile.winRate)
                .rise(0.1)
            StickerBook(stickers: Achievement.all(for: me, saved: saved))
                .rise(0.16)
            ReportCard(me: me, winRate: profile.winRate)
                .rise(0.22)
            StickyNotes(onReport: { feedback.open(.bug, context: ["from": "profile"]) },
                        onIdea: { feedback.open(.idea, context: ["from": "profile"]) })
                .rise(0.28)
            VStack(spacing: 0) {
                row("Tiko & the tour", "Replay the tour or intro, show or hide Tiko", icon: "face.smiling") { sheet = .tiko }
                Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 52)
                row(saved ? "Account" : "Save your progress", saved ? (account.info?.email ?? "Saved") : "Keep your rating on any device",
                    icon: saved ? "checkmark.shield" : "lock.open", accent: !saved) { sheet = .account }
                Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 52)
                row("Practise for a company", "11 companies · TCS, Infosys, Cognizant, etc.", icon: "building.2") { sheet = .practice }
            }
            .card(20)
            .rise(0.34)
        }
    }

    private func row(_ title: String, _ detail: String, icon: String, accent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent ? Theme.ink : Theme.lime)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10).fill(accent ? Theme.lime : Theme.limeTint))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.ui(15, .semibold)).foregroundStyle(Theme.text)
                    Text(detail).font(.ui(12)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(Press())
    }
}

enum ProfileSheet: String, Identifiable {
    case edit, account, tiko, practice
    var id: String { rawValue }
}

// A labelled form field.
struct Field<Content: View>: View {
    let label: String
    var hint: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.ui(14, .semibold)).foregroundStyle(Theme.text)
            content
                .font(.ui(15))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .card(12)
            if let hint { Text(hint).font(.ui(12)).foregroundStyle(Theme.muted) }
        }
    }
}

// A section below a divider.
struct ProfileSection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 32)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
            .padding(.top, 40)
    }
}

struct ProfileForm: View {
    @Bindable var model: ProfileViewModel
    @State private var picking = false

    var body: some View {
        if model.me != nil {
            form
        } else if let error = model.error {
            ErrorNote(error).padding(.top, 24)
        } else {
            Spinner()
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 20) {
            Field(label: "Name", hint: "Shown on challenges and leaderboards.") {
                TextField("", text: $model.name, prompt: Text("What friends call you").foregroundColor(Theme.faint))
                    .textContentType(.nickname)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
            }
            Field(label: "College") {
                Button { picking = true } label: {
                    HStack {
                        Text(model.collegeName ?? "Choose your college")
                            .foregroundStyle(model.collegeId == nil ? Theme.faint : Theme.text)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Field(label: "Graduation year") {
                Menu {
                    Button("Choose a year") { model.gradYear = nil }
                    ForEach(ProfileViewModel.years, id: \.self) { y in Button(String(y)) { model.gradYear = y } }
                } label: {
                    HStack {
                        Text(model.gradYear.map { String($0) } ?? "Choose a year")
                            .foregroundStyle(model.gradYear == nil ? Theme.faint : Theme.text)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
                }
            }
            if let error = model.error { ErrorNote(error) }
            Button { Task { await model.save() } } label: {
                HStack(spacing: 8) {
                    if model.saved { Image(systemName: "checkmark") }
                    Text(model.saving ? "Saving…" : model.saved ? "Saved" : "Save")
                }
                .font(.ui(16, .bold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(FilledStyle(fill: Theme.lime, foreground: Theme.ink, height: 56))
            .disabled(!model.canSave)
            .sensoryFeedback(.success, trigger: model.saved) { _, now in now }
        }
        .padding(.top, 24)
        .sheet(isPresented: $picking) {
            CollegePicker(colleges: model.colleges, selected: $model.collegeId)
                .presentationDetents([.large])
                .preferredColorScheme(.dark)
        }
    }
}
