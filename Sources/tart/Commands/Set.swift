import ArgumentParser
import Foundation

struct Set: AsyncParsableCommand {
  static var configuration = CommandConfiguration(commandName: "set", abstract: "Modify VM's configuration")

  @Argument(help: "VM name")
  var name: String

  @Option(help: "Number of VM CPUs")
  var cpu: UInt16?

  @Option(help: "VM memory size in megabytes")
  var memory: UInt64?

  @Option(help: "VM display resolution in a format of <width>x<height>. For example, 1200x800")
  var display: VMDisplayConfig?

  @Option(help: ArgumentHelp("Resize the VMs disk to the specified size in GB (note that the disk size can only be increased to avoid losing data",
                             discussion: """
                             Disk resizing works on most cloud-ready Linux distributions out-of-the box (e.g. Ubuntu Cloud Images
                             have the \"cloud-initramfs-growroot\" package installed that runs on boot) and on the rest of the
                             distributions by running the \"growpart\" or \"resize2fs\" commands.

                             For macOS, however, things are a bit more complicated: you need to remove the recovery partition
                             first and then run various \"diskutil\" commands, see Tart's packer plugin source code for more
                             details[1].

                             [1]: https://github.com/cirruslabs/packer-plugin-tart/blob/main/builder/tart/step_disk_resize.go
                             """))
  var diskSize: UInt16?

  func run() async throws {
    let vmDir = try VMStorageLocal().open(name)
    var vmConfig = try VMConfig(fromURL: vmDir.configURL)

    if let cpu = cpu {
      try vmConfig.setCPU(cpuCount: Int(cpu))
    }

    if let memory = memory {
      try vmConfig.setMemory(memorySize: memory * 1024 * 1024)
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
