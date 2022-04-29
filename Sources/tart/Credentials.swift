import Foundation

class Credentials {
  static func retrieve(host: String) throws -> (String, String) {
    do {
      return try retrieveKeychain(host: host)
    } catch {
      return try retrieveStdin()
    }
  }

  static func retrieveKeychain(host: String) throws -> (String, String) {
    let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                kSecAttrProtocol as String: kSecAttrProtocolHTTPS,
                                kSecAttrServer as String: host,
                                kSecMatchLimit as String: kSecMatchLimitOne,
                                kSecReturnAttributes as String: true,
                                kSecReturnData as String: true,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    if status != errSecSuccess {
      if status == errSecItemNotFound {
        throw RegistryError.AuthFailed
      }

      throw RegistryError.AuthFailed
    }

    guard let item = item as? [String: Any],
          let user = item[kSecAttrAccount as String] as? String,
          let passwordData = item[kSecValueData as String] as? Data,
          let password = String(data: passwordData, encoding: .utf8)
      else {
      throw RegistryError.AuthFailed
    }

    return (user, password)
  }

  static func retrieveStdin() throws -> (String, String) {
    print("User: ", terminator: "")
    let user = readLine() ?? ""

    let rawPass = getpass("Password: ")
    let pass = String(cString: rawPass!, encoding: .utf8)!

    return (user, pass)
  }

  static func store(host: String, user: String, password: String) throws {
    let attributes: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                     kSecAttrAccount as String: user,
                                     kSecAttrProtocol as String: kSecAttrProtocolHTTPS,
                                     kSecAttrServer as String: host,
                                     kSecValueData as String: password,
                                     kSecAttrLabel as String: "Tart Credentials",
    ]

    switch SecItemAdd(attributes as CFDictionary, nil) {
    case errSecSuccess, errSecDuplicateItem:
      return
    default:
      throw RegistryError.AuthFailed
    }
  }
}
