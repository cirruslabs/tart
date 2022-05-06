import ArgumentParser
import Foundation
import SystemConfiguration

struct Clone: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Clone a VM")

  @Argument(help: "source VM name")
  var sourceName: String

  @Argument(help: "new VM name")
  var newName: String

  func run() async throws {
    do {
      if let remoteName = try? RemoteName(sourceName) {
        if !VMStorageOCI().exists(remoteName) {
          // Pull the VM in case it's OCI-based and doesn't exist locally yet
          let registry = try Registry(host: remoteName.host, namespace: remoteName.namespace)
          try await VMStorageOCI().pull(remoteName, registry: registry)
        }
        let removeVM = try VMStorageHelper.open(sourceName)

        let removeConfig = try VMConfig.init(fromURL: removeVM.configURL)
        let needToGenerateNewMAC = try localVMExistsWith(macAddress: removeConfig.macAddress.string)

        try removeVM.clone(to: VMStorageLocal().create(newName), generateMAC: needToGenerateNewMAC)
      } else {
        try VMStorageHelper.open(sourceName).clone(to: VMStorageLocal().create(newName), generateMAC: true)
      }

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }

  private func localVMExistsWith(macAddress: String) throws -> Bool {
    var needToGenerateNewMAC = false
    for (_, localDir) in try VMStorageLocal().list() {
      let localConfig = try VMConfig.init(fromURL: localDir.configURL)
      if localConfig.macAddress.string == macAddress {
        needToGenerateNewMAC = true
      }
    }
    return needToGenerateNewMAC
  }
}
