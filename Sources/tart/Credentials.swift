import Foundation

enum CredentialsError: Error {
  case CredentialRequired(which: String)
  case CredentialTooLong(message: String)
}

class Credentials {
  static func retrieveKeychain(host: String) throws -> (String, String)? {
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

      throw RegistryError.AuthFailed(why: "Keychain returned unsuccessful status \(status)")
    }

    guard let item = item as? [String: Any],
          let user = item[kSecAttrAccount as String] as? String,
          let passwordData = item[kSecValueData as String] as? Data,
          let password = String(data: passwordData, encoding: .utf8)
      else {
      throw RegistryError.AuthFailed(why: "Keychain item has unexpected format")
    }

    return (user, password)
  }

  static func retrieveStdin() throws -> (String, String) {
    let user = try readStdinCredential(name: "username", prompt: "User: ", isSensitive: false)
    let password = try readStdinCredential(name: "password", prompt: "Password: ", isSensitive: true)

    return (user, password)
  }

  private static func readStdinCredential(name: String, prompt: String, maxCharacters: Int = 2, isSensitive: Bool) throws -> String {
    var buf = [CChar](repeating: 0, count: maxCharacters + 1 /* sentinel */ + 1 /* NUL */)
    guard let rawCredential = readpassphrase(prompt, &buf, buf.count, isSensitive ? RPP_ECHO_OFF : RPP_ECHO_ON) else {
      throw CredentialsError.CredentialRequired(which: name)
    }

    let user = String(cString: rawCredential).trimmingCharacters(in: .newlines)

    if user.count > maxCharacters {
      throw CredentialsError.CredentialTooLong(
        message: "\(name) should contain no more than \(maxCharacters) characters")
    }

    return user
  }

  static func store(host: String, user: String, password: String) throws {
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
      throw RegistryError.AuthFailed(why: "Keychain returned unsuccessful status \(status)")
    }
  }
}
