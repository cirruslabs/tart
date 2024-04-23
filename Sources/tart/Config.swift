import Foundation
import TartEngine

struct Config: ConfigProtocol {
  let tartHomeDir: URL
  let tartCacheDir: URL
  let tartTmpDir: URL

  var tartCacheIPSWsDir: URL {
    tartCacheDir.appendingPathComponent("IPSWs", isDirectory: true)
  }

  var tartCacheOCIsDir: URL {
    tartCacheDir.appendingPathComponent("OCIs", isDirectory: true)
  }

  var tartVMsDir: URL {
    tartHomeDir.appendingPathComponent("vms", isDirectory: true)
  }

  static let processConfig = try! Config()

  private init() throws {
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
  
}
