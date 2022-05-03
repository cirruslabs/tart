import Foundation

struct Config {
  public static let tartHomeDir: URL = FileManager.default
          .homeDirectoryForCurrentUser
          .appendingPathComponent(".tart", isDirectory: true)

  public static let tartCacheDir: URL = tartHomeDir.appendingPathComponent("cache", isDirectory: true)
}
