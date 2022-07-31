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
        let passwordData = password.data(using: .utf8)
        let key: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                  kSecAttrProtocol as String: kSecAttrProtocolHTTPS,
                                  kSecAttrServer as String: host,
                                  kSecAttrLabel as String: "Tart Credentials",
        ]
        let value: [String: Any] = [kSecAttrAccount as String: user,
                                    kSecValueData as String: passwordData,
        ]

        let status = SecItemCopyMatching(key as CFDictionary, nil)

        switch status {
        case errSecItemNotFound:
            let status = SecItemAdd(key.merging(value) { (current, _) in current } as CFDictionary, nil)
            if status != errSecSuccess {
              throw CredentialsProviderError.Failed(message: "Keychain failed to add item: \(status.explanation())")
            }
        case errSecSuccess:
            let status = SecItemUpdate(key as CFDictionary, value as CFDictionary)
            if status != errSecSuccess {
              throw CredentialsProviderError.Failed(message: "Keychain failed to update item: \(status.explanation())")
            }
        default:
            throw CredentialsProviderError.Failed(message: "Keychain failed to find item: \(status.explanation())")
        }
    }
}

extension OSStatus {
  func explanation() -> CFString {
    SecCopyErrorMessageString(self, nil) ?? "Unknown status code \(self)." as CFString
  }
}
