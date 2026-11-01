import Foundation

// Waiting, injectable so tests can skip it. View models store a
// `(Duration) async -> Void` and default it to Wait.real.
public enum Wait {
    // Typed exactly like those stored functions (nonisolated(nonsending)),
    // so awaiting it resumes on the caller's actor. A closure literal as a
    // default argument gets converted instead, and can resume the caller on
    // a background thread.
    public nonisolated(nonsending) static func real(_ duration: Duration) async {
        try? await Task.sleep(for: duration)
    }
}
