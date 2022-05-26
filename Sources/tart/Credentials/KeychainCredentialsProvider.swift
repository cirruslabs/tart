import Foundation

class KeychainCredentialsProvider: CredentialsProvider {
    func retrieve(host: String) throws -> (String, String)? {
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrProtocol as String: kSecAttrProtocolHTTPS,
                                    kSecAttrServer as String: host,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecReturnData as String: true,
                                    kSecAttrLabel as String: "Tart Credentials",
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status != errSecSuccess {
            if status == errSecItemNotFound {
                return nil
            }

            throw CredentialsProviderError.Failed(message: "Keychain returned unsuccessful status \(status)")
        }

        guard let item = item as? [String: Any],
              let user = item[kSecAttrAccount as String] as? String,
              let passwordData = item[kSecValueData as String] as? Data,
              let password = String(data: passwordData, encoding: .utf8)
        else {
            throw CredentialsProviderError.Failed(message: "Keychain item has unexpected format")
        }

        return (user, password)
    }

    func store(host: String, user: String, password: String) throws {
        let attributes: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                         kSecAttrAccount as String: user,
                                         kSecAttrProtocol as String: kSecAttrProtocolHTTPS,
                                         kSecAttrServer as String: host,
                                         kSecValueData as String: password,
                                         kSecAttrLabel as String: "Tart Credentials",
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)

        switch status {
        case errSecSuccess, errSecDuplicateItem:
            return
        default:
            throw CredentialsProviderError.Failed(message: "Keychain returned unsuccessful status \(status)")
        }
    }
}
