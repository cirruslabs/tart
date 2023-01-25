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

  @Flag(help: "connect to the OCI registry via insecure HTTP protocol")
  var insecure: Bool = false

  @Option(help: ArgumentHelp("chunk size in MB if registry supports chunked uploads",
                             discussion: """
                             By default monolithic method is used for uploading blobs to the registry but some registries support a more efficient chunked method.
                             For example, AWS Elastic Container Registry supports only chunks larger than 5MB but GitHub Container Registry supports only chunks smaller than 4MB. Google Container Registry on the other hand doesn't support chunked uploads at all.
                             Please refer to the documentation of your particular registry in order to see if this option is suitable for you and what's the recommended chunk size.
                             """))
  var chunkSize: Int = 0

  @Flag(help: ArgumentHelp("cache pushed images locally",
                           discussion: "Increases disk usage, but saves time if you're going to pull the pushed images later."))
  var populateCache: Bool = false

  func run() async throws {
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
      let registry = try Registry(host: registryIdentifier.host, namespace: registryIdentifier.namespace,
                                  insecure: insecure)

      defaultLogger.appendNewLine("pushing \(localName) to "
        + "\(registryIdentifier.host)/\(registryIdentifier.namespace)\(remoteNamesForRegistry.referenceNames())...")

      let pushedReference = try await localVMDir.pushToRegistry(
        registry: registry,
        references: remoteNamesForRegistry.map{ $0.reference.value },
        chunkSizeMb: chunkSize
      )
      let pushedRemoteName = RemoteName(host: registry.baseURL.host!, namespace: registry.namespace,
                                        reference: pushedReference)

      // Populate the local cache (if requested)
      if populateCache {
        let ociStorage = VMStorageOCI()
        let expectedPushedVMDir = try ociStorage.create(pushedRemoteName)
        try localVMDir.clone(to: expectedPushedVMDir, generateMAC: false)
        for remoteName in remoteNamesForRegistry {
          try ociStorage.link(from: remoteName, to: pushedRemoteName)
        }
      }
    }
  }
}

extension Collection where Element == RemoteName {
  func referenceNames() -> String {
    let references = self.map{ $0.reference.fullyQualified }

    switch count {
    case 0: return "∅"
    case 1: return references.first!
    default: return "{" + references.joined(separator: ",") + "}"
    }
  }
}
