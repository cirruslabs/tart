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
      let diskSize = try vmDir.sizeBytes() / 1024 / 1024 / 1000

      print("""
            cpu cores: \(vmConfig.cpuCount)
            memory:    \(vmConfig.memorySize / 1024 / 1024)
            disk size: \(diskSize) GB
            display:   \(vmConfig.display.width) x \(vmConfig.display.height)
            """)

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}
