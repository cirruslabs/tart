import ArgumentParser
import Dispatch
import SwiftUI

struct Pull: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Pull a VM from a registry",
    discussion: """
    Pulls a virtual machine from a remote OCI-compatible registry. Supports authorization via Keychain (see "tart login --help"),
    Docker credential helpers defined in ~/.docker/config.json or via TART_REGISTRY_USERNAME/TART_REGISTRY_PASSWORD environment variables.

    By default, Tart checks available capacity in Tart's home directory and tries to reclaim minimum possible storage for the remote image to fit via "tart prune".
    This behaviour can be disabled by setting TART_NO_AUTO_PRUNE environment variable.
    """
  )

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
