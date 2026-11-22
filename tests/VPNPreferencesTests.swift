import Foundation
import NetworkExtension
import EasyTierShared

// Exercise delayed callbacks without creating a real system VPN configuration.
// NEVPNManager must be accessed via shared(); its base init asserts at runtime.
// Tunnel-provider managers support init(), as used by the app's install path.
private final class StubVPNManager: NETunnelProviderManager {
    var failure: NSError?
    var saves = 0
    var removals = 0
    var reloads = 0

    override func loadFromPreferences(completionHandler: @escaping @Sendable (Error?) -> Void) {
        reloads += 1
        let error = failure
        DispatchQueue.main.async { completionHandler(error) }
    }

    override func saveToPreferences(completionHandler: (@Sendable (Error?) -> Void)?) {
        saves += 1
        let error = failure
        DispatchQueue.main.async { completionHandler?(error) }
    }

    override func removeFromPreferences(completionHandler: (@Sendable (Error?) -> Void)?) {
        removals += 1
        let error = failure
        DispatchQueue.main.async { completionHandler?(error) }
    }
}

@main
struct VPNPreferencesTests {
    @MainActor
    static func main() async throws {
        let manager = StubVPNManager()
        try await saveVPNPreferences(manager)
        try await removeVPNPreferences(manager)
        try await reloadVPNPreferences(manager)
        precondition(manager.saves == 1 && manager.removals == 1)
        precondition(manager.reloads == 1)

        manager.failure = NSError(domain: "VPNPreferencesTests", code: 42)
        for operation in [saveVPNPreferences, removeVPNPreferences, reloadVPNPreferences] {
            do {
                try await operation(manager)
                fatalError("Expected the callback error to be propagated")
            } catch {
                let nsError = error as NSError
                precondition(nsError.domain == "VPNPreferencesTests" && nsError.code == 42)
            }
        }
        precondition(manager.saves == 2 && manager.removals == 2)
        precondition(manager.reloads == 2)
        print("VPN preference delayed callback success/error tests passed")
    }
}
