import Foundation
import CryptoKit

enum DigestError: Error {
  case InvalidOffset
  case InvalidSize
}

class Digest {
  var hash: SHA256 = SHA256()

  func update(_ data: Data) {
    hash.update(data: data)
  }

  func finalize() -> String {
    hash.finalize().hexdigest()
  }

  static func hash(_ data: Data) -> String {
    SHA256.hash(data: data).hexdigest()
  }

  static func hash(_ url: URL) throws -> String {
    hash(try Data(contentsOf: url))
  }

  static func hash(_ url: URL, offset: UInt64, size: UInt64) throws -> String {
    // Sanity check
    let fhSanity = try FileHandle(forReadingFrom: url)
    try fhSanity.seekToEnd()
    let fileSize = try fhSanity.offset()
    try fhSanity.close()

    if offset > fileSize {
      throw DigestError.InvalidOffset
    }

    if (offset + size) > fileSize {
      throw DigestError.InvalidSize
    }

    // Read a chunk of size ``size`` at offset ``offset``
    // and calculate it's digest
    let fh = try FileHandle(forReadingFrom: url)
    defer { try! fh.close() }

    try fh.seek(toOffset: offset)

    let data = try fh.read(upToCount: Int(size))!

    return hash(data)
  }
}

extension SHA256.Digest {
  func hexdigest() -> String {
    "sha256:" + self.map {
      String(format: "%02x", $0)
    }
    .joined()
  }
}
