import CommonCrypto
import CryptoKit
import Foundation
import LocalAuthentication
import Security
import SwiftUI
import WebKit

enum SecureBrowserVaultError: LocalizedError {
    case invalidPIN
    case pinMismatch
    case pinTooShort
    case setupMissing
    case encryptionFailed
    case authenticationFailed
    case keychainUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidPIN:
            return "That PIN did not unlock Glide."
        case .pinMismatch:
            return "The PINs do not match."
        case .pinTooShort:
            return "Use at least 4 digits."
        case .setupMissing:
            return "Set a PIN before unlocking."
        case .encryptionFailed:
            return "The encrypted browser vault could not be opened."
        case .authenticationFailed:
            return "Face ID could not unlock Glide."
        case .keychainUnavailable:
            return "The secure keychain item is unavailable."
        }
    }
}

private struct VaultEnvelope: Codable {
    var version: Int
    var kdf: String
    var iterations: Int
    var salt: Data
    var nonce: Data
    var ciphertext: Data
    var tag: Data
}

private struct VaultVerifier: Codable {
    var marker: String
    var createdAt: Date
}

final class SecureBrowserVault {
    private let key: SymmetricKey
    private let salt: Data
    private let defaults: UserDefaults

    private static let verifierKey = "ZenFireBrowser.secure.pinVerifier"
    private static let saltKey = "ZenFireBrowser.secure.pinSalt"
    private static let storagePrefix = "ZenFireBrowser.secure.value."
    private static let keychainService = "com.exlon360.glide.secure-vault"
    private static let keychainAccount = "pin-derived-aes256-key"
    private static let kdfIterations = 210_000
    private static let keySize = 32

    init(key: SymmetricKey, salt: Data, defaults: UserDefaults = .standard) {
        self.key = key
        self.salt = salt
        self.defaults = defaults
    }

