import Foundation
import Security

protocol LastFMSessionStoring {
    func load() -> LastFMSession?
    func save(_ session: LastFMSession)
    func clear()
}

struct KeychainLastFMSessionStore: LastFMSessionStoring {
    private let keychain: KeychainStringStore
    private let sessionKeyAccount = "lastfm.session.key"
    private let usernameAccount = "lastfm.session.username"

    init(service: String = Bundle.main.bundleIdentifier ?? "MusicStoryRenderer") {
        self.keychain = KeychainStringStore(service: service)
    }

    func load() -> LastFMSession? {
        guard let key = keychain.read(account: sessionKeyAccount),
              let username = keychain.read(account: usernameAccount)
        else {
            return nil
        }
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedKey.isEmpty == false, trimmedUsername.isEmpty == false else {
            return nil
        }
        return LastFMSession(username: trimmedUsername, key: trimmedKey)
    }

    func save(_ session: LastFMSession) {
        keychain.save(session.key, account: sessionKeyAccount)
        keychain.save(session.username, account: usernameAccount)
    }

    func clear() {
        keychain.delete(account: sessionKeyAccount)
        keychain.delete(account: usernameAccount)
    }
}

struct KeychainStringStore {
    let service: String

    func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return value
    }

    func save(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else {
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        if status == errSecDuplicateItem {
            SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        }
    }

    func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
