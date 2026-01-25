import Foundation
import Security

/// Ein Service zum Speichern, Abrufen und Löschen sensibler Daten im iOS Keychain
public struct KeychainHelper {
    public static let standard = KeychainHelper()
    private init() {}

    /// Speichert einen String unter einem Service/Account im Keychain
    /// Verwendet sichere Zugriffskontrollen für maximalen Schutz
    public func save(_ value: String, service: String, account: String) throws {
        let data = Data(value.utf8)

        // Sichere Keychain-Konfiguration:
        // - kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly: Nur zugänglich wenn Gerät entsperrt
        //   und Passcode gesetzt ist. Wird NICHT in Backups übertragen.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        ]

        // Vorherigen Eintrag löschen (falls vorhanden)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Neuen Eintrag hinzufügen
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    /// Liest einen String aus dem Keychain
    public func read(service: String, account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
        guard let data = result as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }

    /// Löscht den Eintrag aus dem Keychain
    public func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
}

/// Fehler, die beim Keychain-Zugriff auftreten können
public enum KeychainError: Error {
    case unhandledError(status: OSStatus)
    case invalidData
} 