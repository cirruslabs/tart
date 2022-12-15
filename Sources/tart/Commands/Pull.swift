import ArgumentParser
import Dispatch
import SwiftUI

struct Pull: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Pull a VM from a registry")

  @Argument(help: "remote VM name")
  var remoteName: String

  @Flag(help: "connect to the OCI registry via insecure HTTP protocol")
  var insecure: Bool = false

  func run() async throws {
    // Be more liberal when accepting local image as argument,
    // see https://github.com/cirruslabs/tart/issues/36
    if VMStorageLocal().exists(remoteName) {
      print("\"\(remoteName)\" is a local image, nothing to pull here!")

      return
    }

    let remoteName = try RemoteName(remoteName)
    let registry = try Registry(host: remoteName.host, namespace: remoteName.namespace, insecure: insecure)

    defaultLogger.appendNewLine("pulling \(remoteName)...")

    try await VMStorageOCI().pull(remoteName, registry: registry)
  }
}
