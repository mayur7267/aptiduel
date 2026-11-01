import DesignSystem
import Domain
import SwiftUI
import Tiko

// About you: Tiko drops onto a name tag and reacts as you type: thinking
// while it's empty, a happy jump once the name is long enough.
struct NameScene: View {
    let start: Date?
    @Bindable var model: OnboardingViewModel
    var focused: FocusState<Bool>.Binding
    @State private var picking = false
    @State private var cheers = 0
    private let size: CGFloat = 88

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let tagTop = geo.size.height * 0.36
            let perch = CGPoint(x: w * 0.5 + 70, y: tagTop)
            let fall = sqrt(2 * Double(perch.y + 120) / 2_600)

            ZStack(alignment: .top) {
                // Tapping around the tag puts the keyboard away.
                Color.clear.contentShape(Rectangle()).onTapGesture { focused.wrappedValue = false }
                tag
                    .padding(.horizontal, 24)
                    .offset(y: tagTop)
                SceneTimeline(start: start, length: fall + 1) { t in
                    ZStack {
                        Dust(t: t - fall, at: perch)
                        TikoActor(pose: pose(t, perch: perch, fall: fall), size: size,
                                  play: cheers > 0 ? TikoPlay(move: .boing, key: cheers) : nil)
                    }
                    .frame(width: w, height: geo.size.height)
                    .allowsHitTesting(false)
                }
            }
            .sceneHaptics(start, [(fall, .medium)])
        }
        .onChange(of: model.nameIsValid) { _, valid in if valid { cheers += 1 } }
        .sheet(isPresented: $picking) {
            CollegePicker(colleges: model.colleges, selected: $model.collegeId)
                .presentationDetents([.large])
                .preferredColorScheme(.dark)
        }
    }

    private func pose(_ t: Double, perch: CGPoint, fall: Double) -> TikoPose {
        let mood: TikoMood = model.nameIsValid ? .happy : model.name.isEmpty ? (focused.wrappedValue ? .think : .wave) : .think
        if t < fall {
            // Dropped in from above the screen, speeding up as it falls.
            let y = -120 + 0.5 * 2_600 * t * t
            return TikoPose(feet: CGPoint(x: perch.x, y: y), mood: .giggle, sx: 0.94, sy: 1.08)
        }
        let (sx, sy) = Landing.squash(t, landed: fall)
        return TikoPose(feet: perch, mood: mood, still: t < fall + 0.4, sx: sx, sy: sy)
    }

    private var tag: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("HELLO, MY NAME IS")
                .font(.mono(11))
                .tracking(1.4)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.lime))
            TextField("", text: $model.name, prompt: Text("Your name").foregroundColor(Theme.faint))
                .font(.display(22))
                .foregroundStyle(Theme.text)
                .textContentType(.nickname)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused(focused)
                .onSubmit { Task { await model.next() } }
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) { Rectangle().fill(model.nameIsValid ? Theme.lime : Theme.line).frame(height: 2) }
            Button { picking = true } label: {
                HStack {
                    Image(systemName: "building.columns").foregroundStyle(Theme.violet)
                    Text(model.collegeName ?? "Add your college (optional)")
                        .foregroundStyle(model.collegeId == nil ? Theme.muted : Theme.text)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.muted)
                }
                .font(.ui(14, .semibold))
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .card(12, fill: Theme.raised)
            }
            .buttonStyle(.plain)
            .disabled(model.colleges.isEmpty)
        }
        .padding(18)
        .card(22, border: Theme.line, width: 2)
        .sticker(22)
    }
}
