import ArgumentParser
import Foundation

struct Set: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Modify VM's configuration")

  @Argument(help: "VM name")
  var name: String

  @Option(help: "Number of VM CPUs")
  var cpu: UInt16?

  @Option(help: "VM memory size in megabytes")
  var memory: UInt16?

  func run() async throws {
    do {
      let vmStorage = VMStorage()
      let vmDir = try vmStorage.read(name)
      var vmConfig = try VMConfig(fromURL: vmDir.configURL)

      if let cpu = cpu {
        vmConfig.cpuCount = Int(cpu)
      }

      if let memory = memory {
        vmConfig.memorySize = UInt64(memory) * 1024 * 1024
      }

      try vmConfig.save(toURL: vmDir.configURL)

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}
