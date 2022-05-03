import Foundation
import Compression

enum OCIError: Error {
  case ShouldBeExactlyOneLayer
  case ShouldBeAtLeastOneLayer
  case FailedToCreateDiskFile
}

extension VMDirectory {
  private static let bufferSizeBytes = 64 * 1024 * 1024
  private static let layerLimitBytes = 500 * 1000 * 1000

  private static let configMediaType = "application/vnd.cirruslabs.tart.config.v1"
  private static let diskMediaType = "application/vnd.cirruslabs.tart.disk.v1"
  private static let nvramMediaType = "application/vnd.cirruslabs.tart.nvram.v1"

  func pullFromRegistry(registry: Registry, reference: String) async throws {
    defaultLogger.appendNewLine("pulling manifest")

    let (manifest, _) = try await registry.pullManifest(reference: reference)

    return try await pullFromRegistry(registry: registry, manifest: manifest)
  }

  func pullFromRegistry(registry: Registry, manifest: OCIManifest) async throws {
    // Pull VM's config file layer and re-serialize it into a config file
    let configLayers = manifest.layers.filter {
      $0.mediaType == Self.configMediaType
    }
    if configLayers.count != 1 {
      throw OCIError.ShouldBeExactlyOneLayer
    }
    let configData = try await registry.pullBlob(configLayers.first!.digest)
    try VMConfig(fromData: configData).save(toURL: configURL)

    // Pull VM's disk layers and decompress them sequentially into a disk file
    let diskLayers = manifest.layers.filter {
      $0.mediaType == Self.diskMediaType
    }
    if diskLayers.isEmpty {
      throw OCIError.ShouldBeAtLeastOneLayer
    }
    if !FileManager.default.createFile(atPath: diskURL.path, contents: nil) {
      throw OCIError.FailedToCreateDiskFile
    }
    let disk = try FileHandle(forWritingTo: diskURL)
    let filter = try OutputFilter(.decompress, using: .lz4, bufferCapacity: Self.bufferSizeBytes) { data in
      if let data = data {
        disk.write(data)
      }
    }

    // Progress
    let progress = Progress(totalUnitCount: Int64(diskLayers.map{ $0.size }.reduce(0) { $0 + $1 }))
    defaultLogger.appendNewLine("pulling disk, \(progress.percentage())")

    for diskLayer in diskLayers {
      let diskData = try await registry.pullBlob(diskLayer.digest)
      try filter.write(diskData)

      // Progress
      progress.completedUnitCount += Int64(diskLayer.size)
      defaultLogger.updateLastLine("pulling disk, \(progress.percentage())")
    }
    try filter.finalize()
    try disk.close()

    // Pull VM's NVRAM file layer and store it in an NVRAM file
    defaultLogger.appendNewLine("pulling NVRAM")

    let nvramLayers = manifest.layers.filter {
      $0.mediaType == Self.nvramMediaType
    }
    if nvramLayers.count != 1 {
      throw OCIError.ShouldBeExactlyOneLayer
    }
    let nvramData = try await registry.pullBlob(nvramLayers.first!.digest)
    try nvramData.write(to: nvramURL)
  }

  func pushToRegistry(registry: Registry, references: [String]) async throws {
    var layers = Array<OCIManifestLayer>()

    // Read VM's config and push it as blob
    let config = try VMConfig(fromURL: configURL)
    let configJSON = try JSONEncoder().encode(config)
    let configDigest = try await registry.pushBlob(fromData: configJSON)
    layers.append(OCIManifestLayer(mediaType: Self.configMediaType, size: configJSON.count, digest: configDigest))

    // Progress
    let diskSize = try FileManager.default.attributesOfItem(atPath: diskURL.path)[.size] as! Int64
    let progress = Progress(totalUnitCount: diskSize)
    defaultLogger.appendNewLine("pushing disk, \(progress.percentage())")

    // Read VM's compressed disk as chunks
    // and sequentially upload them as blobs
    let disk = try FileHandle(forReadingFrom: diskURL)
    let compressingFilter = try InputFilter<Data>(.compress, using: .lz4, bufferCapacity: Self.bufferSizeBytes) { _ in
      let data = try disk.read(upToCount: Self.bufferSizeBytes)

      // Progress
      progress.completedUnitCount += Int64(data?.count ?? 0)

      return data
    }
    while let chunk = try compressingFilter.readData(ofLength: Self.layerLimitBytes) {
      let chunkDigest = try await registry.pushBlob(fromData: chunk)
      layers.append(OCIManifestLayer(mediaType: Self.diskMediaType, size: chunk.count, digest: chunkDigest))

      // Progress
      defaultLogger.updateLastLine("pushing disk, \(progress.percentage())")
    }

    // Read VM's NVRAM and push it as blob
    defaultLogger.appendNewLine("pushing NVRAM")

    let nvram = try FileHandle(forReadingFrom: nvramURL).readToEnd()!
    let nvramDigest = try await registry.pushBlob(fromData: nvram)
    layers.append(OCIManifestLayer(mediaType: Self.nvramMediaType, size: nvram.count, digest: nvramDigest))

    // Craft a stub OCI config for Docker Hub compatibility
    struct OCIConfig: Encodable, Decodable {
      var architecture: String = "arm64"
      var os: String = "darwin"
    }

    let ociConfigJSON = try JSONEncoder().encode(OCIConfig())
    let ociConfigDigest = try await registry.pushBlob(fromData: ociConfigJSON)
    let ociConfigDescriptor = Descriptor(size: ociConfigJSON.count, digest: ociConfigDigest)

    // Manifest
    for reference in references {
      defaultLogger.appendNewLine("pushing manifest")

      _ = try await registry.pushManifest(reference: reference, config: ociConfigDescriptor, layers: layers)
    }
  }
}

extension Progress {
  func percentage() -> String {
    String(Int(100 * fractionCompleted)) + "%"
  }
}
