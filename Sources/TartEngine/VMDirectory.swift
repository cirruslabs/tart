import Foundation
import Virtualization
import CryptoKit

package struct VMDirectory: Prunable {
  package enum State: String {
    case Running = "running"
    case Suspended = "suspended"
    case Stopped = "stopped"
  }

  package var baseURL: URL

  package var configURL: URL {
    baseURL.appendingPathComponent("config.json")
  }
  package var diskURL: URL {
    baseURL.appendingPathComponent("disk.img")
  }
  package var nvramURL: URL {
    baseURL.appendingPathComponent("nvram.bin")
  }
  package var stateURL: URL {
    baseURL.appendingPathComponent("state.vzvmsave")
  }

  package var explicitlyPulledMark: URL {
    baseURL.appendingPathComponent(".explicitly-pulled")
  }

  package var name: String {
    baseURL.lastPathComponent
  }

  package var url: URL {
    baseURL
  }

  package func lock() throws -> PIDLock {
    try PIDLock(lockURL: configURL)
  }

  package func running() throws -> Bool {
    // The most common reason why PIDLock() instantiation fails is a race with "tart delete" (ENOENT),
    // which is fine to report as "not running".
    //
    // The other reasons are unlikely and the cost of getting a false positive is way less than
    // the cost of crashing with an exception when calling "tart list" on a busy machine, for example.
    guard let lock = try? lock() else {
      return false
    }

    return try lock.pid() != 0
  }

  package func state() throws -> State {
    if try running() {
      return State.Running
    } else if FileManager.default.fileExists(atPath: stateURL.path) {
      return State.Suspended
    } else {
      return State.Stopped
    }
  }

  package static func temporary(config: any ConfigProtocol) throws -> VMDirectory {
    let tmpDir = config.tartTmpDir.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: false)

    return VMDirectory(baseURL: tmpDir)
  }

  //Create tmp directory with hashing
  static func temporaryDeterministic(key: String, config: any ConfigProtocol) throws -> VMDirectory {
    let keyData = Data(key.utf8)
    let hash = Insecure.MD5.hash(data: keyData)
    // Convert hash to string
    let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
    let tmpDir = config.tartTmpDir.appendingPathComponent(hashString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    return VMDirectory(baseURL: tmpDir)
  }

  package var initialized: Bool {
    FileManager.default.fileExists(atPath: configURL.path) &&
      FileManager.default.fileExists(atPath: diskURL.path) &&
      FileManager.default.fileExists(atPath: nvramURL.path)
  }

  package func initialize(overwrite: Bool = false) throws {
    if !overwrite && initialized {
      throw RuntimeError.VMDirectoryAlreadyInitialized("VM directory is already initialized, preventing overwrite")
    }

    try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)

    try? FileManager.default.removeItem(at: configURL)
    try? FileManager.default.removeItem(at: diskURL)
    try? FileManager.default.removeItem(at: nvramURL)
  }

  package func validate(userFriendlyName: String) throws {
    if !FileManager.default.fileExists(atPath: baseURL.path) {
      throw RuntimeError.VMDoesNotExist(name: userFriendlyName)
    }

    if !initialized {
      throw RuntimeError.VMMissingFiles("VM is missing some of its files (\(configURL.lastPathComponent),"
        + " \(diskURL.lastPathComponent) or \(nvramURL.lastPathComponent))")
    }
  }

  package func clone(to: VMDirectory, generateMAC: Bool) throws {
    try FileManager.default.copyItem(at: configURL, to: to.configURL)
    try FileManager.default.copyItem(at: nvramURL, to: to.nvramURL)
    try FileManager.default.copyItem(at: diskURL, to: to.diskURL)
    try? FileManager.default.copyItem(at: stateURL, to: to.stateURL)

    // Re-generate MAC address
    if generateMAC {
      try to.regenerateMACAddress()
    }
  }

  package func macAddress() throws -> String {
    try VMConfig(fromURL: configURL).macAddress.string
  }

  package func regenerateMACAddress() throws {
    var vmConfig = try VMConfig(fromURL: configURL)

    vmConfig.macAddress = VZMACAddress.randomLocallyAdministered()
    // cleanup state if any
    try? FileManager.default.removeItem(at: stateURL)

    try vmConfig.save(toURL: configURL)
  }

  package func resizeDisk(_ sizeGB: UInt16) throws {
    if !FileManager.default.fileExists(atPath: diskURL.path) {
      FileManager.default.createFile(atPath: diskURL.path, contents: nil, attributes: nil)
    }

    let diskFileHandle = try FileHandle.init(forWritingTo: diskURL)
    let currentDiskFileLength = try diskFileHandle.seekToEnd()
    let desiredDiskFileLength = UInt64(sizeGB) * 1000 * 1000 * 1000
    if desiredDiskFileLength < currentDiskFileLength {
      let currentLengthHuman = ByteCountFormatter().string(fromByteCount: Int64(currentDiskFileLength))
      let desiredLengthHuman = ByteCountFormatter().string(fromByteCount: Int64(desiredDiskFileLength))
      throw RuntimeError.InvalidDiskSize("new disk size of \(desiredLengthHuman) should be larger " +
        "than the current disk size of \(currentLengthHuman)")
    } else if desiredDiskFileLength > currentDiskFileLength {
      try diskFileHandle.truncate(atOffset: desiredDiskFileLength)
    }
    try diskFileHandle.close()
  }

  package func delete() throws {
    let lock = try lock()

    if try !lock.trylock() {
      throw RuntimeError.VMIsRunning(name)
    }

    try FileManager.default.removeItem(at: baseURL)

    try lock.unlock()
  }

  package func accessDate() throws -> Date {
    try baseURL.accessDate()
  }

  package func allocatedSizeBytes() throws -> Int {
    try configURL.allocatedSizeBytes() + diskURL.allocatedSizeBytes() + nvramURL.allocatedSizeBytes()
  }

  package func allocatedSizeGB() throws -> Int {
    try allocatedSizeBytes() / 1000 / 1000 / 1000
  }

  package func sizeBytes() throws -> Int {
    try configURL.sizeBytes() + diskURL.sizeBytes() + nvramURL.sizeBytes()
  }

  package func sizeGB() throws -> Int {
    try sizeBytes() / 1000 / 1000 / 1000
  }

  package func markExplicitlyPulled() {
    FileManager.default.createFile(atPath: explicitlyPulledMark.path, contents: nil)
  }

  package func isExplicitlyPulled() -> Bool {
    FileManager.default.fileExists(atPath: explicitlyPulledMark.path)
  }
}
