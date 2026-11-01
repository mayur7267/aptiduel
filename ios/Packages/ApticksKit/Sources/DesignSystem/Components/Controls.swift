import Domain
import SwiftUI

public struct CloseButton: View {
    var label: String
    let action: () -> Void

    public init(_ label: String = "Close", action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.surface))
                .overlay(Circle().strokeBorder(Theme.line))
        }
        .accessibilityLabel(label)
    }
}

// Right/wrong dots for each question of a run.
public struct ProgressDots: View {
    let marks: [AnswerMark]
    let current: Int
    let total: Int
    var ring: Color

    public init(marks: [AnswerMark], current: Int, total: Int, ring: Color = Theme.text) {
        self.marks = marks
        self.current = current
        self.total = total
        self.ring = ring
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                switch i < marks.count ? marks[i] : nil {
                case .right:
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 20, height: 20).background(Circle().fill(Theme.lime))
                        .transition(.scale.combined(with: .opacity))
                case .wrong:
                    Image(systemName: "xmark").font(.system(size: 8, weight: .black))
                        .foregroundStyle(Theme.red)
                        .frame(width: 20, height: 20).background(Circle().fill(Theme.redTint))
                        .transition(.scale.combined(with: .opacity))
                case .unknown:
                    Circle().fill(Theme.lineStrong).frame(width: 20, height: 20)
                case nil:
                    if i == current {
                        Circle().strokeBorder(ring, lineWidth: 2).frame(width: 20, height: 20)
                    } else {
                        Circle().fill(Theme.line).frame(width: 20, height: 20)
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: marks)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(marks.filter { $0 == .right }.count) correct so far")
    }
}

// The little point on a speech bubble, towards whoever is speaking.
public struct BubbleTail: View {
    var edge: HorizontalEdge

    public init(edge: HorizontalEdge = .trailing) { self.edge = edge }

    public var body: some View {
        Rectangle()
            .fill(Theme.surface)
            .frame(width: 13, height: 13)
            .overlay(alignment: edge == .trailing ? .topTrailing : .bottomLeading) {
                // Two sides of the border, so it joins the bubble's outline.
                ZStack(alignment: edge == .trailing ? .topTrailing : .bottomLeading) {
                    Rectangle().fill(Theme.line).frame(width: 13, height: 2)
                    Rectangle().fill(Theme.line).frame(width: 2, height: 13)
                }
            }
            .rotationEffect(.degrees(45))
            .accessibilityHidden(true)
    }
}
