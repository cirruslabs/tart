import ArgumentParser
import Foundation
import SystemConfiguration

struct Clone: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Clone a VM")

  @Argument(help: "source VM name")
  var sourceName: String

  @Argument(help: "new VM name")
  var newName: String

  func validate() throws {
    if newName.contains("/") {
      throw ValidationError("<new-name> should be a local name")
    }
  }

  func run() async throws {
    do {
      if let remoteName = try? RemoteName(sourceName), !VMStorageOCI().exists(remoteName) {
        // Pull the VM in case it's OCI-based and doesn't exist locally yet
        let registry = try Registry(host: remoteName.host, namespace: remoteName.namespace)
        try await VMStorageOCI().pull(remoteName, registry: registry)
      }

      let tmpVMDir = try VMDirectory.temporary()
      try VMStorageHelper.open(sourceName).clone(to: tmpVMDir, generateMAC: true)
      try VMStorageLocal().move(newName, from: tmpVMDir)

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}
