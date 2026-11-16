import Foundation
import NetworkExtension
import EasyTierShared

// Exercise delayed callbacks without creating a real system VPN configuration.
private final class StubVPNManager: NEVPNManager {
    var failure: NSError?
    var saves = 0
    var removals = 0

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
        precondition(manager.saves == 1 && manager.removals == 1)

        manager.failure = NSError(domain: "VPNPreferencesTests", code: 42)
        for operation in [saveVPNPreferences, removeVPNPreferences] {
            do {
                try await operation(manager)
                fatalError("Expected the callback error to be propagated")
            } catch {
                let nsError = error as NSError
                precondition(nsError.domain == "VPNPreferencesTests" && nsError.code == 42)
            }
        }
        precondition(manager.saves == 2 && manager.removals == 2)
        print("VPN preference delayed callback success/error tests passed")
    }
}
