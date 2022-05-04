import Foundation
import Virtualization

struct UninitializedVMDirectoryError: Error {
}

struct AlreadyInitializedVMDirectoryError: Error {
}

struct VMDirectory {
  var baseURL: URL

  var configURL: URL {
    baseURL.appendingPathComponent("config.json")
  }
  var diskURL: URL {
    baseURL.appendingPathComponent("disk.img")
  }
  var nvramURL: URL {
    baseURL.appendingPathComponent("nvram.bin")
  }

  var name: String {
    baseURL.lastPathComponent
  }

  var initialized: Bool {
    FileManager.default.fileExists(atPath: configURL.path) &&
      FileManager.default.fileExists(atPath: diskURL.path) &&
      FileManager.default.fileExists(atPath: nvramURL.path)
  }

  func initialize(overwrite: Bool = false) throws {
    if !overwrite && initialized {
      throw AlreadyInitializedVMDirectoryError()
    }

    try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)

    try? FileManager.default.removeItem(at: configURL)
    try? FileManager.default.removeItem(at: diskURL)
    try? FileManager.default.removeItem(at: nvramURL)
  }

  func validate() throws {
    if !initialized {
      throw UninitializedVMDirectoryError()
    }
  }

  func clone(to: VMDirectory, generateMAC: Bool) throws {
    try FileManager.default.copyItem(at: configURL, to: to.configURL)
    try FileManager.default.copyItem(at: nvramURL, to: to.nvramURL)
    try FileManager.default.copyItem(at: diskURL, to: to.diskURL)

    // Re-generate MAC address
    var newVMConfig = try VMConfig(fromURL: to.configURL)
    if generateMAC {
      newVMConfig.macAddress = VZMACAddress.randomLocallyAdministered()
    }
    try newVMConfig.save(toURL: to.configURL)
  }

  func resizeDisk(_ sizeGB: UInt8) throws {
    if !FileManager.default.fileExists(atPath: diskURL.path) {
      FileManager.default.createFile(atPath: diskURL.path, contents: nil, attributes: nil)
    }
    let diskFileHandle = try FileHandle.init(forWritingTo: diskURL)
    // macOS considers kilo being 1000 and not 1024
    try diskFileHandle.truncate(atOffset: UInt64(sizeGB) * 1000 * 1000 * 1000)
    try diskFileHandle.close()
  }
}
