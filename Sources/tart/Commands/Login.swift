import ArgumentParser
import Dispatch
import SwiftUI

struct Login: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Login to a registry")

  @Argument(help: "host")
  var host: String

  func run() async throws {
    do {
      let (user, password) = try Credentials.retrieveStdin()

      try Credentials.store(host: host, user: user, password: password)

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}
