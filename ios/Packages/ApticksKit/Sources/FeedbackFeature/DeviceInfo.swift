import Foundation
import UIKit

// The app version and device, sent with feedback.
public enum DeviceInfo {
    public static var current: [String: String] {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return [
            "app": "\(version) (\(build))",
            "os": "iOS \(UIDevice.current.systemVersion)",
            "device": model,
        ]
    }

    // "iPhone17,1" and the like (the simulator reports its own).
    private static var model: String {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return "\(sim) (simulator)" }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
