import ArgumentParser
import Dispatch
import Foundation
import Compression

struct Push: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Push a VM to a registry")

  @Argument(help: "local VM name")
  var localName: String

  @Argument(help: "remote VM name(s)")
  var remoteNames: [String]

  func run() async throws {
    do {
      let localVMDir = try VMStorageLocal().open(localName)

      // Parse remote names supplied by the user
      let remoteNames = try remoteNames.map{
        try RemoteName($0)
      }

      // Group remote names by registry
      struct RegistryIdentifier: Hashable, Equatable {
        var host: String
        var namespace: String
      }

      let registryGroups = Dictionary(grouping: remoteNames, by: {
        RegistryIdentifier(host: $0.host, namespace: $0.namespace)
      })

      // Push VM
      for (registryIdentifier, remoteNamesForRegistry) in registryGroups {
        let registry = try Registry(host: registryIdentifier.host, namespace: registryIdentifier.namespace)

        for remoteName in remoteNamesForRegistry {
          try await localVMDir.pushToRegistry(registry: registry, reference: remoteName.reference)
        }
      }

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}
