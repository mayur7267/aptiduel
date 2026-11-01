import SwiftUI

@main
struct ApticksApp: App {
    @State private var container = AppContainer.make()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .preferredColorScheme(.dark)
                .tint(.accentColor)
        }
    }
}
