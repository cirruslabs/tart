import Foundation

let ociManifestMediaType = "application/vnd.oci.image.manifest.v1+json"
let ociConfigMediaType = "application/vnd.oci.image.config.v1+json"

struct OCIManifest: Encodable, Decodable, Equatable {
  var schemaVersion: Int = 2
  var mediaType: String = ociManifestMediaType
  var config: OCIManifestConfig
  var layers: [OCIManifestLayer] = Array()
}

struct OCIManifestConfig: Encodable, Decodable, Equatable {
  var mediaType: String = ociConfigMediaType
  var size: Int
  var digest: String
}

struct OCIManifestLayer: Encodable, Decodable, Equatable {
  var mediaType: String
  var size: Int
  var digest: String
}

struct Descriptor: Equatable {
  var size: Int
  var digest: String
}
