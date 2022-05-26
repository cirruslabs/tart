import ArgumentParser
import Dispatch
import SwiftUI

struct Login: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Login to a registry")

  @Argument(help: "host")
  var host: String

  func run() async throws {
    do {
      let (user, password) = try StdinCredentials.retrieve()
      let credentialsProvider = DictionaryCredentialsProvider([
        host: (user, password)
      ])

      do {
        let registry = try Registry(host: host, namespace: "", credentialsProvider: credentialsProvider)
        try await registry.ping()
      } catch {
        print("invalid credentials: \(error)")

        Foundation.exit(1)
      }

      try KeychainCredentialsProvider().store(host: host, user: user, password: password)

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}

fileprivate class DictionaryCredentialsProvider: CredentialsProvider {
  var credentials: Dictionary<String, (String, String)>

  init(_ credentials: Dictionary<String, (String, String)>) {
    self.credentials = credentials
  }

  func retrieve(host: String) throws -> (String, String)? {
    credentials[host]
  }

  func store(host: String, user: String, password: String) throws {
    credentials[host] = (user, password)
  }
}
