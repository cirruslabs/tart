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

    let (manifest, _) = try await registry.pullManifest(reference: name.reference.value)

    if let cacheToVMDir = try cache(name: name, digest: manifest.digest()) {
      try await cacheToVMDir.pullFromRegistry(registry: registry, manifest: manifest)
    }
  }

  func cache(name: RemoteName, digest: String) throws -> VMDirectory? {
    var result: VMDirectory? = nil

    var digestName = name
    digestName.reference = Reference(digest: digest)

    if !exists(digestName) {
      result = try create(digestName)
    } else {
      defaultLogger.appendNewLine("\(digestName) image is already cached! creating a symlink...")
    }

    if name != digestName {
      // Overwrite the old symbolic link
      if FileManager.default.fileExists(atPath: vmURL(name).path) {
        try FileManager.default.removeItem(at: vmURL(name))
      }

      try FileManager.default.createSymbolicLink(at: vmURL(name), withDestinationURL: vmURL(digestName))
    }

    return result
  }
}

extension URL {
  func appendingRemoteName(_ name: RemoteName) -> URL {
    var result: URL = self

    for pathComponent in (name.host + "/" + name.namespace + "/" + name.reference.value).split(separator: "/") {
      result = result.appendingPathComponent(String(pathComponent))
    }

    return result
  }
}
