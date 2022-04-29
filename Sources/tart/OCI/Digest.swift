import Foundation
import CryptoKit

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
}

extension SHA256.Digest {
  func hexdigest() -> String {
    "sha256:" + self.map {
              String(format: "%02x", $0)
            }
            .joined()
  }
}