    static func prepareLaunchPrivacy() {
        URLCache.shared = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 0, diskPath: nil)
        purgePersistentWebKitData()
        removeUnencryptedCacheFiles()
    }

    static var isConfigured: Bool {
        let defaults = UserDefaults.standard
        return defaults.data(forKey: verifierKey) != nil && defaults.data(forKey: saltKey) != nil
    }

    static func setup(pin: String, confirmation: String) throws -> SecureBrowserVault {
        let trimmedPIN = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPIN.count >= 4 else { throw SecureBrowserVaultError.pinTooShort }
        guard trimmedPIN == confirmation.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw SecureBrowserVaultError.pinMismatch
        }

        let salt = try randomData(count: 32)
        let keyData = try deriveKeyData(pin: trimmedPIN, salt: salt)
        let key = SymmetricKey(data: keyData)
        let vault = SecureBrowserVault(key: key, salt: salt)
        let verifier = VaultVerifier(marker: "GlideSecureVault", createdAt: Date())

        UserDefaults.standard.set(salt, forKey: saltKey)
        UserDefaults.standard.set(try vault.encrypt(verifier), forKey: verifierKey)
        storeBiometricKeyIfPossible(keyData)
        prepareLaunchPrivacy()
        return vault
    }

    static func unlock(pin: String) throws -> SecureBrowserVault {
        let defaults = UserDefaults.standard
        guard let salt = defaults.data(forKey: saltKey),
              let verifierData = defaults.data(forKey: verifierKey) else {
            throw SecureBrowserVaultError.setupMissing
        }

        let keyData = try deriveKeyData(pin: pin.trimmingCharacters(in: .whitespacesAndNewlines), salt: salt)
        let vault = SecureBrowserVault(key: SymmetricKey(data: keyData), salt: salt)
        let verifier = try vault.decrypt(VaultVerifier.self, from: verifierData)
        guard verifier.marker == "GlideSecureVault" else { throw SecureBrowserVaultError.invalidPIN }

        storeBiometricKeyIfPossible(keyData)
        prepareLaunchPrivacy()
        return vault
    }

    static func unlockWithBiometrics() throws -> SecureBrowserVault {
        let defaults = UserDefaults.standard
        guard let salt = defaults.data(forKey: saltKey),
              let verifierData = defaults.data(forKey: verifierKey) else {
            throw SecureBrowserVaultError.setupMissing
        }

        let keyData = try readBiometricKey()
        let vault = SecureBrowserVault(key: SymmetricKey(data: keyData), salt: salt)
        let verifier = try vault.decrypt(VaultVerifier.self, from: verifierData)
        guard verifier.marker == "GlideSecureVault" else { throw SecureBrowserVaultError.authenticationFailed }

        prepareLaunchPrivacy()
        return vault
    }

    static func biometricStatus() -> (available: Bool, title: String) {
        let context = LAContext()
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        if available {
            switch context.biometryType {
            case .faceID:
                return (true, "Face ID")
            case .touchID:
                return (true, "Touch ID")
            default:
                return (true, "Biometrics")
            }
        }
        return (false, "Face ID unavailable")
    }

    func load<T: Decodable>(_ type: T.Type, forKey key: String, default defaultValue: T) -> T {
        loadOptional(type, forKey: key) ?? defaultValue
    }

    func loadOptional<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        if let encryptedData = defaults.data(forKey: secureKey(for: key)),
           let value = try? decrypt(type, from: encryptedData) {
            return value
        }

        if let legacyData = defaults.data(forKey: key) {
            if let direct = legacyData as? T {
                return direct
            }
            if let value = try? JSONDecoder().decode(type, from: legacyData) {
                return value
            }
        }

        return defaults.object(forKey: key) as? T
    }

    func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let encryptedData = try? encrypt(value) else { return }
        defaults.set(encryptedData, forKey: secureKey(for: key))
        defaults.removeObject(forKey: key)
    }

    func remove(_ key: String) {
        defaults.removeObject(forKey: secureKey(for: key))
        defaults.removeObject(forKey: key)
    }

    func encryptData(_ data: Data) throws -> Data {
        try seal(plaintext: data)
    }

    func decryptData(_ data: Data) throws -> Data {
        try openEnvelope(from: data)
    }

    private func secureKey(for key: String) -> String {
        "\(Self.storagePrefix)\(key)"
    }

    private func encrypt<T: Encodable>(_ value: T) throws -> Data {
        let plaintext = try JSONEncoder().encode(value)
        return try seal(plaintext: plaintext)
    }

    private func decrypt<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let plaintext = try openEnvelope(from: data)
        return try JSONDecoder().decode(type, from: plaintext)
    }

    private func seal(plaintext: Data) throws -> Data {
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(plaintext, using: key, nonce: nonce)
        let envelope = VaultEnvelope(
            version: 1,
            kdf: "PBKDF2-HMAC-SHA256",
            iterations: Self.kdfIterations,
            salt: salt,
            nonce: Data(nonce),
            ciphertext: sealedBox.ciphertext,
            tag: sealedBox.tag
        )
        return try JSONEncoder().encode(envelope)
    }

    private func openEnvelope(from data: Data) throws -> Data {
        let envelope = try JSONDecoder().decode(VaultEnvelope.self, from: data)
        let nonce = try AES.GCM.Nonce(data: envelope.nonce)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: envelope.ciphertext,
            tag: envelope.tag
        )
        return try AES.GCM.open(sealedBox, using: key)
    }

    private static func deriveKeyData(pin: String, salt: Data) throws -> Data {
        let passwordBytes = [Int8](pin.utf8.map { Int8(bitPattern: $0) })
        var derived = Data(count: keySize)

        let status = derived.withUnsafeMutableBytes { derivedBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordBytes.withUnsafeBufferPointer { passwordBuffer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBuffer.baseAddress,
                        passwordBytes.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(kdfIterations),
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                        keySize
                    )
                }
            }
        }

        guard status == kCCSuccess else { throw SecureBrowserVaultError.encryptionFailed }
        return derived
    }

    private static func randomData(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else { throw SecureBrowserVaultError.encryptionFailed }
        return Data(bytes)
    }

    private static func storeBiometricKey(_ keyData: Data) throws {
        var query = keychainBaseQuery()
        SecItemDelete(query as CFDictionary)

        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else {
            throw SecureBrowserVaultError.keychainUnavailable
        }

        query[kSecValueData as String] = keyData
        query[kSecAttrAccessControl as String] = accessControl

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw SecureBrowserVaultError.keychainUnavailable }
    }

    private static func storeBiometricKeyIfPossible(_ keyData: Data) {
        let status = biometricStatus()
        guard status.available else { return }
        try? storeBiometricKey(keyData)
    }

    private static func readBiometricKey() throws -> Data {
        let context = LAContext()
        context.localizedReason = "Unlock Glide's encrypted browser vault."

        var query = keychainBaseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw SecureBrowserVaultError.authenticationFailed
        }

        return data
    }

    private static func keychainBaseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
    }

    private static func purgePersistentWebKitData() {
        let store = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: dataTypes) { records in
            store.removeData(ofTypes: dataTypes, for: records) {}
        }
    }

    private static func removeUnencryptedCacheFiles() {
        let fileManager = FileManager.default
        let roots = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)

        for root in roots {
            guard let children = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
                continue
            }
            for child in children {
                try? fileManager.removeItem(at: child)
            }
        }

        guard let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return
        }

        for relativePath in ["WebKit", "Cookies"] {
            try? fileManager.removeItem(at: libraryURL.appendingPathComponent(relativePath, isDirectory: true))
        }
    }
}

