import ArgumentParser
import Foundation
import SystemConfiguration

struct Clone: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Clone a VM")

  @Argument(help: "source VM name")
  var sourceName: String

  @Argument(help: "new VM name")
  var newName: String

  @Flag(help: "Generate new MAC address.")
  var newMacAddress: Bool = false

  func run() async throws {
    do {
      // Pull the VM in case it's OCI-based and doesn't exist locally yet
      if let remoteName = try? RemoteName(sourceName), !VMStorageOCI().exists(remoteName) {
        let registry = try Registry(host: remoteName.host, namespace: remoteName.namespace)
        try await VMStorageOCI().pull(remoteName, registry: registry)
      }

      try VMStorageHelper.open(sourceName).clone(to: VMStorageLocal().create(newName), generateMAC: newMacAddress)

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}
