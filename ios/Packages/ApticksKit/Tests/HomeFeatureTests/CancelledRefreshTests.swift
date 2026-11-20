import AppCore
import Domain
import Foundation
import Networking
import NetworkingFakes
import Testing
@testable import HomeFeature

// The first pull-to-refresh after every launch showed "The operation
// couldn't be completed. (Swift.CancellationError error 1.)": SwiftUI
// cancelled the refresh and home reported it as a failure.
@MainActor
struct CancelledRefreshTests {
    @Test func aCancelledRefreshKeepsHomeAsItWas() async throws {
        let home = HomeViewModel(api: FakeBackend(latency: .milliseconds(200)), router: AppRouter())
        await home.load()
        #expect(home.me != nil && home.error == nil)

        let refresh = Task { await home.load() }
        try await Task.sleep(for: .milliseconds(20))
        refresh.cancel()
        await refresh.value
        #expect(home.error == nil)
        #expect(home.me != nil)
    }

    @Test func realFailuresStillShow() async {
        let backend = FakeBackend(latency: .zero)
        backend.offline = true
        let home = HomeViewModel(api: backend, router: AppRouter())
        await home.load()
        #expect(home.error?.contains("offline") == true)
    }

    // The live backend runs every failure through friendlyError. It used to
    // wrap a cancellation in an AppError, which hid it from the check below.
    @Test func theLiveBackendLetsCancellationsThrough() {
        #expect(friendlyError(CancellationError()).isCancellation)
        #expect(friendlyError(URLError(.cancelled)).isCancellation)
        #expect(friendlyError(URLError(.notConnectedToInternet)) as? AppError == AppError("You're offline. Check your connection and try again."))
        #expect(friendlyError(URLError(.timedOut)) as? AppError == AppError("Couldn't reach Apticks. Try again in a moment."))
        #expect(!friendlyError(URLError(.badServerResponse)).isCancellation)
    }

    @Test func whatCountsAsCancelled() {
        #expect(CancellationError().isCancellation)
        #expect(URLError(.cancelled).isCancellation)
        #expect(!URLError(.notConnectedToInternet).isCancellation)
        #expect(!AppError("Names are 2 to 24 characters.").isCancellation)
    }
}
