import Foundation

class VMStorageOCI {
  let baseURL = Config.tartCacheDir.appendingPathComponent("OCIs", isDirectory: true)

  private func vmURL(_ name: RemoteName) -> URL {
    baseURL.appendingRemoteName(name)
  }

  func exists(_ name: RemoteName) -> Bool {
    VMDirectory(baseURL: vmURL(name)).initialized
  }

  func open(_ name: RemoteName) throws -> VMDirectory {
    let vmDir = VMDirectory(baseURL: vmURL(name))

    try vmDir.validate()

    return vmDir
  }

  func create(_ name: RemoteName, overwrite: Bool = false) throws -> VMDirectory {
    let vmDir = VMDirectory(baseURL: vmURL(name))

    try vmDir.initialize(overwrite: overwrite)

    return vmDir
  }

  func delete(_ name: RemoteName) throws {
    try FileManager.default.removeItem(at: vmURL(name))
  }

  func list() throws -> [(String, VMDirectory)] {
    var result: [(String, VMDirectory)] = Array()

    guard let enumerator = FileManager.default.enumerator(at: baseURL,
      includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.producesRelativePathURLs]) else {
      return []
    }

    for case let foundURL as URL in enumerator {
      let vmDir = VMDirectory(baseURL: foundURL)

      if !vmDir.initialized {
        continue
      }

      let parts = [foundURL.deletingLastPathComponent().relativePath, foundURL.lastPathComponent]
      var name: String

      if try foundURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink! {
        name = parts.joined(separator: ":")
      } else {
        name = parts.joined(separator: "@")
      }

      result.append((name, vmDir))
    }

    return result
  }

  func pull(_ name: RemoteName, registry: Registry) async throws {
    defaultLogger.appendNewLine("pulling manifest...")

    let (manifest, manifestData) = try await registry.pullManifest(reference: name.reference)

    // Create directory for manifest's digest
    var digestName = name
    digestName.reference = Digest.hash(manifestData)
    if !exists(digestName) {
      let vmDir = try create(digestName)
      try await vmDir.pullFromRegistry(registry: registry, manifest: manifest)
    } else {
      defaultLogger.appendNewLine("\(digestName.reference) image is already cached! creating a symlink...")   
    }

    // Create directory for reference if it's different
    if digestName != name {
      // Overwrite the old symbolic link
      if FileManager.default.fileExists(atPath: vmURL(name).path) {
        try FileManager.default.removeItem(at: vmURL(name))
      }

      try FileManager.default.createSymbolicLink(at: vmURL(name), withDestinationURL: vmURL(digestName))
    }
  }
}

extension URL {
  func appendingRemoteName(_ name: RemoteName) -> URL {
    var result: URL = self

    for pathComponent in (name.host + "/" + name.namespace + "/" + name.reference).split(separator: "/") {
      result = result.appendingPathComponent(String(pathComponent))
    }

    return result
  }
}
