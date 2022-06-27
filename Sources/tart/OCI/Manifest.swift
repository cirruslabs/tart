import Foundation

let ociManifestMediaType = "application/vnd.oci.image.manifest.v1+json"
let ociConfigMediaType = "application/vnd.oci.image.config.v1+json"

// Annotations
let uncompressedDiskSizeAnnotation = "org.cirruslabs.tart.uncompressed-disk-size"

struct OCIManifest: Codable, Equatable {
  var schemaVersion: Int = 2
  var mediaType: String = ociManifestMediaType
  var config: OCIManifestConfig
  var layers: [OCIManifestLayer] = Array()
  var annotations: Dictionary<String, String>?

  init(config: OCIManifestConfig, layers: [OCIManifestLayer], uncompressedDiskSize: UInt64? = nil) {
    self.config = config
    self.layers = layers

    if let uncompressedDiskSize = uncompressedDiskSize {
      annotations = [
        uncompressedDiskSizeAnnotation: String(uncompressedDiskSize)
      ]
    }
  }

  init(fromJSON: Data) throws {
    self = try Config.jsonDecoder().decode(Self.self, from: fromJSON)
  }

  func toJSON() throws -> Data {
    try Config.jsonEncoder().encode(self)
  }

  func digest() throws -> String {
    try Digest.hash(toJSON())
  }

  func uncompressedDiskSize() -> UInt64? {
    guard let value = annotations?[uncompressedDiskSizeAnnotation] else {
      return nil
    }

    return UInt64(value)
  }
}

struct OCIConfig: Codable {
  var architecture: String = "arm64"
  var os: String = "darwin"

  func toJSON() throws -> Data {
    try Config.jsonEncoder().encode(self)
  }
}

struct OCIManifestConfig: Codable, Equatable {
  var mediaType: String = ociConfigMediaType
  var size: Int
  var digest: String
}

struct OCIManifestLayer: Codable, Equatable {
  var mediaType: String
  var size: Int
  var digest: String
}

struct Descriptor: Equatable {
  var size: Int
  var digest: String
}
