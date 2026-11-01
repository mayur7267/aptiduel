import Foundation

// Whether the launch splash is still on screen, so animations underneath
// (the intro's first scene, Tiko's first words) wait for it.
@MainActor
@Observable
public final class LaunchState {
    public private(set) var splashing = true

    public init() {}

    public func splashFinished() { splashing = false }
}
