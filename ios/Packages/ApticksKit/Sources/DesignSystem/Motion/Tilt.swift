import CoreMotion
import Foundation
import Observation

// Device tilt, smoothed: x and y in about -1...1.
@MainActor
@Observable
public final class Tilt {
    public private(set) var x = 0.0
    public private(set) var y = 0.0
    private let motion = CMMotionManager()

    public init() {}

    public func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let g = data?.gravity else { return }
            let gx = g.x, gy = g.y
            MainActor.assumeIsolated {
                guard let self else { return }
                // Low-pass the gravity vector so the scene drifts, never jitters.
                self.x += (max(-1, min(1, gx * 1.6)) - self.x) * 0.12
                self.y += (max(-1, min(1, (gy + 0.6) * 1.6)) - self.y) * 0.12
            }
        }
    }

    public func stop() { motion.stopDeviceMotionUpdates() }
}
