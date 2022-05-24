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

  @Flag(help: ArgumentHelp("cache pushed images locally",
          discussion: "Increases disk usage, but saves time if you're going to pull the pushed images later."))
  var populateCache: Bool = false

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
      var pushedToRemoteNames = Set<RemoteName>()

      for (registryIdentifier, remoteNamesForRegistry) in registryGroups {
        let registry = try Registry(host: registryIdentifier.host, namespace: registryIdentifier.namespace)

        let listOfTagsAndDigests = "{" + remoteNamesForRegistry.map{$0.reference.fullyQualified }
                .joined(separator: ",") + "}"
        defaultLogger.appendNewLine("pushing \(localName) to "
          + "\(registryIdentifier.host)/\(registryIdentifier.namespace)\(listOfTagsAndDigests)...")

        let manifestDigest = try await localVMDir.pushToRegistry(registry: registry, references: remoteNamesForRegistry.map{ $0.reference.value })

        // Gather data to populate the local cache (if requested)
        if populateCache {
          // User-specified RemoteNames
          remoteNamesForRegistry.forEach { pushedToRemoteNames.insert($0) }
          // Specification-derived RemoteNames
          pushedToRemoteNames.insert(
                  RemoteName(
                          host: registryIdentifier.host,
                          namespace: registryIdentifier.namespace,
                          reference: Reference(digest: manifestDigest)
                  )
          )
        }
      }

      // Populate local cache (if requested)
      if populateCache {
        for pushedToRemoteName in pushedToRemoteNames {
          defaultLogger.appendNewLine("caching \(localName) as \(pushedToRemoteName)...")

          let ociVMDir = try VMStorageOCI().create(pushedToRemoteName, overwrite: true)
          try localVMDir.clone(to: ociVMDir, generateMAC: false)
        }
      }

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}
