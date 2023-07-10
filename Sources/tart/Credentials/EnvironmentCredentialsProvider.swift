import Foundation

class EnvironmentCredentialsProvider: CredentialsProvider {
  func retrieve(host: String) throws -> (String, String)? {
    if let tartRegistryHost = ProcessInfo.processInfo.environment["TART_REGISTRY_HOST"],
       tartRegistryHost != host {
      return nil
    }

    let username = ProcessInfo.processInfo.environment["TART_REGISTRY_USERNAME"]
    let password = ProcessInfo.processInfo.environment["TART_REGISTRY_PASSWORD"]
    if let username = username, let password = password {
      return (username, password)
    }
    return nil
  }

  func store(host: String, user: String, password: String) throws {
  }
}
