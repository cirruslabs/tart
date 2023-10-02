import Foundation

enum StdinCredentialsError: Error {
  case CredentialRequired(which: String)
  case CredentialTooLong(message: String)
}

class StdinCredentials {
  static func retrieve() throws -> (String, String) {
    let user = try readStdinCredential(name: "username", prompt: "User: ", isSensitive: false)
    let password = try readStdinCredential(name: "password", prompt: "Password: ", isSensitive: true)

    return (user, password)
  }

  private static func readStdinCredential(name: String, prompt: String, maxCharacters: Int = 1024, isSensitive: Bool) throws -> String {
    var buf = [CChar](repeating: 0, count: maxCharacters + 1 /* sentinel */ + 1 /* NUL */)
    guard let rawCredential = readpassphrase(prompt, &buf, buf.count, isSensitive ? RPP_ECHO_OFF : RPP_ECHO_ON) else {
      throw StdinCredentialsError.CredentialRequired(which: name)
    }

    let credential = String(cString: rawCredential).trimmingCharacters(in: .newlines)

    if credential.count > maxCharacters {
      throw StdinCredentialsError.CredentialTooLong(
        message: "\(name) should contain no more than \(maxCharacters) characters")
    }

    return credential
  }
}
