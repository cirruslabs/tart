import ArgumentParser
import Dispatch
import Foundation
import Compression

struct Push: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Push a VM to a registry")

  @Argument(help: "local VM name")
  var localName: String

  @Argument(help: "remote VM name")
  var remoteName: String

  func run() async throws {
    do {
      let localVMDir = try VMStorageLocal().open(localName)

      let remoteName = try RemoteName(remoteName)
      let registry = try Registry(host: remoteName.host, namespace: remoteName.namespace)

      try await localVMDir.pushToRegistry(registry: registry, reference: remoteName.reference)

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}
