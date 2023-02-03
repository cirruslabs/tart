import ArgumentParser
import Foundation

fileprivate struct VMInfo: Encodable {
  let CPU: Int
  let Memory: UInt64
  let Disk: Int
  let Display: String
  let Running: Bool
}

struct Get: AsyncParsableCommand {
  static var configuration = CommandConfiguration(commandName: "get", abstract: "Get a VM's configuration")

  @Argument(help: "VM name.")
  var name: String

  @Flag(help: "Output format")
  var format: Format = .table

  func run() async throws {
    let vmDir = try VMStorageLocal().open(name)
    let vmConfig = try VMConfig(fromURL: vmDir.configURL)
    let diskSizeInGb = try vmDir.sizeGB()
    let memorySizeInMb = vmConfig.memorySize / 1024 / 1024
    let running = try PIDLock(lockURL: vmDir.configURL).pid() > 0

    let info = VMInfo(CPU: vmConfig.cpuCount, Memory: memorySizeInMb, Disk: diskSizeInGb, Display: vmConfig.display.description, Running: running)
    print(format.renderSingle(info))
  }
}