@MainActor
final class AppSecurityModel: ObservableObject {
    @Published var vault: SecureBrowserVault?
    @Published var message = ""
    @Published var biometricTitle = "Face ID"
    @Published var isBiometricAvailable = false
    @Published var crashLogs: [AppCrashLogEntry] = []
    @Published var isCrashLogsPresented = false
    private var didAutoPresentCrashLogs = false

    var isConfigured: Bool {
        SecureBrowserVault.isConfigured
    }

    var isUnlocked: Bool {
        vault != nil
    }

    init() {
        SecureBrowserVault.prepareLaunchPrivacy()
        refreshBiometricAvailability()
        refreshCrashLogs()
    }

    func refreshBiometricAvailability() {
        let status = SecureBrowserVault.biometricStatus()
        isBiometricAvailable = status.available
        biometricTitle = status.title
    }

    func setup(pin: String, confirmation: String) {
        do {
            vault = try SecureBrowserVault.setup(pin: pin, confirmation: confirmation)
            message = ""
        } catch {
            message = error.localizedDescription
        }
        refreshBiometricAvailability()
    }

    func unlock(pin: String) {
        do {
            vault = try SecureBrowserVault.unlock(pin: pin)
            message = ""
        } catch {
            message = error.localizedDescription
        }
        refreshBiometricAvailability()
    }

    func unlockWithBiometrics() {
        do {
            vault = try SecureBrowserVault.unlockWithBiometrics()
            message = ""
        } catch {
            message = error.localizedDescription
        }
        refreshBiometricAvailability()
    }

    func lock() {
        vault = nil
        message = "Locked."
    }

    var hasUnreadCrashLogs: Bool {
        crashLogs.contains { $0.isUnread }
    }

    func refreshCrashLogs() {
        crashLogs = AppCrashReporter.shared.logs()
    }

    func presentCrashLogsIfNeeded() {
        refreshCrashLogs()
        guard didAutoPresentCrashLogs == false, hasUnreadCrashLogs else { return }
        didAutoPresentCrashLogs = true
        isCrashLogsPresented = true
    }

    func markCrashLogsSeen() {
        AppCrashReporter.shared.markAllSeen()
        refreshCrashLogs()
    }

    func clearCrashLogs() {
        AppCrashReporter.shared.clearLogs()
        refreshCrashLogs()
    }
}
