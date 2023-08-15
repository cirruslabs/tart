import ArgumentParser
import Dispatch
import SwiftUI

struct Logout: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Logout from a registry")

  @Argument(help: "host")
  var host: String

  func run() async throws {
    try KeychainCredentialsProvider().remove(host: host)
  }
}
