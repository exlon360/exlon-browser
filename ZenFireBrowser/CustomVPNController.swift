import Foundation
import NetworkExtension

enum CustomVPNError: LocalizedError {
    case missingConfiguration

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Add a country and server address before saving the VPN profile."
        }
    }
}

enum CustomVPNController {
    static func install(profile: CustomVPNProfile) async throws {
        let profile = profile.trimmed()
        guard profile.isConfigured else {
            throw CustomVPNError.missingConfiguration
        }

        let manager = NEVPNManager.shared()
        try await load(manager)

        let tunnel = NEVPNProtocolIKEv2()
        tunnel.serverAddress = profile.serverAddress
        tunnel.remoteIdentifier = profile.remoteIdentifier.isEmpty ? profile.serverAddress : profile.remoteIdentifier
        tunnel.localIdentifier = profile.username.isEmpty ? nil : profile.username
        tunnel.username = profile.username.isEmpty ? nil : profile.username
        tunnel.useExtendedAuthentication = profile.username.isEmpty == false
        tunnel.authenticationMethod = .none
        tunnel.disconnectOnSleep = false

        manager.localizedDescription = "Exlon Browser \(profile.countryName)"
        manager.protocolConfiguration = tunnel
        manager.isEnabled = profile.isEnabled

        try await save(manager)
    }

    static func setEnabled(_ enabled: Bool) async throws {
        let manager = NEVPNManager.shared()
        try await load(manager)
        manager.isEnabled = enabled
        try await save(manager)
    }

    static func connect() async throws {
        let manager = NEVPNManager.shared()
        try await load(manager)
        try manager.connection.startVPNTunnel()
    }

    static func disconnect() {
        NEVPNManager.shared().connection.stopVPNTunnel()
    }

    private static func load(_ manager: NEVPNManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.loadFromPreferences { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func save(_ manager: NEVPNManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.saveToPreferences { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

private extension CustomVPNProfile {
    func trimmed() -> CustomVPNProfile {
        CustomVPNProfile(
            countryName: countryName.trimmingCharacters(in: .whitespacesAndNewlines),
            serverAddress: serverAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            remoteIdentifier: remoteIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: isEnabled
        )
    }
}
