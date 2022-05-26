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

  @Option(help: "VM display resolution in a format of <width>x<height>. For example, 1200x800")
  var display: VMDisplayConfig?

  @Option(help: .hidden)
  var diskSize: UInt8?

  func run() async throws {
    do {
      let vmDir = try VMStorageLocal().open(name)
      var vmConfig = try VMConfig(fromURL: vmDir.configURL)

      if let cpu = cpu {
        try vmConfig.setCPU(cpuCount: Int(cpu))
      }

      if let memory = memory {
        try vmConfig.setMemory(memorySize: UInt64(memory) * 1024 * 1024)
      }

      if let display = display {
        if (display.width > 0) {
          vmConfig.display.width = display.width
        }
        if (display.height > 0) {
          vmConfig.display.height = display.height
        }
      }

      try vmConfig.save(toURL: vmDir.configURL)

      if diskSize != nil {
        try vmDir.resizeDisk(diskSize!)
      }

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}

extension VMDisplayConfig: ExpressibleByArgument {
  public init(argument: String) {
    let parts = argument.components(separatedBy: "x").map {
      Int($0) ?? 0
    }
    self = VMDisplayConfig(
      width: parts[safe: 0] ?? 0,
      height: parts[safe: 1] ?? 0
    )
  }
}
