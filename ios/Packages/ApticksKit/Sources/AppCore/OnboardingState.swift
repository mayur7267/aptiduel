import Foundation

// The first-launch intro. Shown until it's finished once; Profile can
// bring it back.
@MainActor
@Observable
public final class OnboardingState {
    private static let doneKey = "apticks-onboarding-done"

    public private(set) var showing: Bool

    public init() {
        showing = !UserDefaults.standard.bool(forKey: Self.doneKey)
    }

    public func finish() {
        UserDefaults.standard.set(true, forKey: Self.doneKey)
        showing = false
    }

    public func replay() { showing = true }
}
