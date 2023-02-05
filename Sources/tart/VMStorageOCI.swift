import Foundation
import Sentry

class VMStorageOCI: PrunableStorage {
  let baseURL = try! Config().tartCacheDir.appendingPathComponent("OCIs", isDirectory: true)

  private func vmURL(_ name: RemoteName) -> URL {
    baseURL.appendingRemoteName(name)
  }

  private func hostDirectoryURL(_ name: RemoteName) -> URL {
    baseURL.appendingHost(name)
  }

  func exists(_ name: RemoteName) -> Bool {
    VMDirectory(baseURL: vmURL(name)).initialized
  }

  func open(_ name: RemoteName) throws -> VMDirectory {
    let vmDir = VMDirectory(baseURL: vmURL(name))

    try vmDir.validate()

    try vmDir.baseURL.updateAccessDate()

    return vmDir
  }

  func create(_ name: RemoteName, overwrite: Bool = false) throws -> VMDirectory {
    let vmDir = VMDirectory(baseURL: vmURL(name))

    try vmDir.initialize(overwrite: overwrite)

    return vmDir
  }

  func move(_ name: RemoteName, from: VMDirectory) throws{
    let targetURL = vmURL(name)

    // Pre-create intermediate directories (e.g. creates ~/.tart/cache/OCIs/github.com/org/repo/
    // for github.com/org/repo:latest)
    try FileManager.default.createDirectory(at: targetURL.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)

    _ = try FileManager.default.replaceItemAt(targetURL, withItemAt: from.baseURL)
  }

  func delete(_ name: RemoteName) throws {
    try FileManager.default.removeItem(at: vmURL(name))
    try gc()
  }

  func gc() throws {
    var refCounts = Dictionary<URL, UInt>()

    guard let enumerator = FileManager.default.enumerator(at: baseURL,
                                                          includingPropertiesForKeys: [.isSymbolicLinkKey]) else {
      return
    }

    for case let foundURL as URL in enumerator {
      let isSymlink = try foundURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink!

      // Perform garbage collection for tag-based images
      // with broken outgoing references
      if isSymlink && foundURL == foundURL.resolvingSymlinksInPath() {
        try FileManager.default.removeItem(at: foundURL)
        continue
      }

      let vmDir = VMDirectory(baseURL: foundURL.resolvingSymlinksInPath())
      if !vmDir.initialized {
        continue
      }

      refCounts[vmDir.baseURL] = (refCounts[vmDir.baseURL] ?? 0) + (isSymlink ? 1 : 0)
    }

    // Perform garbage collection for digest-based images
    // with no incoming references
    for (baseURL, incRefCount) in refCounts {
      let vmDir = VMDirectory(baseURL: baseURL)

      if !vmDir.isExplicitlyPulled() && incRefCount == 0 {
        try FileManager.default.removeItem(at: baseURL)
      }
    }
  }

  func list() throws -> [(String, VMDirectory, Bool)] {
    var result: [(String, VMDirectory, Bool)] = Array()

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

      let isSymlink = try foundURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink!
      if isSymlink {
        name = parts.joined(separator: ":")
      } else {
        name = parts.joined(separator: "@")
      }

      result.append((name, vmDir, isSymlink))
    }

