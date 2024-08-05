import Foundation

struct LocalLayerCache {
  struct DigestInfo {
    let range: Range<Data.Index>
    let compressedDigest: String
    let uncompressedContentDigest: String?
  }

  let name: String
  let deduplicatedBytes: UInt64
  let diskURL: URL

  private let mappedDisk: Data
  private var digestToRange: [String: DigestInfo] = [:]
  private var offsetToRange: [UInt64: DigestInfo] = [:]

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

      let info = DigestInfo(
        range: Int(offset)..<Int(offset + uncompressedSize),
        compressedDigest: layer.digest,
        uncompressedContentDigest: layer.uncompressedContentDigest()!
      )
      self.digestToRange[layer.digest] = info
      self.offsetToRange[offset] = info

      offset += uncompressedSize
    }
  }

  func findInfo(digest: String, offsetHint: UInt64) -> DigestInfo? {
    // Layers can have the same digests, for example, empty ones. Let's use the offset hint to make a better guess.
    if let info = self.offsetToRange[offsetHint], info.compressedDigest == digest {
      return info
    }
    return self.digestToRange[digest]
  }

  func subdata(_ range: Range<Data.Index>) -> Data {
    return self.mappedDisk.subdata(in: range)
  }
}
