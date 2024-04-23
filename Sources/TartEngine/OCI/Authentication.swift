import Foundation

package protocol Authentication {
  func header() -> (String, String)
  func isValid() -> Bool
}

struct BasicAuthentication: Authentication {
  let user: String
  let password: String

  func header() -> (String, String) {
    let creds = Data("\(user):\(password)".utf8).base64EncodedString()

    return ("Authorization", "Basic \(creds)")
  }

  func isValid() -> Bool {
    true
  }
}
