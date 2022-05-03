import ArgumentParser
import Dispatch
import SwiftUI

struct Pull: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Pull a VM from a registry")

  @Argument(help: "remote VM name")
  var remoteName: String

  func run() async throws {
    do {
      let remoteName = try RemoteName(remoteName)
      let registry = try Registry(host: remoteName.host, namespace: remoteName.namespace)

      defaultLogger.appendNewLine("pulling \(remoteName)...")

      try await VMStorageOCI().pull(remoteName, registry: registry)

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}
