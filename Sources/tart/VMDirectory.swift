import Foundation
import Virtualization
import CryptoKit

struct VMDirectory: Prunable {
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
  var stateURL: URL {
    baseURL.appendingPathComponent("state.vzvmsave")
  }

  var explicitlyPulledMark: URL {
    baseURL.appendingPathComponent(".explicitly-pulled")
  }

  var name: String {
    baseURL.lastPathComponent
  }

  var url: URL {
    baseURL
  }

  func running() throws -> Bool {
    // The most common reason why PIDLock() instantiation fails is a race with "tart delete" (ENOENT),
    // which is fine to report as "not running".
    //
    // The other reasons are unlikely and the cost of getting a false positive is way less than
    // the cost of crashing with an exception when calling "tart list" on a busy machine, for example.
    guard let lock = try? PIDLock(lockURL: configURL) else {
      return false
    }

    return try lock.pid() != 0
  }

  func state() throws -> String {
    if try running() {
      return "running"
    } else if FileManager.default.fileExists(atPath: stateURL.path) {
      return "suspended"
    } else {
      return "stopped"
    }
  }

  static func temporary() throws -> VMDirectory {
    let tmpDir = try Config().tartTmpDir.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: false)

    return VMDirectory(baseURL: tmpDir)
  }

  //Create tmp directory with hashing
  static func temporaryDeterministic(key: String) throws -> VMDirectory {
    let keyData = Data(key.utf8)
    let hash = Insecure.MD5.hash(data: keyData)
    // Convert hash to string
    let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
    let tmpDir = try Config().tartTmpDir.appendingPathComponent(hashString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    return VMDirectory(baseURL: tmpDir)
  }

  var initialized: Bool {
    FileManager.default.fileExists(atPath: configURL.path) &&
      FileManager.default.fileExists(atPath: diskURL.path) &&
      FileManager.default.fileExists(atPath: nvramURL.path)
  }

  func initialize(overwrite: Bool = false) throws {
    if !overwrite && initialized {
      throw RuntimeError.VMDirectoryAlreadyInitialized("VM directory is already initialized, preventing overwrite")
    }

    try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)

    try? FileManager.default.removeItem(at: configURL)
    try? FileManager.default.removeItem(at: diskURL)
    try? FileManager.default.removeItem(at: nvramURL)
  }

  func validate(userFriendlyName: String) throws {
    if !FileManager.default.fileExists(atPath: baseURL.path) {
      throw RuntimeError.VMDoesNotExist(name: userFriendlyName)
    }

    if !initialized {
      throw RuntimeError.VMMissingFiles("VM is missing some of its files (\(configURL.lastPathComponent),"
        + " \(diskURL.lastPathComponent) or \(nvramURL.lastPathComponent))")
    }
  }

  func clone(to: VMDirectory, generateMAC: Bool) throws {
    try FileManager.default.copyItem(at: configURL, to: to.configURL)
    try FileManager.default.copyItem(at: nvramURL, to: to.nvramURL)
    try FileManager.default.copyItem(at: diskURL, to: to.diskURL)
    try? FileManager.default.copyItem(at: stateURL, to: to.stateURL)

    // Re-generate MAC address
    if generateMAC {
      try to.regenerateMACAddress()
    }
  }

  func macAddress() throws -> String {
    try VMConfig(fromURL: configURL).macAddress.string
  }

  func regenerateMACAddress() throws {
    var vmConfig = try VMConfig(fromURL: configURL)

    vmConfig.macAddress = VZMACAddress.randomLocallyAdministered()
    // cleanup state if any
    try? FileManager.default.removeItem(at: stateURL)

    try vmConfig.save(toURL: configURL)
  }

  func resizeDisk(_ sizeGB: UInt16) throws {
    if !FileManager.default.fileExists(atPath: diskURL.path) {
      FileManager.default.createFile(atPath: diskURL.path, contents: nil, attributes: nil)
    }
    let diskFileHandle = try FileHandle.init(forWritingTo: diskURL)
    // macOS considers kilo being 1000 and not 1024
    try diskFileHandle.truncate(atOffset: UInt64(sizeGB) * 1000 * 1000 * 1000)
    try diskFileHandle.close()
  }

  func delete() throws {
    try FileManager.default.removeItem(at: baseURL)
  }

  func accessDate() throws -> Date {
    try baseURL.accessDate()
  }

  func sizeBytes() throws -> Int {
    try configURL.sizeBytes() + diskURL.sizeBytes() + nvramURL.sizeBytes()
  }

  func sizeGB() throws -> Int {
    try sizeBytes() / 1000 / 1000 / 1000
  }

  func markExplicitlyPulled() {
    FileManager.default.createFile(atPath: explicitlyPulledMark.path, contents: nil)
  }

  func isExplicitlyPulled() -> Bool {
    FileManager.default.fileExists(atPath: explicitlyPulledMark.path)
  }
}
