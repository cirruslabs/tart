import ArgumentParser
import Foundation
import SystemConfiguration

struct Clone: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Clone a VM")

  @Argument(help: "source VM name")
  var sourceName: String

  @Argument(help: "new VM name")
  var newName: String

  func validate() throws {
    if newName.contains("/") {
      throw ValidationError("<new-name> should be a local name")
    }
  }

  func run() async throws {
    do {
      let ociStorage = VMStorageOCI()
      let localStorage = VMStorageLocal()

      if let remoteName = try? RemoteName(sourceName), !ociStorage.exists(remoteName) {
        // Pull the VM in case it's OCI-based and doesn't exist locally yet
        let registry = try Registry(host: remoteName.host, namespace: remoteName.namespace)
        try await ociStorage.pull(remoteName, registry: registry)
      }

      let sourceVM = try VMStorageHelper.open(sourceName)
      let generateMAC = try localStorage.hasVMsWithMACAddress(macAddress: sourceVM.macAddress())

      let tmpVMDir = try VMDirectory.temporary()
      try await withTaskCancellationHandler(operation: {
        try sourceVM.clone(to: tmpVMDir, generateMAC: generateMAC)
        try localStorage.move(newName, from: tmpVMDir)
      }, onCancel: {
        try? FileManager.default.removeItem(at: tmpVMDir.baseURL)
      })

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
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
