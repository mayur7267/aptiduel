import Domain
import SwiftUI

// Your college. Until you type it lists the colleges people play for;
// two letters or more search about 34,000 colleges in 224 countries
// (0027_world_colleges.sql), and a missing one can be added.
public struct CollegePicker: View {
    let colleges: [College]
    @Binding var selected: Int?
    let search: @MainActor (String) async throws -> [College]
    let add: @MainActor (String, String?, String) async throws -> College
    let picked: @MainActor (College) -> Void

    @State private var query = ""
    @State private var results: (query: String, list: [College])?
    @State private var searchError: String?
    @State private var adding = false
    @Environment(\.dismiss) private var dismiss

    public init(
        colleges: [College],
        selected: Binding<Int?>,
        search: @escaping @MainActor (String) async throws -> [College],
        add: @escaping @MainActor (String, String?, String) async throws -> College,
        picked: @escaping @MainActor (College) -> Void
    ) {
        self.colleges = colleges
        _selected = selected
        self.search = search
        self.add = add
        self.picked = picked
    }

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }
    private var searching: Bool { trimmed.count >= 2 }

    public var body: some View {
        let shown = searching ? (results?.list ?? []) : colleges
        NavigationStack {
            List {
                if !searching {
                    Button("No college") {
                        selected = nil
                        dismiss()
                    }
                    .foregroundStyle(Theme.muted)
                }
                ForEach(shown) { c in
                    Button { choose(c) } label: { row(c) }
                }
                if searching {
                    if results == nil && searchError == nil {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Searching…").foregroundStyle(Theme.muted)
                        }
                    }
                    if let searchError { Text(searchError).foregroundStyle(Theme.orange) }
                    if let results, results.list.isEmpty {
                        Text("No college matches “\(trimmed)” yet.").foregroundStyle(Theme.muted)
                    }
                    Button { adding = true } label: {
                        Label("Can't find it? Add your college", systemImage: "plus")
                            .font(.ui(15, .semibold))
                            .foregroundStyle(Theme.lime)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ink)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search colleges in any country")
            .autocorrectionDisabled()
            .task(id: trimmed) { await runSearch(trimmed) }
            .navigationTitle("Your college")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $adding) {
                AddCollegeForm(name: trimmed, add: add) { college in
                    adding = false
                    choose(college, after: .milliseconds(350))
                }
                .presentationDetents([.large])
                .preferredColorScheme(.dark)
            }
        }
    }

    private func row(_ c: College) -> some View {
        HStack(spacing: 12) {
            Text(c.flag).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name).foregroundStyle(Theme.text).lineLimit(2)
                if !c.place.isEmpty {
                    Text(c.place).font(.ui(12)).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let n = c.players, n > 0 {
                Text("\(n) \(n == 1 ? "player" : "players")")
                    .font(.mono(11))
                    .foregroundStyle(Theme.lime)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.limeTint, in: Capsule())
            }
            if c.id == selected { Image(systemName: "checkmark").foregroundStyle(Theme.lime) }
        }
    }

    private func runSearch(_ q: String) async {
        guard q.count >= 2 else { return }
        // Waits for a pause in typing; a new keystroke cancels this one.
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        do {
            let list = try await search(q)
            guard !Task.isCancelled else { return }
            results = (q, list)
            searchError = nil
        } catch is CancellationError {
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            searchError = error.localizedDescription
        }
    }

    private func choose(_ c: College, after delay: Duration = .zero) {
        selected = c.id
        picked(c)
        Task {
            if delay > .zero { try? await Task.sleep(for: delay) }
            dismiss()
        }
    }
}

// A college that isn't on the list: its name, city and country.
private struct AddCollegeForm: View {
    @State var name: String
    let add: @MainActor (String, String?, String) async throws -> College
    let done: @MainActor (College) -> Void

    @State private var city = ""
    @State private var country = Locale.current.region?.identifier ?? "IN"
    @State private var saving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    // Every country, by name in the phone's language.
    private static let countries: [(code: String, name: String)] = Locale.Region.isoRegions
        .map(\.identifier)
        .filter { $0.count == 2 && $0.allSatisfy(\.isLetter) }
        .compactMap { code in Locale.current.localizedString(forRegionCode: code).map { (code, $0) } }
        .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

    private var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("College name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("City (optional)", text: $city)
                        .textInputAutocapitalization(.words)
                }
                Section {
                    Picker("Country", selection: $country) {
                        ForEach(Self.countries, id: \.code) { c in
                            Text("\(College.flag(c.code) ?? "") \(c.name)").tag(c.code)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                if let error {
                    Section { Text(error).foregroundStyle(Theme.orange) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ink)
            .autocorrectionDisabled()
            .navigationTitle("Add your college")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Adding…" : "Add") { Task { await save() } }
                        .disabled(saving || cleanName.count < 3)
                }
            }
        }
    }

    private func save() async {
        saving = true
        error = nil
        let place = city.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            done(try await add(cleanName, place.isEmpty ? nil : place, country))
        } catch {
            self.error = error.localizedDescription
        }
        saving = false
    }
}
