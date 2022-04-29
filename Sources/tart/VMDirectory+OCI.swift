import Foundation
import Compression

enum OCIError: Error {
  case ShouldBeExactlyOneLayer
  case ShouldBeAtLeastOneLayer
  case FailedToCreateDiskFile
}

extension VMDirectory {
  private static let bufferSizeBytes = 64 * 1024 * 1024
  private static let layerLimitBytes = 512 * 1024 * 1024

  private static let configMediaType = "application/vnd.cirruslabs.tart.config.v1"
  private static let diskMediaType = "application/vnd.cirruslabs.tart.disk.v1"
  private static let nvramMediaType = "application/vnd.cirruslabs.tart.nvram.v1"

  func pullFromRegistry(registry: Registry, reference: String) async throws {
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
    for diskLayer in diskLayers {
      let diskData = try await registry.pullBlob(diskLayer.digest)
      try filter.write(diskData)
    }
    try filter.finalize()
    try disk.close()

    // Pull VM's NVRAM file layer and store it in an NVRAM file
    let nvramLayers = manifest.layers.filter {
      $0.mediaType == Self.nvramMediaType
    }
    if nvramLayers.count != 1 {
      throw OCIError.ShouldBeExactlyOneLayer
    }
    let nvramData = try await registry.pullBlob(nvramLayers.first!.digest)
    try nvramData.write(to: nvramURL)
  }

  func pushToRegistry(registry: Registry, reference: String) async throws {
    var layers = Array<OCIManifestLayer>()

    // Read VM's config and push it as blob
    let config = try VMConfig(fromURL: configURL)
    let configJSON = try JSONEncoder().encode(config)
    let configDigest = try await registry.pushBlob(fromData: configJSON)
    layers.append(OCIManifestLayer(mediaType: Self.configMediaType, size: configJSON.count, digest: configDigest))

    // Read VM's compressed disk as chunks
    // and sequentially upload them as blobs
    let disk = try FileHandle(forReadingFrom: diskURL)
    let compressingFilter = try InputFilter(.compress, using: .lz4, bufferCapacity: Self.bufferSizeBytes) { _ in
      try disk.read(upToCount: Self.bufferSizeBytes)
    }
    while let chunk = try compressingFilter.readData(ofLength: Self.layerLimitBytes) {
      let chunkDigest = try await registry.pushBlob(fromData: chunk)
      layers.append(OCIManifestLayer(mediaType: Self.diskMediaType, size: chunk.count, digest: chunkDigest))
    }

    // Read VM's NVRAM and push it as blob
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
    _ = try await registry.pushManifest(reference: reference, config: ociConfigDescriptor, layers: layers)
  }
}
