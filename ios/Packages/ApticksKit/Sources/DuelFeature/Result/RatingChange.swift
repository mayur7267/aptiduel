import DesignSystem
import Domain
import SwiftUI
import Tiko

struct RatingChange: View {
    let before: Int
    let after: Int
    let delta: Int

    var body: some View {
        let now = tierFor(after)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rating").font(.ui(13)).foregroundStyle(Theme.muted)
                    HStack(spacing: 10) {
                        Text(grouped(before)).font(.mono(18)).foregroundStyle(Theme.muted)
                        Text("→").foregroundStyle(Theme.muted)
                        Text(grouped(after)).font(.mono(24)).foregroundStyle(Theme.text)
                    }
                }
                Spacer()
                Text(signed(delta))
                    .font(.ui(15, .bold))
                    .foregroundStyle(delta >= 0 ? Theme.ink : Theme.redSoft)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(delta >= 0 ? Theme.lime : Theme.redTint))
                    .popIn(0.2)
            }
            if promoted(from: before, to: after) {
                HStack(spacing: 12) {
                    Image(systemName: "shield.fill").foregroundStyle(Theme.violetSoft)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.violetStrong))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Promoted to \(now.name)").font(.ui(14, .bold)).foregroundStyle(Theme.violetSoft)
                        if let next = now.next {
                            Text("Next: \(next.name) at \(grouped(next.min))").font(.ui(12)).foregroundStyle(Theme.violet)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.violetTint))
            }
        }
        .padding(16)
        .card(20)
    }
}
