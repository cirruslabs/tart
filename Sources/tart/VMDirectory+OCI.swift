import Foundation
import Compression
import Sentry

enum OCIError: Error {
  case ShouldBeExactlyOneLayer
  case ShouldBeAtLeastOneLayer
  case FailedToCreateVmFile
}

extension VMDirectory {
  private static let bufferSizeBytes = 64 * 1024 * 1024
  private static let layerLimitBytes = 500 * 1000 * 1000

  private static let configMediaType = "application/vnd.cirruslabs.tart.config.v1"
  private static let diskMediaType = "application/vnd.cirruslabs.tart.disk.v1"
  private static let nvramMediaType = "application/vnd.cirruslabs.tart.nvram.v1"

  func pullFromRegistry(registry: Registry, reference: String) async throws {
    defaultLogger.appendNewLine("pulling manifest...")

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
    if !FileManager.default.createFile(atPath: configURL.path, contents: nil) {
      throw OCIError.FailedToCreateVmFile
    }
    let configFile = try FileHandle(forWritingTo: configURL)
    try await registry.pullBlob(configLayers.first!.digest) { data in
      configFile.write(data)
    }
    try configFile.close()

    // Pull VM's disk layers and decompress them sequentially into a disk file
    let diskLayers = manifest.layers.filter {
      $0.mediaType == Self.diskMediaType
    }
    if diskLayers.isEmpty {
      throw OCIError.ShouldBeAtLeastOneLayer
    }
    if !FileManager.default.createFile(atPath: diskURL.path, contents: nil) {
      throw OCIError.FailedToCreateVmFile
    }
    let disk = try FileHandle(forWritingTo: diskURL)
    let filter = try OutputFilter(.decompress, using: .lz4, bufferCapacity: Self.bufferSizeBytes) { data in
      if let data = data {
        disk.write(data)
      }
    }

    // Progress
    let diskCompressedSize: Int64 = Int64(diskLayers.map {
      $0.size
    }
    .reduce(0) {
      $0 + $1
    })
    let prettyDiskSize = String(format: "%.1f", Double(diskCompressedSize) / 1_000_000_000.0)
    defaultLogger.appendNewLine("pulling disk (\(prettyDiskSize) GB compressed)...")
    let progress = Progress(totalUnitCount: diskCompressedSize)
    ProgressObserver(progress).log(defaultLogger)

    for diskLayer in diskLayers {
      try await registry.pullBlob(diskLayer.digest) { data in
        try filter.write(data)
        progress.completedUnitCount += Int64(data.count)
      }
    }
    try filter.finalize()
    try disk.close()
    SentrySDK.span?.setMeasurement(name: "compressed_disk_size", value: diskCompressedSize as NSNumber, unit: MeasurementUnitInformation.byte);

    // Pull VM's NVRAM file layer and store it in an NVRAM file
    defaultLogger.appendNewLine("pulling NVRAM...")

    let nvramLayers = manifest.layers.filter {
      $0.mediaType == Self.nvramMediaType
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

  func pushToRegistry(registry: Registry, references: [String], chunkSizeMb: Int) async throws -> RemoteName {
    var layers = Array<OCIManifestLayer>()

    // Read VM's config and push it as blob
    let config = try VMConfig(fromURL: configURL)
    let configJSON = try JSONEncoder().encode(config)
    defaultLogger.appendNewLine("pushing config...")
    let configDigest = try await registry.pushBlob(fromData: configJSON, chunkSizeMb: chunkSizeMb)
    layers.append(OCIManifestLayer(mediaType: Self.configMediaType, size: configJSON.count, digest: configDigest))

    // Progress
    let diskSize = try FileManager.default.attributesOfItem(atPath: diskURL.path)[.size] as! Int64

    defaultLogger.appendNewLine("pushing disk... this will take a while...")
    let progress = Progress(totalUnitCount: diskSize)
    ProgressObserver(progress).log(defaultLogger)

    // Read VM's compressed disk as chunks
    // and sequentially upload them as blobs
    let mappedDisk = try Data(contentsOf: diskURL, options: [.alwaysMapped])
    let mappedDiskSize = mappedDisk.count
    var mappedDiskReadOffset = 0
    let compressingFilter = try InputFilter(.compress, using: .lz4, bufferCapacity: Self.bufferSizeBytes) { (length: Int) -> Data? in
      let bytesRead = min(length, mappedDiskSize - mappedDiskReadOffset)
      let data = mappedDisk.subdata(in: mappedDiskReadOffset ..< mappedDiskReadOffset + bytesRead)
      mappedDiskReadOffset += bytesRead

      progress.completedUnitCount = Int64(mappedDiskReadOffset)

      return data
    }
    while let compressedLayerData = try compressingFilter.readData(ofLength: Self.layerLimitBytes) {
      let layerDigest = try await registry.pushBlob(fromData: compressedLayerData, chunkSizeMb: chunkSizeMb)
      layers.append(OCIManifestLayer(mediaType: Self.diskMediaType, size: compressedLayerData.count, digest: layerDigest))
    }

    // Read VM's NVRAM and push it as blob
    defaultLogger.appendNewLine("pushing NVRAM...")

    let nvram = try FileHandle(forReadingFrom: nvramURL).readToEnd()!
    let nvramDigest = try await registry.pushBlob(fromData: nvram, chunkSizeMb: chunkSizeMb)
    layers.append(OCIManifestLayer(mediaType: Self.nvramMediaType, size: nvram.count, digest: nvramDigest))

    // Craft a stub OCI config for Docker Hub compatibility
    let ociConfigJSON = try OCIConfig(architecture: config.arch, os: config.os).toJSON()
    let ociConfigDigest = try await registry.pushBlob(fromData: ociConfigJSON, chunkSizeMb: chunkSizeMb)
    let manifest = OCIManifest(
      config: OCIManifestConfig(size: ociConfigJSON.count, digest: ociConfigDigest),
      layers: layers,
      uncompressedDiskSize: UInt64(mappedDiskReadOffset),
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
