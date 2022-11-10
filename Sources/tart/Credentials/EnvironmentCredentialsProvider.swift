import Foundation

class EnvironmentCredentialsProvider: CredentialsProvider {
  func retrieve(host: String) throws -> (String, String)? {
    let username = ProcessInfo.processInfo.environment["TART_REGISTRY_USERNAME"]
    let password = ProcessInfo.processInfo.environment["TART_REGISTRY_PASSWORD"]
    if username != nil && password != nil {
      return (username!, password!)
    }
    return nil
  }

  func store(host: String, user: String, password: String) throws {
  }
}
