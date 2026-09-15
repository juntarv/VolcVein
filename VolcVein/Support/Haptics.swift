import UIKit

/// Launch-argument switches. Both are read once at startup.
enum LaunchFlags {
    static let demoMode = ProcessInfo.processInfo.arguments.contains("-demoMode")
    static let screenshotTour = ProcessInfo.processInfo.arguments.contains("-screenshotTour")
    /// The tour reuses the deterministic demo script.
    static var deterministic: Bool { demoMode || screenshotTour }
    static let demoSeed: UInt64 = 20_260_914
    static let demoVent = 7
}

/// Every knock in the game comes through here, gated on the stored preference.
enum Haptics {
    static var enabled: Bool = true

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notice = UINotificationFeedbackGenerator()

    static func prime() {
        guard enabled else { return }
        light.prepare(); medium.prepare(); heavy.prepare()
    }

    static func tap() {
        guard enabled else { return }
        light.impactOccurred()
    }

    static func knock() {
        guard enabled else { return }
        medium.impactOccurred()
    }

    static func blow() {
        guard enabled else { return }
        heavy.impactOccurred()
    }

    static func success() {
        guard enabled else { return }
        notice.notificationOccurred(.success)
    }

    static func warn() {
        guard enabled else { return }
        notice.notificationOccurred(.warning)
    }
}
