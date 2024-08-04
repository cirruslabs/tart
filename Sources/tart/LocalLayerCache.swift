import Foundation

struct LocalLayerCache {
  struct DigestInfo {
    let range: Range<Data.Index>
    let uncompressedContentDigest: String?
  }

  let name: String
  let deduplicatedBytes: UInt64
  let diskURL: URL

  private let mappedDisk: Data
  private var digestToRange: [String : DigestInfo] = [:]

  init?(_ name: String, _ deduplicatedBytes: UInt64, _ diskURL: URL, _ manifest: OCIManifest) throws {
    self.name = name
    self.deduplicatedBytes = deduplicatedBytes
    self.diskURL = diskURL

    // mmap(2) the disk that contains the layers from the manifest
    self.mappedDisk = try Data(contentsOf: diskURL, options: [.alwaysMapped])

    // Record the ranges of the disk layers listed in the manifest
    var offset: UInt64 = 0

    for layer in manifest.layers.filter({ $0.mediaType == diskV2MediaType }) {
      guard let uncompressedSize = layer.uncompressedSize() else {
        return nil
      }

      self.digestToRange[layer.digest] = DigestInfo(
        range: Int(offset)..<Int(offset+uncompressedSize),
        uncompressedContentDigest: layer.uncompressedContentDigest()!
      )

      offset += uncompressedSize
    }
  }

  func findInfo(_ digest: String) -> DigestInfo? {
    return self.digestToRange[digest]
  }

  func subdata(_ range: Range<Data.Index>) -> Data {
    return self.mappedDisk.subdata(in: range)
  }
}
