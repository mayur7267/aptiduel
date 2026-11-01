import Domain
import SwiftUI

// A searchable list of colleges.
public struct CollegePicker: View {
    let colleges: [College]
    @Binding var selected: Int?
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    public init(colleges: [College], selected: Binding<Int?>) {
        self.colleges = colleges
        _selected = selected
    }

    public var body: some View {
        let shown = query.isEmpty ? colleges : colleges.filter { $0.name.localizedCaseInsensitiveContains(query) }
        NavigationStack {
            List {
                Button("No college") {
                    selected = nil
                    dismiss()
                }
                .foregroundStyle(Theme.muted)
                ForEach(shown) { c in
                    Button {
                        selected = c.id
                        dismiss()
                    } label: {
                        HStack {
                            Text(c.name).foregroundStyle(Theme.text)
                            Spacer()
                            if c.id == selected { Image(systemName: "checkmark").foregroundStyle(Theme.lime) }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ink)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search colleges")
            .navigationTitle("Your college")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}
