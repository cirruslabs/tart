import ArgumentParser
import Dispatch
import SwiftUI

struct Login: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Login to a registry")

  @Argument(help: "host")
  var host: String

  @Option(help: "username")
  var username: String?

  @Flag(help: "password-stdin")
  var passwordStdin: Bool = false

  @Flag(help: "connect to the OCI registry via insecure HTTP protocol")
  var insecure: Bool = false

  func validate() throws {
    let usernameProvided = username != nil
    let passwordProvided = passwordStdin

    if usernameProvided != passwordProvided {
      throw ValidationError("both --username and --password-stdin are required")
    }
  }

  func run() async throws {
    do {
      var user: String
      var password: String

      if let username = username {
        user = username

        let passwordData = FileHandle.standardInput.readDataToEndOfFile()
        password = String(decoding: passwordData, as: UTF8.self)
      } else {
        (user, password) = try StdinCredentials.retrieve()
      }
      let credentialsProvider = DictionaryCredentialsProvider([
        host: (user, password)
      ])

      do {
        let registry = try Registry(host: host, namespace: "", insecure: insecure,
          credentialsProviders: [credentialsProvider])
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
