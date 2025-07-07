import Foundation
import Sentry
import Retry

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

  func digest(_ name: RemoteName) throws -> String {
    let digest = vmURL(name).resolvingSymlinksInPath().lastPathComponent

    if !digest.starts(with: "sha256:") {
      throw RuntimeError.OCIStorageError("\(name) is not a digest and doesn't point to a digest")
    }

    return digest
  }

  func open(_ name: RemoteName, _ accessDate: Date = Date()) throws -> VMDirectory {
    let vmDir = VMDirectory(baseURL: vmURL(name))

    try vmDir.validate(userFriendlyName: name.description)

    try vmDir.baseURL.updateAccessDate(accessDate)

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

      // Split the relative VM's path at the last component
      // and figure out which character should be used
      // to join them together, either ":" for tags or
      // "@" for hashes
      let parts = [foundURL.deletingLastPathComponent().relativePath, foundURL.lastPathComponent]
      var name: String

      let isSymlink = try foundURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink!
      if isSymlink {
        name = parts.joined(separator: ":")
      } else {
        name = parts.joined(separator: "@")
      }

      // Remove the percent-encoding, if any
      name = percentDecode(name)

      result.append((name, vmDir, isSymlink))
    }

    return result
  }

  func prunables() throws -> [Prunable] {
    try list().filter { (_, _, isSymlink) in !isSymlink }.map { (_, vmDir, _) in vmDir }
  }

  func pull(_ name: RemoteName, registry: Registry, concurrency: UInt, deduplicate: Bool) async throws {
    SentrySDK.configureScope { scope in
      scope.setContext(value: ["imageName": name.description], key: "OCI")
    }

    defaultLogger.appendNewLine("pulling manifest...")

    let (manifest, manifestData) = try await registry.pullManifest(reference: name.reference.value)

    let digestName = RemoteName(host: name.host, namespace: name.namespace,
                                reference: Reference(digest: Digest.hash(manifestData)))

    if exists(name) && exists(digestName) && linked(from: name, to: digestName) {
      // optimistically check if we need to do anything at all before locking
      defaultLogger.appendNewLine("\(digestName) image is already cached and linked!")
      return
    }

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
      let tmpVMDir = try VMDirectory.temporaryDeterministic(key: name.description)

      // Open an existing VM directory corresponding to this name, if any,
      // marking it as outdated to speed up the garbage collection process
      _ = try? open(name, Date(timeIntervalSince1970: 0))

      // Lock the temporary VM directory to prevent it's garbage collection
      let tmpVMDirLock = try FileLock(lockURL: tmpVMDir.baseURL)
      try tmpVMDirLock.lock()

      // Try to reclaim some cache space if we know the VM size in advance
      if let uncompressedDiskSize = manifest.uncompressedDiskSize() {
        SentrySDK.configureScope { scope in
          scope.setContext(value: ["imageUncompressedDiskSize": uncompressedDiskSize], key: "OCI")
        }

        let otherVMFilesSize: UInt64 = 128 * 1024 * 1024

        try Prune.reclaimIfNeeded(uncompressedDiskSize + otherVMFilesSize)
      }

      try await withTaskCancellationHandler(operation: {
        try await retry(maxAttempts: 5) {
          // Choose the best base image which has the most deduplication ratio
          let localLayerCache = try await chooseLocalLayerCache(name, manifest, registry)

          if let llc = localLayerCache {
            let deduplicatedHuman = ByteCountFormatter.string(fromByteCount: Int64(llc.deduplicatedBytes), countStyle: .file)

            if deduplicate {
              defaultLogger.appendNewLine("found an image \(llc.name) that will allow us to deduplicate \(deduplicatedHuman), using it as a base...")
            } else {
              defaultLogger.appendNewLine("found an image \(llc.name) that will allow us to avoid fetching \(deduplicatedHuman), will try use it...")
            }
          }

          try await tmpVMDir.pullFromRegistry(registry: registry, manifest: manifest, concurrency: concurrency, localLayerCache: localLayerCache, deduplicate: deduplicate)
        } recoverFromFailure: { error in
          if error is URLError {
            print("Error pulling image: \"\(error.localizedDescription)\", attempting to re-try...")

            return .retry
          }

          return .throw
        }
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

    // to explicitly set the image as being accessed so it won't get pruned immediately
    _ = try VMStorageOCI().open(name)
  }

  func linked(from: RemoteName, to: RemoteName) -> Bool {
    do {
      let resolvedFrom = try FileManager.default.destinationOfSymbolicLink(atPath: vmURL(from).path)
      return resolvedFrom == vmURL(to).path
    } catch {
      return false
    }
  }

  func link(from: RemoteName, to: RemoteName) throws {
    try? FileManager.default.removeItem(at: vmURL(from))

    try FileManager.default.createSymbolicLink(at: vmURL(from), withDestinationURL: vmURL(to))

    try gc()
  }

  func chooseLocalLayerCache(_ name: RemoteName, _ manifest: OCIManifest, _ registry: Registry) async throws -> LocalLayerCache? {
    // Establish a closure that will calculate how much bytes
    // we'll deduplicate if we re-use the given manifest
    let target = Swift.Set(manifest.layers)

    let calculateDeduplicatedBytes = { (manifest: OCIManifest) -> UInt64 in
      target.intersection(manifest.layers).map({ UInt64($0.size) }).reduce(0, +)
    }

    // Load OCI VM images and their manifests (if present)
    var candidates: [(name: String, vmDir: VMDirectory, manifest: OCIManifest, deduplicatedBytes: UInt64)] = []

    for (name, vmDir, isSymlink) in try list() {
      if isSymlink {
        continue
      }

      guard let manifestJSON = try? Data(contentsOf: vmDir.manifestURL) else {
        continue
      }

      guard let manifest = try? OCIManifest(fromJSON: manifestJSON) else {
        continue
      }

      candidates.append((name, vmDir, manifest, calculateDeduplicatedBytes(manifest)))
    }

    // Previously we haven't stored the OCI VM image manifests, but still fetched the VM image manifest if
    // what the user was trying to pull was a tagged image, and we already had that image in the OCI VM cache
    //
    // Keep supporting this behavior for backwards comaptibility, but only communicate
    // with the registry if we haven't already retrieved the manifest for that OCI VM image.
    if name.reference.type == .Tag,
       let vmDir = try? open(name),
       let digest = try? digest(name),
       try !candidates.contains(where: {try $0.manifest.digest() == digest}),
       let (manifest, _) = try? await registry.pullManifest(reference: digest) {
      candidates.append((name.description, vmDir, manifest, calculateDeduplicatedBytes(manifest)))
    }

    // Now, find the best match based on how many bytes we'll deduplicate
    let choosen = candidates.filter {
      $0.deduplicatedBytes > 1024 * 1024 * 1024 // save at least 1GB
    }.max { left, right in
      return left.deduplicatedBytes < right.deduplicatedBytes
    }

    return try choosen.flatMap({ choosen in
      try LocalLayerCache(choosen.name, choosen.deduplicatedBytes, choosen.vmDir.diskURL, choosen.manifest)
    })
  }
}

extension URL {
  func appendingRemoteName(_ name: RemoteName) -> URL {
    var result: URL = self

    for pathComponent in (percentEncode(name.host) + "/" + name.namespace + "/" + name.reference.value).split(separator: "/") {
      result = result.appendingPathComponent(String(pathComponent))
    }

    return result
  }

  func appendingHost(_ name: RemoteName) -> URL {
    self.appendingPathComponent(percentEncode(name.host), isDirectory: true)
  }
}

// Work around a pretty inane Swift's URL behavior where calling
// appendingPathComponent() or deletingLastPathComponent() on a
// URL like URL(filePath: "example.com:8080") (note the "filePath")
// will flip its isFileURL from "true" to "false" and discard its
// absolute path infromation (if any).
//
// The same kind of operations won't do anything to a URL like
// URL(filePath: "127.0.0.1:8080"), which makes things even more
// ridiculous.
private func percentEncode(_ s: String) -> String {
  return s.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: ":").inverted)!
}

private func percentDecode(_ s: String) -> String {
  s.removingPercentEncoding!
}
