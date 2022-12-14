import ArgumentParser
import Foundation
import SystemConfiguration

struct Clone: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Clone a VM")

  @Argument(help: "source VM name")
  var sourceName: String

  @Argument(help: "new VM name")
  var newName: String

  @Flag(help: "connect to the OCI registry via insecure HTTP protocol")
  var insecure: Bool = false

  func validate() throws {
    if newName.contains("/") {
      throw ValidationError("<new-name> should be a local name")
    }
  }

  func run() async throws {
    let ociStorage = VMStorageOCI()
    let localStorage = VMStorageLocal()

    if let remoteName = try? RemoteName(sourceName), !ociStorage.exists(remoteName) {
      // Pull the VM in case it's OCI-based and doesn't exist locally yet
      let registry = try Registry(host: remoteName.host, namespace: remoteName.namespace, insecure: insecure)
      try await ociStorage.pull(remoteName, registry: registry)
    }

    let sourceVM = try VMStorageHelper.open(sourceName)

    let tmpVMDir = try VMDirectory.temporary()

    // Lock the temporary VM directory to prevent it's garbage collection
    let tmpVMDirLock = try FileLock(lockURL: tmpVMDir.baseURL)
    try tmpVMDirLock.lock()

    try await withTaskCancellationHandler(operation: {
      let lock = try FileLock(lockURL: Config().tartHomeDir)
      try lock.lock()

      let generateMAC = try localStorage.hasVMsWithMACAddress(macAddress: sourceVM.macAddress())
      try sourceVM.clone(to: tmpVMDir, generateMAC: generateMAC)
      try localStorage.move(newName, from: tmpVMDir)

      try lock.unlock()
    }, onCancel: {
      try? FileManager.default.removeItem(at: tmpVMDir.baseURL)
    })
  }
}

fileprivate extension VMDirectory {
  func macAddress() throws -> String {
    try VMConfig(fromURL: configURL).macAddress.string
  }
}

fileprivate extension VMStorageLocal {
  func hasVMsWithMACAddress(macAddress: String) throws -> Bool {
    try list().contains { try $1.macAddress() == macAddress }
  }
}
