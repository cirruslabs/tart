import Foundation

// OCI manifest and OCI config media types
let ociManifestMediaType = "application/vnd.oci.image.manifest.v1+json"
let ociConfigMediaType = "application/vnd.oci.image.config.v1+json"

// Layer media types
let configMediaType = "application/vnd.cirruslabs.tart.config.v1"
let diskV1MediaType = "application/vnd.cirruslabs.tart.disk.v1"
let diskV2MediaType = "application/vnd.cirruslabs.tart.disk.v2"
let nvramMediaType = "application/vnd.cirruslabs.tart.nvram.v1"

// Manifest annotations
let uncompressedDiskSizeAnnotation = "org.cirruslabs.tart.uncompressed-disk-size"
let uploadTimeAnnotation = "org.cirruslabs.tart.upload-time"

// Layer annotations
let uncompressedSizeAnnotation = "org.cirruslabs.tart.uncompressed-size"
let uncompressedContentDigestAnnotation = "org.cirruslabs.tart.uncompressed-content-digest"

struct OCIManifest: Codable, Equatable {
  var schemaVersion: Int = 2
  var mediaType: String = ociManifestMediaType
  var config: OCIManifestConfig
  var layers: [OCIManifestLayer] = Array()
  var annotations: Dictionary<String, String>?

  init(config: OCIManifestConfig, layers: [OCIManifestLayer], uncompressedDiskSize: UInt64? = nil, uploadDate: Date? = nil) {
    self.config = config
    self.layers = layers

    var annotations: [String: String] = [:]

    if let uncompressedDiskSize = uncompressedDiskSize {
      annotations[uncompressedDiskSizeAnnotation] = String(uncompressedDiskSize)
    }

    if let uploadDate = uploadDate {
      annotations[uploadTimeAnnotation] = uploadDate.toISO()
    }

    self.annotations = annotations
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
  var architecture: Architecture = .arm64
  var os: OS = .darwin

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
  var annotations: Dictionary<String, String>?

  init(mediaType: String, size: Int, digest: String, uncompressedSize: UInt64? = nil, uncompressedContentDigest: String? = nil) {
    self.mediaType = mediaType
    self.size = size
    self.digest = digest

    var annotations: [String: String] = [:]

    if let uncompressedSize = uncompressedSize {
      annotations[uncompressedSizeAnnotation] = String(uncompressedSize)
    }

    if let uncompressedContentDigest = uncompressedContentDigest {
      annotations[uncompressedContentDigestAnnotation] = uncompressedContentDigest
    }

    self.annotations = annotations
  }

  func uncompressedSize() -> UInt64? {
    guard let value = annotations?[uncompressedSizeAnnotation] else {
      return nil
    }

    return UInt64(value)
  }

  func uncompressedContentDigest() -> String? {
    annotations?[uncompressedContentDigestAnnotation]
  }
}

struct Descriptor: Equatable {
  var size: Int
  var digest: String
}
