import AppCore
import DesignSystem
import Domain
import SwiftUI
import Tiko

public struct ChallengeView: View {
    @State private var model: ChallengeViewModel

    public init(model: ChallengeViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton("Back to home") { model.close() }
                Spacer()
                Logo()
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                Group {
                    if let lobby = model.lobby {
                        LobbyView(model: lobby)
                    } else if let error = model.error {
                        ErrorNote(error) { Task { await model.load() } }
                    } else if let status = model.status {
                        OwnerView(model: model, status: status)
                    } else if let challenge = model.challenge, challenge.live == true {
                        LiveInviteView(model: model, challenge: challenge)
                    } else if let challenge = model.challenge {
                        FriendView(model: model, challenge: challenge)
                    } else if model.loaded {
                        notFound
                    } else {
                        Spinner("Opening the challenge")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .task { await model.load() }
        .task(id: model.status != nil) { await model.poll() }
        .task(id: model.lobby?.duelId) { await model.lobby?.poll() }
        .animation(.snappy, value: model.status)
    }

    private var notFound: some View {
        VStack(spacing: 12) {
            TikoView(mood: .confused, size: 96)
            Text("Challenge not found").font(.display(22)).foregroundStyle(Theme.text)
            Text("This link doesn't match any challenge. Check it with your friend, or start your own.")
                .font(.ui(15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Button("Start your own") { model.close() }.buttonStyle(.lime).padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// What a friend sees: who challenged them, the score to beat, and Accept.
private struct FriendView: View {
    let model: ChallengeViewModel
    let challenge: Challenge

    var body: some View {
        let ch = challenge
        VStack(alignment: .leading, spacing: 20) {
            Label("You've been challenged", systemImage: "bolt.fill")
                .font(.ui(13, .bold))
                .foregroundStyle(Theme.lime)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.limeTint))
            Text("\(ch.challenger.name) challenged you to an aptitude duel.")
                .font(.display(30)).foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("5 placement-style questions. About 3 minutes. No sign-up. Just tap play.")
                .font(.ui(17)).foregroundStyle(Theme.muted)

            HStack(spacing: 16) {
                Avatar(name: ch.challenger.name, size: 52).padding(2).background(Circle().fill(Theme.violet))
                VStack(alignment: .leading, spacing: 4) {
                    Text(ch.challenger.name).font(.ui(15, .bold)).foregroundStyle(Theme.text)
                    if let college = ch.challenger.college {
                        Text(college + (ch.challenger.gradYear.map { " · ’\(String(String($0).suffix(2)))" } ?? ""))
                            .font(.ui(13)).foregroundStyle(Theme.muted)
                    }
                    TierBadge(rating: ch.challenger.rating, showRating: true).padding(.top, 2)
                }
                Spacer(minLength: 0)
                if ch.challengerFinished {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Score to beat").font(.ui(12)).foregroundStyle(Theme.muted)
                        Text("\(ch.correct)/5").font(.mono(24)).foregroundStyle(Theme.text)
                        Text("in \(clock(ch.totalMs))").font(.mono(12, .regular)).foregroundStyle(Theme.muted)
                    }
                }
            }
            .padding(16)
            .card(20, border: Theme.line, width: 2)
            .sticker(20)

            if ch.open {
                VStack(alignment: .leading, spacing: 8) {
                    Button { Task { await model.accept() } } label: {
                        Label(model.accepting ? "Starting…" : "Accept challenge", systemImage: "play.fill").font(.ui(17, .bold))
                    }
                    .buttonStyle(PressableStyle(fill: Theme.lime, foreground: Theme.ink, pop: Theme.limePop, radius: 16, height: 58))
                    .disabled(model.accepting)
                    if let error = model.acceptError { Text(error).font(.ui(14)).foregroundStyle(Theme.redSoft) }
                }
            } else {
                Text("This challenge has expired. Start a new one from home.")
                    .font(.ui(14)).foregroundStyle(Theme.muted)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).card(16)
            }

            HStack(spacing: 16) {
                ForEach(["Free", "Quant, reasoning, verbal"], id: \.self) { t in
                    Label { Text(t) } icon: { Image(systemName: "checkmark").foregroundStyle(Theme.lime).fontWeight(.black) }
                        .font(.ui(13)).foregroundStyle(Theme.muted)
                }
                if ch.acceptedCount > 0 {
                    Text("\(ch.acceptedCount) already played").font(.ui(13)).foregroundStyle(Theme.muted)
                }
            }

            // Tiko perches on a picture of the duel screen, waving the friend in.
            DuelPreview()
                .overlay(alignment: .topLeading) { TikoView(mood: .wave, size: 84).offset(x: -6, y: -74) }
                .padding(.top, 72)

            Text("How a duel works").font(.display(22)).foregroundStyle(Theme.text).padding(.top, 20)
            ForEach([
                ("01", "Same 5 questions", "You get exactly the questions your friend played. 25 to 75 seconds each."),
                ("02", "Beat the score", "100 points for every correct answer, plus up to 50 for speed."),
                ("03", "Earn your rating", "Win to climb from Fresher to Architect, and put your college on the board."),
            ], id: \.0) { n, title, body in
                VStack(alignment: .leading, spacing: 8) {
                    Text(n).font(.display(22)).foregroundStyle(Theme.lime)
                    Text(title).font(.ui(17, .bold)).foregroundStyle(Theme.text)
                    Text(body).font(.ui(15)).foregroundStyle(Theme.muted)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(20)
            }
        }
    }
}

// What the challenger sees on their own link.
private struct OwnerView: View {
    let model: ChallengeViewModel
    let status: ChallengeStatus

    var body: some View {
        let me = status.me
        VStack(alignment: .leading, spacing: 20) {
            TikoView(mood: model.ownerMood, size: 88)
            (Text("Your challenge · ") + Text(status.code).font(.mono(13)))
                .font(.ui(13, .bold))
                .foregroundStyle(Theme.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.orangeTint))
            Text(model.ownerTitle).font(.display(30)).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
            Text(me.finished
                ? "You scored \(me.correct)/5 in \(clock(me.totalMs)). Everyone who opens this link races your run."
                : "You haven't played your turn yet. Play now or after your friend: whoever goes second races the other's run.")
                .font(.ui(17)).foregroundStyle(Theme.muted)

            if status.open {
                if !me.finished {
                    Button { model.open(.duel(status.duelId)) } label: {
                        Label("Play your turn", systemImage: "play.fill").font(.ui(17, .bold))
                    }
                    .buttonStyle(PressableStyle(fill: Theme.lime, foreground: Theme.ink, pop: Theme.limePop, radius: 16, height: 56, fullWidth: false))
                }
                SharePanel(code: status.code, text: model.shareText)
            } else {
                Text("This link has expired, so new friends can't join. Start a new challenge from home.")
                    .font(.ui(14)).foregroundStyle(Theme.muted)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).card(16)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Friends").font(.ui(15, .bold)).foregroundStyle(Theme.text).padding(.bottom, 8)
                if status.friends.isEmpty {
                    Text("Nobody has opened your link yet. It stays open for 7 days.").font(.ui(14)).foregroundStyle(Theme.muted)
                }
                ForEach(Array(status.friends.enumerated()), id: \.element.id) { i, f in
                    if i > 0 { Rectangle().fill(Theme.line).frame(height: 1) }
                    // Before you've played, every row leads to your own turn.
                    Button { model.open(me.finished ? .result(f.duelId) : .duel(status.duelId)) } label: {
                        FriendRow(friend: f, me: me)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(20)

            Button("Back to home") { model.close() }.font(.ui(14, .semibold)).foregroundStyle(Theme.lime)
        }
    }
}

// A live room you're not in yet: who's inviting you, and Join (after
// signing in, for a guest).
private struct LiveInviteView: View {
    let model: ChallengeViewModel
    let challenge: Challenge

    var body: some View {
        let ch = challenge
        let closed = !ch.open || ch.started == true || ch.full == true
        VStack(alignment: .leading, spacing: 20) {
            Label("Live duel", systemImage: "circle.fill")
                .labelStyle(PulseDot())
                .font(.ui(13, .bold))
                .foregroundStyle(Theme.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.orangeTint))
            Text("\(ch.challenger.name) wants to duel you, live.")
                .font(.display(30)).foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("You race through the same 5 placement questions, starting together. Fast and right wins. About 3 minutes.")
                .font(.ui(17)).foregroundStyle(Theme.muted)

            HStack(spacing: 16) {
                Avatar(name: ch.challenger.name, size: 52).padding(2).background(Circle().fill(Theme.violet))
                VStack(alignment: .leading, spacing: 4) {
                    Text(ch.challenger.name).font(.ui(15, .bold)).foregroundStyle(Theme.text)
                    if let college = ch.challenger.college {
                        Text(college).font(.ui(13)).foregroundStyle(Theme.muted)
                    }
                    TierBadge(rating: ch.challenger.rating, showRating: true).padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .card(20)

            if closed {
                Text(ch.started == true || ch.full == true
                    ? "\(ch.challenger.name) is already in a duel with someone else."
                    : "This duel has closed. Ask your friend for a new link.")
                    .font(.ui(14)).foregroundStyle(Theme.muted)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(16)
                Button("Start your own") { model.close() }.buttonStyle(.lime)
            } else if let signIn = model.signIn {
                SignInForm(model: signIn)
            } else if model.guest {
                Button { model.startSignIn() } label: {
                    Label("Sign in to join", systemImage: "play.fill")
                }
                .buttonStyle(.lime)
                Text("Friend duels are between real accounts, so you both know who you're playing. It takes a code from your email, nothing else.")
                    .font(.ui(14)).foregroundStyle(Theme.muted)
            } else {
                Button { Task { await model.joinLive() } } label: {
                    Label(model.accepting ? "Joining…" : "Join the duel", systemImage: "play.fill")
                }
                .buttonStyle(.lime)
                .disabled(model.accepting)
            }
            if let error = model.acceptError { ErrorNote(error) }
        }
    }
}
