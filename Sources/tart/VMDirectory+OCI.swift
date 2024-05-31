import Compression
import Foundation
import Sentry

enum OCIError: Error {
  case ShouldBeExactlyOneLayer
  case ShouldBeAtLeastOneLayer
  case FailedToCreateVmFile
  case LayerIsMissingUncompressedSizeAnnotation
  case LayerIsMissingUncompressedDigestAnnotation
}

extension VMDirectory {
  private static let bufferSizeBytes = 64 * 1024 * 1024
  private static let layerLimitBytes = 500 * 1000 * 1000

  func pullFromRegistry(registry: Registry, manifest: OCIManifest, concurrency: UInt, localLayerCache: LocalLayerCache?) async throws {
    // Pull VM's config file layer and re-serialize it into a config file
    let configLayers = manifest.layers.filter {
      $0.mediaType == configMediaType
    }
    if configLayers.count != 1 {
      throw OCIError.ShouldBeExactlyOneLayer
    }
    if !FileManager.default.createFile(atPath: configURL.path, contents: nil) {
      throw OCIError.FailedToCreateVmFile
    }
    let configFile = try FileHandle(forWritingTo: configURL)
    try await registry.pullBlob(configLayers.first!.digest) { data in
      configFile.write(data)
    }
    try configFile.close()

    // Pull VM's disk layers and decompress them into a disk file
    let diskImplType: Disk.Type
    let layers: [OCIManifestLayer]

    if manifest.layers.contains(where: { $0.mediaType == diskV1MediaType }) {
      diskImplType = DiskV1.self
      layers = manifest.layers.filter { $0.mediaType == diskV1MediaType }
    } else if manifest.layers.contains(where: { $0.mediaType == diskV2MediaType }) {
      diskImplType = DiskV2.self
      layers = manifest.layers.filter { $0.mediaType == diskV2MediaType }
    } else {
      throw OCIError.ShouldBeAtLeastOneLayer
    }

    let diskCompressedSize = layers.map { Int64($0.size) }.reduce(0, +)
    SentrySDK.span?.setMeasurement(name: "compressed_disk_size", value: diskCompressedSize as NSNumber, unit: MeasurementUnitInformation.byte)

    let prettyDiskSize = String(format: "%.1f", Double(diskCompressedSize) / 1_000_000_000.0)
    defaultLogger.appendNewLine("pulling disk (\(prettyDiskSize) GB compressed)...")

    let progress = Progress(totalUnitCount: diskCompressedSize)
    ProgressObserver(progress).log(defaultLogger)

    do {
      try await diskImplType.pull(registry: registry, diskLayers: layers, diskURL: diskURL,
                                  concurrency: concurrency, progress: progress,
                                  localLayerCache: localLayerCache)
    } catch let error where error is FilterError {
      throw RuntimeError.PullFailed("failed to decompress disk: \(error.localizedDescription)")
    }

    // Pull VM's NVRAM file layer and store it in an NVRAM file
    defaultLogger.appendNewLine("pulling NVRAM...")

    let nvramLayers = manifest.layers.filter {
      $0.mediaType == nvramMediaType
    }
    if nvramLayers.count != 1 {
      throw OCIError.ShouldBeExactlyOneLayer
    }
    if !FileManager.default.createFile(atPath: nvramURL.path, contents: nil) {
      throw OCIError.FailedToCreateVmFile
    }
    let nvram = try FileHandle(forWritingTo: nvramURL)
    try await registry.pullBlob(nvramLayers.first!.digest) { data in
      nvram.write(data)
    }
    try nvram.close()
  }

  func pushToRegistry(registry: Registry, references: [String], chunkSizeMb: Int, diskFormat: String) async throws -> RemoteName {
    var layers = Array<OCIManifestLayer>()

    // Read VM's config and push it as blob
    let config = try VMConfig(fromURL: configURL)
    let configJSON = try JSONEncoder().encode(config)
    defaultLogger.appendNewLine("pushing config...")
    let configDigest = try await registry.pushBlob(fromData: configJSON, chunkSizeMb: chunkSizeMb)
    layers.append(OCIManifestLayer(mediaType: configMediaType, size: configJSON.count, digest: configDigest))

    // Compress the disk file as multiple chunks and push them as disk layers
    let diskSize = try FileManager.default.attributesOfItem(atPath: diskURL.path)[.size] as! Int64

    defaultLogger.appendNewLine("pushing disk... this will take a while...")
    let progress = Progress(totalUnitCount: diskSize)
    ProgressObserver(progress).log(defaultLogger)

    switch diskFormat {
    case "v1":
      layers.append(contentsOf: try await DiskV1.push(diskURL: diskURL, registry: registry, chunkSizeMb: chunkSizeMb, progress: progress))
    case "v2":
      layers.append(contentsOf: try await DiskV2.push(diskURL: diskURL, registry: registry, chunkSizeMb: chunkSizeMb, progress: progress))
    default:
      throw RuntimeError.OCIUnsupportedDiskFormat(diskFormat)
    }

    // Read VM's NVRAM and push it as blob
    defaultLogger.appendNewLine("pushing NVRAM...")

    let nvram = try FileHandle(forReadingFrom: nvramURL).readToEnd()!
    let nvramDigest = try await registry.pushBlob(fromData: nvram, chunkSizeMb: chunkSizeMb)
    layers.append(OCIManifestLayer(mediaType: nvramMediaType, size: nvram.count, digest: nvramDigest))

    // Craft a stub OCI config for Docker Hub compatibility
    let ociConfigJSON = try OCIConfig(architecture: config.arch, os: config.os).toJSON()
    let ociConfigDigest = try await registry.pushBlob(fromData: ociConfigJSON, chunkSizeMb: chunkSizeMb)
    let manifest = OCIManifest(
      config: OCIManifestConfig(size: ociConfigJSON.count, digest: ociConfigDigest),
      layers: layers,
      uncompressedDiskSize: UInt64(diskSize),
      uploadDate: Date()
    )

    // Manifest
    for reference in references {
      defaultLogger.appendNewLine("pushing manifest for \(reference)...")

      _ = try await registry.pushManifest(reference: reference, manifest: manifest)
    }

    let pushedReference = Reference(digest: try manifest.digest())
    return RemoteName(host: registry.host!, namespace: registry.namespace, reference: pushedReference)
  }
}

extension Progress {
  func percentage() -> String {
    String(Int(100 * fractionCompleted)) + "%"
  }
}
