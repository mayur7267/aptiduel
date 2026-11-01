import UIKit

extension Notification.Name {
    static let deviceDidShake = Notification.Name("ApticksDeviceDidShake")
}

// Turns a shake of the phone into a notification the app can act on
// (it opens "Report a problem").
extension UIWindow {
    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake { NotificationCenter.default.post(name: .deviceDidShake, object: nil) }
    }
}
