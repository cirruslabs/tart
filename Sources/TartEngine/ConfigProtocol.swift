import Foundation

public protocol ConfigProtocol {
  var tartHomeDir: URL { get }
  var tartCacheDir: URL { get }
  var tartTmpDir: URL { get }
}

public extension ConfigProtocol {
  var tartCacheIPSWsDir: URL {
    tartCacheDir.appendingPathComponent("IPSWs", isDirectory: true)
  }

  var tartCacheOCIsDir: URL {
    tartCacheDir.appendingPathComponent("OCIs", isDirectory: true)
  }

  var tartVMsDir: URL {
    tartHomeDir.appendingPathComponent("vms", isDirectory: true)
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
}
