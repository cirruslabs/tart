import Foundation

struct Config {
  let tartHomeDir: URL
  let tartCacheDir: URL

  init() throws {
    var tartHomeDir: URL

    if let customTartHome = ProcessInfo.processInfo.environment["TART_HOME"] {
      tartHomeDir = URL(fileURLWithPath: customTartHome)
    } else {
      tartHomeDir = FileManager.default
              .homeDirectoryForCurrentUser
              .appendingPathComponent(".tart", isDirectory: true)
    }

    self.tartHomeDir = tartHomeDir
    tartCacheDir = tartHomeDir.appendingPathComponent("cache", isDirectory: true)

    try FileManager.default.createDirectory(at: tartCacheDir, withIntermediateDirectories: true)
  }

  static func jsonEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()

    encoder.outputFormatting = [.sortedKeys]

    return encoder
  }

  static func jsonDecoder() -> JSONDecoder {
    JSONDecoder()
  }
}
