import Foundation

package extension Collection {
  subscript (safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

package func resolveBinaryPath(_ name: String) -> URL? {
  guard let path = ProcessInfo.processInfo.environment["PATH"] else {
    return nil
  }

  for pathComponent in path.split(separator: ":") {
    let url = URL(fileURLWithPath: String(pathComponent))
      .appendingPathComponent(name, isDirectory: false)

    if FileManager.default.fileExists(atPath: url.path) {
      return url
    }
  }

  return nil
}

package func jsonEncoder() -> JSONEncoder {
  let encoder = JSONEncoder()

  encoder.outputFormatting = [.sortedKeys]

  return encoder
}

package func jsonDecoder() -> JSONDecoder {
  JSONDecoder()
}
