import ArgumentParser
import Foundation

struct Get: AsyncParsableCommand {
  static var configuration = CommandConfiguration(commandName: "get", abstract: "Get a VM's configuration")

  @Argument(help: "VM name")
  var name: String

  func run() async throws {
    do {
      let vmDir = try VMStorageLocal().open(name)
      let vmConfig = try VMConfig(fromURL: vmDir.configURL)
      let diskSize = try vmDir.sizeBytes() / 1000 / 1000 / 1000

      print("CPU\tMemory\tDisk\tDisplay")

      var s = "\(vmConfig.cpuCount)\t"
      s += "\(vmConfig.memorySize / 1024 / 1024) MB\t"
      s += "\(diskSize) GB\t"
      s += "\(vmConfig.display.width)x\(vmConfig.display.height)"
      print(s)

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}
