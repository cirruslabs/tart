import ArgumentParser
import Foundation

struct Get: AsyncParsableCommand {
  static var configuration = CommandConfiguration(commandName: "get", abstract: "Get a VM's configuration")

  @Argument(help: "VM name")
  var name: String

  @Flag(help: "Number of VM CPUs")
  var cpu: Bool = false

  @Flag(help: "VM memory size in megabytes")
  var memory: Bool = false

  @Flag(help: "Disk size in gigabytes")
  var diskSize: Bool = false

  @Flag(help: "VM display resolution in a format of <width>x<height>. For example, 1200x800")
  var display: Bool = false

  func validate() throws {
    if [cpu, memory, diskSize, display].filter({$0}).count > 1 {
      throw ValidationError("--cpu, --memory, --disk-size and --display are mutually exclusive")
    }
  }

  func run() async throws {
    let vmDir = try VMStorageLocal().open(name)
    let vmConfig = try VMConfig(fromURL: vmDir.configURL)
    let diskSizeInGb = try vmDir.sizeBytes() / 1000 / 1000 / 1000
    let memorySizeInMb = vmConfig.memorySize  / 1024 / 1024

    if cpu {
      print(vmConfig.cpuCount)
    } else if memory {
      print(memorySizeInMb)
    } else if diskSize {
      print(diskSizeInGb)
    } else if display {
      print("\(vmConfig.display.width)x\(vmConfig.display.height)")
    } else {
      print(
        "CPU\tMemory\tDisk\tDisplay\n" +
          "\(vmConfig.cpuCount)\t" +
          "\(memorySizeInMb) MB\t" +
          "\(diskSizeInGb) GB\t" +
          "\(vmConfig.display)"
      )
    }
  }
}
