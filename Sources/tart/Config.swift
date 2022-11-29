import Foundation

struct Config {
  let tartHomeDir: URL
  let tartCacheDir: URL
  let tartTmpDir: URL

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

    tartTmpDir = tartHomeDir.appendingPathComponent("tmp", isDirectory: true)
    try FileManager.default.createDirectory(at: tartTmpDir, withIntermediateDirectories: true)
  }

  func gc() throws {
    for entry in try FileManager.default.contentsOfDirectory(at: tartTmpDir,
                                                             includingPropertiesForKeys: [], options: []) {
      let lock = try FileLock(lockURL: entry)
      if try !lock.trylock() {
        continue
      }

      try FileManager.default.removeItem(at: entry)

      try lock.unlock()
    }
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
