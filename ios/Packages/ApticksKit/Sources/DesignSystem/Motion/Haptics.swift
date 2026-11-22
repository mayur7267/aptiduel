import CoreHaptics
import UIKit

// Hand-made haptics for the big moments (Core Haptics), with plain
// feedback generators on phones without a Taptic Engine pattern player.
// A thud is a hard hit with a short low rumble after it, like a block
// landing; a fanfare climbs; a rumble shakes and fades, like a tower
// falling.
@MainActor
public final class Haptics {
    public static let shared = Haptics()

    private var engine: CHHapticEngine?

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in
            Task { @MainActor in try? self?.engine?.start() }
        }
    }

    private func hit(_ time: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time)
    }

    private func hum(_ time: TimeInterval, _ duration: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time, duration: duration)
    }

    private func play(_ events: [CHHapticEvent], curves: [CHHapticParameterCurve] = [], fallback: () -> Void) {
        guard let engine else { return fallback() }
        do {
            try engine.start()
            let player = try engine.makePlayer(with: try CHHapticPattern(events: events, parameterCurves: curves))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback()
        }
    }

    // A block landing: a heavy, dull hit, then a low rumble that dies away.
    public func thud() {
        let fade = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 0.9), .init(relativeTime: 0.22, value: 0.25), .init(relativeTime: 0.4, value: 0),
        ], relativeTime: 0.02)
        play([hit(0, 1, 0.25), hum(0.02, 0.4, 0.75, 0.1)], curves: [fade]) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    // A light, crisp tap: the number rolling, a floor lighting up.
    public func tick(_ intensity: Float = 0.5) {
        play([hit(0, intensity, 0.8)]) { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: CGFloat(intensity)) }
    }

    // A sticker slamming down: hard and sharp, with a tiny bounce.
    public func slam() {
        play([hit(0, 1, 0.9), hit(0.07, 0.45, 0.6)]) { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    }

    // A badge: taps that climb, then a long bright buzz.
    public func fanfare() {
        let taps = (0..<5).map { i in hit(Double(i) * 0.075, 0.45 + Float(i) * 0.12, 0.5 + Float(i) * 0.1) }
        play(taps + [hum(0.4, 0.35, 0.8, 0.7)]) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // A tower falling: a rattle of knocks over a shake that fades.
    public func rumble() {
        let knocks = (0..<7).map { i in hit(Double(i) * 0.09, 0.9 - Float(i) * 0.1, 0.3) }
        let fade = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 1), .init(relativeTime: 0.7, value: 0),
        ], relativeTime: 0)
        play(knocks + [hum(0, 0.75, 0.6, 0.15)], curves: [fade]) {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}
