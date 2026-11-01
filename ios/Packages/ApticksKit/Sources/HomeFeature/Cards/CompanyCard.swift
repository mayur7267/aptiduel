import DesignSystem
import Domain
import SwiftUI

struct CompanyCard: View {
    let onPick: (Company) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Practise for a company").font(.ui(17, .bold)).foregroundStyle(Theme.text)
                Text("A rated duel using only the topics on that company's aptitude test.").font(.ui(14)).foregroundStyle(Theme.muted)
            }
            VStack(spacing: 10) {
                ForEach(COMPANIES) { c in
                    Button { onPick(c) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name).font(.ui(15, .bold)).foregroundStyle(Theme.text)
                                Text(c.blurb).font(.ui(12)).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .card(16, fill: Theme.raised)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(22)
        .card(20)
    }
}
