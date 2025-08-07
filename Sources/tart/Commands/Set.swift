import ArgumentParser
import Foundation
import Virtualization

struct Set: AsyncParsableCommand {
  static var configuration = CommandConfiguration(commandName: "set", abstract: "Modify VM's configuration")

  @Argument(help: "VM name", completion: .custom(completeLocalMachines))
  var name: String

  @Option(help: "Number of VM CPUs")
  var cpu: UInt16?

  @Option(help: "VM memory size in megabytes")
  var memory: UInt64?

  @Option(help: "VM display resolution in a format of <width>x<height>. For example, 1200x800")
  var display: VMDisplayConfig?

  @Flag(inversion: .prefixedNo, help: ArgumentHelp("Whether to automatically reconfigure the VM's display to fit the window"))
  var displayRefit: Bool? = nil

  @Flag(help: ArgumentHelp("Generate a new random MAC address for the VM."))
  var randomMAC: Bool = false

  #if arch(arm64)
    @Flag(help: ArgumentHelp("Generate a new random serial number for the macOS VM."))
  #endif
  var randomSerial: Bool = false

  @Option(help: ArgumentHelp("Replace the VM's disk contents with the disk contents at path.", valueName: "path"))
  var disk: String?

  @Option(help: ArgumentHelp("Resize the VMs disk to the specified size in GB (note that the disk size can only be increased to avoid losing data)",
                             discussion: """
                             See https://tart.run/faq/#disk-resizing for more details.
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

    vmConfig.displayRefit = displayRefit

    if randomMAC {
      vmConfig.macAddress = VZMACAddress.randomLocallyAdministered()
    }

    #if arch(arm64)
      if randomSerial, let oldPlatform = vmConfig.platform as? Darwin {
        vmConfig.platform = Darwin(ecid: VZMacMachineIdentifier(), hardwareModel: oldPlatform.hardwareModel)
      }
    #endif

    try vmConfig.save(toURL: vmDir.configURL)

    if let disk = disk {
      let temporaryDiskURL = try Config().tartTmpDir.appendingPathComponent("set-disk-\(UUID().uuidString)")

      try FileManager.default.copyItem(atPath: disk, toPath: temporaryDiskURL.path())

      _ = try FileManager.default.replaceItemAt(vmDir.diskURL, withItemAt: temporaryDiskURL)
    }

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
