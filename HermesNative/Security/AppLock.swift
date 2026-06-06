import SwiftUI
import LocalAuthentication

/// Optional biometric (Face ID / Touch ID) gate on app launch (PRD §21).
/// Works under free-Apple-ID sideloading — no special entitlement required.
@MainActor
@Observable
final class AppLock {
    private let defaults: UserDefaults
    var enabled: Bool { didSet { defaults.set(enabled, forKey: "applock.enabled") } }
    var unlocked: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let on = defaults.bool(forKey: "applock.enabled")
        self.enabled = on
        self.unlocked = !on   // if lock disabled, start unlocked
    }

    var biometryAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Called when entering background to require re-auth next foreground.
    func lock() { if enabled { unlocked = false } }

    func authenticate() async {
        guard enabled, !unlocked else { return }
        let context = LAContext()
        context.localizedFallbackTitle = "Enter Passcode"
        let ok = (try? await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock Hermes")) ?? false
        unlocked = ok
    }
}