    return result
  }

  func prunables() throws -> [Prunable] {
    try list().filter { (_, _, isSymlink) in !isSymlink }.map { (_, vmDir, _) in vmDir }
  }

  func pull(_ name: RemoteName, registry: Registry) async throws {
    defaultLogger.appendNewLine("pulling manifest...")

    let (manifest, manifestData) = try await registry.pullManifest(reference: name.reference.value)

    let digestName = RemoteName(host: name.host, namespace: name.namespace,
                                reference: Reference(digest: Digest.hash(manifestData)))

    // Ensure that host directory for given RemoteName exists in OCI storage
    let hostDirectoryURL = hostDirectoryURL(digestName)
    try FileManager.default.createDirectory(at: hostDirectoryURL, withIntermediateDirectories: true)

    // Acquire a lock on it to prevent concurrent pulls for a single host
    let lock = try FileLock(lockURL: hostDirectoryURL)

    let sucessfullyLocked = try lock.trylock()
    if !sucessfullyLocked {
      print("waiting for lock...")
      try lock.lock()
    }
    defer { try! lock.unlock() }

    if Task.isCancelled {
      throw CancellationError()
    }

    if !exists(digestName) {
      let transaction = SentrySDK.startTransaction(name: name.description, operation: "pull", bindToScope: true)
      let tmpVMDir = try VMDirectory.temporary()

      // Lock the temporary VM directory to prevent it's garbage collection
      let tmpVMDirLock = try FileLock(lockURL: tmpVMDir.baseURL)
      try tmpVMDirLock.lock()

      // Try to reclaim some cache space if we know the VM size in advance
      if let uncompressedDiskSize = manifest.uncompressedDiskSize() {
        let requiredCapacityBytes = UInt64(uncompressedDiskSize + 128 * 1024 * 1024)

        let attrs = try Config().tartCacheDir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
        let capacityImportant = attrs.volumeAvailableCapacityForImportantUsage!
        let capacityAvailable = attrs.volumeAvailableCapacity!
        let availableCapacityBytes = max(UInt64(capacityImportant), UInt64(capacityAvailable))

        if capacityImportant == 0 || capacityAvailable == 0 {
          SentrySDK.capture(message: "Zero capacity") { scope in
            scope.setLevel(.warning)

            scope.setContext(value: [
              "volumeAvailableCapacityForImportantUsageKey": capacityImportant,
              "volumeAvailableCapacityKey": capacityAvailable,
            ], key: "Attributes")
          }
        }

        // There is a suspicious that occasionally capacity is returned as zero which can't be true.
        // Let's validate to avoid unnecessary pruning.
        if 0 < availableCapacityBytes && availableCapacityBytes < requiredCapacityBytes {
          let transaction = SentrySDK.startTransaction(name: "Automatically Pruning Cache", operation: "prune", bindToScope: true)
          transaction.setData(value: name, key: "name")
          transaction.setData(value: uncompressedDiskSize, key: "uncompressedDiskSize")
          transaction.setData(value: availableCapacityBytes, key: "availableCapacity")
          transaction.setData(value: requiredCapacityBytes, key: "requiredCapacity")
          defer { transaction.finish() }

          try Prune.pruneReclaim(reclaimBytes: requiredCapacityBytes - availableCapacityBytes)
        }
      }

      try await withTaskCancellationHandler(operation: {
        try await tmpVMDir.pullFromRegistry(registry: registry, manifest: manifest)
        try move(digestName, from: tmpVMDir)
        transaction.finish()
      }, onCancel: {
        transaction.finish(status: SentrySpanStatus.cancelled)
        try? FileManager.default.removeItem(at: tmpVMDir.baseURL)
      })
    } else {
      defaultLogger.appendNewLine("\(digestName) image is already cached! creating a symlink...")
    }

    if name != digestName {
      // Create new or overwrite the old symbolic link
      try link(from: name, to: digestName)
    } else {
      // Ensure that images pulled by content digest
      // are excluded from garbage collection
      VMDirectory(baseURL: vmURL(name)).markExplicitlyPulled()
    }
  }

  func link(from: RemoteName, to: RemoteName) throws {
    if FileManager.default.fileExists(atPath: vmURL(from).path) {
      try FileManager.default.removeItem(at: vmURL(from))
    }

    try FileManager.default.createSymbolicLink(at: vmURL(from), withDestinationURL: vmURL(to))

    try gc()
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

  func appendingHost(_ name: RemoteName) -> URL {
    self.appendingPathComponent(name.host, isDirectory: true)
  }
}
