import ArgumentParser
import Dispatch
import SwiftUI
import Virtualization

var vm: VM?

struct IPNotFound: Error {
}

struct Run: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Run a VM")

  @Argument(help: "VM name")
  var name: String

  @Flag(help: ArgumentHelp(
          "Don't open a UI window.",
          discussion: "Useful for integrating Tart VMs into other tools.\nUse `tart ip` in order to get an IP for SSHing or VNCing into the VM.")) 
  var noGraphics: Bool = false

  @Flag(help: "Force open a UI window, even when VNC is enabled.")
  var graphics: Bool = false

  @Flag(help: "Boot into recovery mode") 
  var recovery: Bool = false
  
  @Flag(help: ArgumentHelp(
          "Use screen sharing instead of the built-in UI.",
          discussion: "Useful since Screen Sharing supports copy/paste, drag and drop, etc.\n"
            + "Note that Remote Login option should be enabled inside the VM."))
  var vnc: Bool = false

  @Flag(help: ArgumentHelp(
    "Use Virtualization.Framework's VNC server instead of the build-in UI.",
    discussion: "Useful since this type of VNC is available in recovery mode and in macOS installation.\n"
      + "Note that this feature is experimental and there may be bugs present when using VNC."))
  var vncExperimental: Bool = false

  @Flag(help: ArgumentHelp(visibility: .private))
  var withSoftnet: Bool = false

  @Option(help: ArgumentHelp("""
    Additional disk attachments with an optional read-only specifier\n(e.g. --disk=\"disk.bin\" --disk=\"ubuntu.iso:ro\")
    """, discussion: """
    Learn how to create a disk image using Disk Utility here:
    https://support.apple.com/en-gb/guide/disk-utility/dskutl11888/mac
    """, valueName: "path[:ro]"))
  var disk: [String] = []

  @Option(name: [.customLong("rosetta")], help: ArgumentHelp(
    "Attaches a Rosetta share to the guest Linux VM with a specific tag (e.g. --rosetta=\"rosetta\")",
    discussion: """
                Requires host to be macOS 13.0 (Ventura) with Rosetta installed. The latter can be done
                by running "softwareupdate --install-rosetta" (without quotes) in the Terminal.app.

                Note that you also have to configure Rosetta in the guest Linux VM by following the
                steps from "Mount the Shared Directory and Register Rosetta" section here:
                https://developer.apple.com/documentation/virtualization/running_intel_binaries_in_linux_vms_with_rosetta#3978496
                """,
    valueName: "tag"
  ))
  var rosettaTag: String?

  @Option(help: ArgumentHelp("""
                             Additional directory shares with an optional read-only specifier\n(e.g. --dir=\"build:~/src/build\" --dir=\"sources:~/src/sources:ro\")
                             """, discussion: """
                                              Requires host to be macOS 13.0 (Ventura) or newer.
                                              All shared directories are automatically mounted to "/Volumes/My Shared Files" directory on macOS,
                                              while on Linux you have to do it manually: "mount -t virtiofs com.apple.virtio-fs.automount /mount/point".
                                              For macOS guests, they must be running macOS 13.0 (Ventura) or newer.
                                              """, valueName: "name:path[:ro]"))
  var dir: [String] = []

  @Option(help: ArgumentHelp("""
                             Use bridged networking instead of the default shared (NAT) networking \n(e.g. --net-bridged=en0 or --net-bridged=\"Wi-Fi\")
                             """, discussion: """
                                              Specify "list" as an interface name (--net-bridged=list) to list the available bridged interfaces.
                                              """, valueName: "interface name"))
  var netBridged: String?

  @Flag(help: ArgumentHelp("Use software networking instead of the default shared (NAT) networking",
          discussion: "Learn how to configure Softnet for use with Tart here: https://github.com/cirruslabs/softnet"))
  var netSoftnet: Bool = false

  func validate() throws {
    if vnc && vncExperimental {
      throw ValidationError("--vnc and --vnc-experimental are mutually exclusive")
    }

    if withSoftnet && netBridged != nil {
      throw ValidationError("--with-softnet and --net-bridged are mutually exclusive")
    }

    if netBridged != nil && netSoftnet {
      throw ValidationError("--net-bridged and --net-softnet are mutually exclusive")
    }

    if graphics && noGraphics {
      throw ValidationError("--graphics and --no-graphics are mutually exclusive")
    }
  }

  @MainActor
  func run() async throws {
    let vmDir = try VMStorageLocal().open(name)
    vm = try VM(
      vmDir: vmDir,
      network: userSpecifiedNetwork(vmDir: vmDir) ?? NetworkShared(),
      additionalDiskAttachments: additionalDiskAttachments(),
      directorySharingDevices: directoryShares() + rosettaDirectoryShare()
    )

    let vncImpl: VNC? = try {
      if vnc {
        let vmConfig = try VMConfig.init(fromURL: vmDir.configURL)
        return ScreenSharingVNC(vmConfig: vmConfig)
      } else if vncExperimental {
        return FullFledgedVNC(virtualMachine: vm!.virtualMachine)
      } else {
        return nil
      }
    }()

    // Lock the VM
    //
    // More specifically, lock the "config.json", because we can't lock
    // directories with fcntl(2)-based locking and we better not interfere
    // with the VM's disk and NVRAM, because they are opened (and even seem
    // to be locked) directly by the Virtualization.Framework's process.
    //
    // Note that due to "completely stupid semantics"[1] of the fcntl-based
    // file locking, we need to acquire the lock after we read the VM's
    // configuration file, otherwise we will loose the lock.
    //
    // [1]: https://man.openbsd.org/fcntl
    let lock = try PIDLock(lockURL: vmDir.configURL)
    if try !lock.trylock() {
      print("Virtual machine \"\(name)\" is already running!")
      Foundation.exit(2)
    }

    let task = Task {
      do {
        if let vncImpl = vncImpl {
          let vncURL = try await vncImpl.waitForURL()

          if noGraphics || ProcessInfo.processInfo.environment["CI"] != nil {
            print("VNC server is running at \(vncURL)")
          } else {
            print("Opening \(vncURL)...")
            NSWorkspace.shared.open(vncURL)
          }
        }

        try await vm!.run(recovery)

        if let vncImpl = vncImpl {
          try vncImpl.stop()
        }

        Foundation.exit(0)
      } catch {
        print(error)
        Foundation.exit(1)
      }
    }

    let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT)
    sigintSrc.setEventHandler {
      task.cancel()
    }
    sigintSrc.activate()

    let useVNCWithoutGraphics = (vnc || vncExperimental) && !graphics
    if noGraphics || useVNCWithoutGraphics {
      dispatchMain()
    } else {
      runUI()
    }
  }

  func userSpecifiedNetwork(vmDir: VMDirectory) throws -> Network? {
    if withSoftnet || netSoftnet {
      let config = try VMConfig.init(fromURL: vmDir.configURL)

      return try Softnet(vmMACAddress: config.macAddress.string)
    }

    if let netBridged = netBridged {
      let matchingInterfaces = VZBridgedNetworkInterface.networkInterfaces.filter { interface in
        interface.identifier == netBridged || interface.localizedDisplayName == netBridged
      }

      if matchingInterfaces.isEmpty {
        let available = bridgeInterfaces().joined(separator: ", ")
        throw ValidationError("no bridge interfaces matched \"\(netBridged)\", "
          + "available interfaces: \(available)")
      }

      if matchingInterfaces.count > 1 {
        throw ValidationError("more than one bridge interface matched \"\(netBridged)\", "
          + "consider refining the search criteria")
      }

      return NetworkBridged(interface: matchingInterfaces.first!)
    }

    return nil
  }

  func bridgeInterfaces() -> [String] {
    VZBridgedNetworkInterface.networkInterfaces.map { interface in
      var bridgeDescription = interface.identifier

      if let localizedDisplayName = interface.localizedDisplayName {
        bridgeDescription += " (or \"\(localizedDisplayName)\")"
      }

      return bridgeDescription
    }
  }

  func additionalDiskAttachments() throws -> [VZDiskImageStorageDeviceAttachment] {
    var result: [VZDiskImageStorageDeviceAttachment] = []
    let readOnlySuffix = ":ro"
    let expandedDiskPaths = disk.map { NSString(string:$0).expandingTildeInPath }

    for rawDisk in expandedDiskPaths {
      if rawDisk.hasSuffix(readOnlySuffix) {
        result.append(try VZDiskImageStorageDeviceAttachment(
          url: URL(fileURLWithPath: String(rawDisk.prefix(rawDisk.count - readOnlySuffix.count))),
          readOnly: true
        ))
      } else {
        result.append(try VZDiskImageStorageDeviceAttachment(
          url: URL(fileURLWithPath: rawDisk),
          readOnly: false
        ))
      }
    }

    return result
  }

  func directoryShares() throws -> [VZDirectorySharingDeviceConfiguration] {
    if dir.isEmpty {
      return []
    }

    guard #available(macOS 13, *) else {
      throw UnsupportedOSError("directory sharing", "is")
    }

    struct DirectoryShare {
      let name: String
      let path: URL
      let readOnly: Bool
    }

    var directoryShares: [DirectoryShare] = []

    for rawDir in dir {
      let splits = rawDir.split(maxSplits: 2) { $0 == ":" }

      if splits.count < 2 {
        throw ValidationError("invalid --dir syntax: should at least include name and path, colon-separated")
      }

      var readOnly: Bool = false

      if splits.count == 3 {
        if splits[2] == "ro" {
          readOnly = true
        } else {
          throw ValidationError("invalid --dir syntax: optional read-only specifier can only be \"ro\"")
        }
      }

      let (name, path) = (String(splits[0]), String(splits[1]))

      directoryShares.append(DirectoryShare(
        name: name,
        path: URL(fileURLWithPath: NSString(string: path).expandingTildeInPath),
        readOnly: readOnly)
      )
    }

    var directories: [String : VZSharedDirectory] = Dictionary()
    directoryShares.forEach { directories[$0.name] = VZSharedDirectory(url: $0.path, readOnly: $0.readOnly) }

    let automountTag = VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag
    let sharingDevice = VZVirtioFileSystemDeviceConfiguration(tag: automountTag)
    sharingDevice.share = VZMultipleDirectoryShare(directories: directories)

    return [sharingDevice]
  }

  private func rosettaDirectoryShare() throws -> [VZDirectorySharingDeviceConfiguration] {
    guard let rosettaTag = rosettaTag else {
      return []
    }

    guard #available(macOS 13, *) else {
      throw UnsupportedOSError("Rosetta directory share", "is")
    }

    switch VZLinuxRosettaDirectoryShare.availability {
    case .notInstalled:
      throw UnsupportedOSError("Rosetta directory share", "is", "that have Rosetta installed")
    case .notSupported:
      throw UnsupportedOSError("Rosetta directory share", "is", "running Apple silicon")
    default:
      break
    }

    try VZVirtioFileSystemDeviceConfiguration.validateTag(rosettaTag)
    let device = VZVirtioFileSystemDeviceConfiguration(tag: rosettaTag)
    device.share = try VZLinuxRosettaDirectoryShare()

    return [device]
  }

  private func runUI() {
    let nsApp = NSApplication.shared
    nsApp.setActivationPolicy(.regular)
    nsApp.activate(ignoringOtherApps: true)

    nsApp.applicationIconImage = NSImage(data: AppIconData)

    struct MainApp: App {
      var body: some Scene {
        WindowGroup(vm!.name) {
          Group {
            VMView(vm: vm!).onAppear {
              NSWindow.allowsAutomaticWindowTabbing = false
            }.onDisappear {
              NSApplication.shared.terminate(self)
            }
          }.frame(width: CGFloat(vm!.config.display.width), height: CGFloat(vm!.config.display.height))
        }.commands {
                  // Remove some standard menu options
                  CommandGroup(replacing: .help, addition: {})
                  CommandGroup(replacing: .newItem, addition: {})
                  CommandGroup(replacing: .pasteboard, addition: {})
                  CommandGroup(replacing: .textEditing, addition: {})
                  CommandGroup(replacing: .undoRedo, addition: {})
                  CommandGroup(replacing: .windowSize, addition: {})
                  // Replace some standard menu options
                  CommandGroup(replacing: .appInfo) { AboutTart() }
                }
      }
    }

    MainApp.main()
  }
}

struct AboutTart: View {
  var body: some View {
    Button("About Tart") {
      NSApplication.shared.orderFrontStandardAboutPanel(options: [
        NSApplication.AboutPanelOptionKey.applicationIcon: NSApplication.shared.applicationIconImage as Any,
        NSApplication.AboutPanelOptionKey.applicationName: "Tart",
        NSApplication.AboutPanelOptionKey.applicationVersion: CI.version,
        NSApplication.AboutPanelOptionKey.credits: try! NSAttributedString(markdown: "https://github.com/cirruslabs/tart"),
      ])
    }
  }
}

struct VMView: NSViewRepresentable {
  typealias NSViewType = VZVirtualMachineView

  @ObservedObject var vm: VM

  func makeNSView(context: Context) -> NSViewType {
    let machineView = VZVirtualMachineView()
    machineView.capturesSystemKeys = true
    return machineView
  }

  func updateNSView(_ nsView: NSViewType, context: Context) {
    nsView.virtualMachine = vm.virtualMachine
  }
}
