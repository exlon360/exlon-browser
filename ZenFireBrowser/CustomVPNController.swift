import Foundation
import NetworkExtension
import Security

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
        if let passwordReference = try passwordReference(for: profile) {
            tunnel.passwordReference = passwordReference
            tunnel.useExtendedAuthentication = true
        } else {
            tunnel.useExtendedAuthentication = profile.username.isEmpty == false
        }
        tunnel.authenticationMethod = .none
        tunnel.disconnectOnSleep = false

        manager.localizedDescription = "Glide \(profile.countryName)"
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

    private static func passwordReference(for profile: CustomVPNProfile) throws -> Data? {
        let password = profile.password?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard password.isEmpty == false else { return nil }

        let account = [profile.countryName, profile.serverAddress, profile.username]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: "|")
        let data = Data(password.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.exlon360.glide.vpn",
            kSecAttrAccount as String: account
        ]

        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        addQuery[kSecReturnPersistentRef as String] = true

        var result: CFTypeRef?
        let status = SecItemAdd(addQuery as CFDictionary, &result)
        guard status == errSecSuccess else {
            throw NSError(
                domain: "GlideVPNKeychain",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Could not save VPN password in Keychain."]
            )
        }
        return result as? Data
    }
}

private extension CustomVPNProfile {
    func trimmed() -> CustomVPNProfile {
        CustomVPNProfile(
            countryName: countryName.trimmingCharacters(in: .whitespacesAndNewlines),
            serverAddress: serverAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            remoteIdentifier: remoteIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password?.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: isEnabled
        )
    }
}
