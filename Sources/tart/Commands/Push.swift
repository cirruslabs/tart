import ArgumentParser
import Dispatch
import Foundation
import Compression

struct Push: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Push a VM to a registry")

  @Argument(help: "local or remote VM name")
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

  @Option(help: .hidden)
  var diskFormat: String = "v2"

  @Flag(help: ArgumentHelp("cache pushed images locally",
                           discussion: "Increases disk usage, but saves time if you're going to pull the pushed images later."))
  var populateCache: Bool = false

  func run() async throws {
    let ociStorage = VMStorageOCI()
    let localVMDir = try VMStorageHelper.open(localName)

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

      let references = remoteNamesForRegistry.map{ $0.reference.value }

      let pushedRemoteName: RemoteName
      // If we're pushing a local OCI VM, check if points to an already existing registry manifest
      // and if so, only upload manifests (without config, disk and NVRAM) to the user-specified references
      if let remoteName = try? RemoteName(localName) {
        pushedRemoteName = try await lightweightPushToRegistry(
          registry: registry, 
          remoteName: remoteName,
          references: references
        )
      } else {
        pushedRemoteName = try await localVMDir.pushToRegistry(
          registry: registry,
          references: references,
          chunkSizeMb: chunkSize,
          diskFormat: diskFormat
        )
        // Populate the local cache (if requested)
        if populateCache {
          let expectedPushedVMDir = try ociStorage.create(pushedRemoteName)
          try localVMDir.clone(to: expectedPushedVMDir, generateMAC: false)
        }
      }

      // link the rest remote names
      if populateCache {
        for remoteName in remoteNamesForRegistry {
          try ociStorage.link(from: remoteName, to: pushedRemoteName)
        }
      }
    }
  }

  func lightweightPushToRegistry(registry: Registry, remoteName: RemoteName, references: [String]) async throws -> RemoteName {
    // Is the local OCI VM already present in the registry?
    let digest = try VMStorageOCI().digest(remoteName)

    let (remoteManifest, _) = try await registry.pullManifest(reference: digest)

    // Overwrite registry's references with the retrieved manifest
    for reference in references {
      defaultLogger.appendNewLine("pushing manifest for \(reference)...")

      _ = try await registry.pushManifest(reference: reference, manifest: remoteManifest)
    }

    return RemoteName(host: registry.host!, namespace: registry.namespace,
                      reference: Reference(digest: digest))
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
