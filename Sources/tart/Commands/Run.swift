import ArgumentParser
import Cocoa
import Darwin
import Dispatch
import SwiftUI
import Virtualization
import Sentry
import System

var vm: VM?

struct IPNotFound: Error {
}

struct Run: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Run a VM")

  @Argument(help: "VM name", completion: .custom(completeLocalMachines))
  var name: String

  @Flag(help: ArgumentHelp(
    "Don't open a UI window.",
    discussion: "Useful for integrating Tart VMs into other tools.\nUse `tart ip` in order to get an IP for SSHing or VNCing into the VM."))
  var noGraphics: Bool = false

  @Flag(help: ArgumentHelp(
    "Open serial console in /dev/ttySXX",
    discussion: "Useful for debugging Linux Kernel."))
  var serial: Bool = false

  @Option(help: ArgumentHelp(
    "Attach an externally created serial console",
    discussion: "Alternative to `--serial` flag for programmatic integrations."
  ))
  var serialPath: String?

  @Flag(help: ArgumentHelp("Force open a UI window, even when VNC is enabled.", visibility: .private))
  var graphics: Bool = false

  @Flag(help: "Disable audio pass-through to host.")
  var noAudio: Bool = false

  @Flag(help: ArgumentHelp(
    "Disable clipboard sharing between host and guest.",
    discussion: "Only works with Linux-based guest operating systems."))
  var noClipboard: Bool = false

  #if arch(arm64)
    @Flag(help: "Boot into recovery mode")
  #endif
  var recovery: Bool = false

  #if arch(arm64)
    @Flag(help: ArgumentHelp(
      "Use screen sharing instead of the built-in UI.",
      discussion: "Useful since Screen Sharing supports copy/paste, drag and drop, etc.\n"
        + "Note that Remote Login option should be enabled inside the VM."))
  #endif
  var vnc: Bool = false

  #if arch(arm64)
    @Flag(help: ArgumentHelp(
      "Use Virtualization.Framework's VNC server instead of the built-in UI.",
      discussion: "Useful since this type of VNC is available in recovery mode and in macOS installation.\n"
        + "Note that this feature is experimental and there may be bugs present when using VNC."))
  #endif
  var vncExperimental: Bool = false

  @Option(help: ArgumentHelp("""
  Additional disk attachments with an optional read-only specifier\n(e.g. --disk=\"disk.bin\" --disk=\"ubuntu.iso:ro\" --disk=\"/dev/disk0\" --disk=\"nbd://localhost:10809/myDisk\")
  """, discussion: """
  Can be either a disk image file, a block device like a local SSD on AWS EC2 Mac instances or a Network Block Device (NBD).

  Learn how to create a disk image using Disk Utility here:
  https://support.apple.com/en-gb/guide/disk-utility/dskutl11888/mac

  To work with block devices, the easiest way is to modify their permissions (e.g. by using "sudo chown $USER /dev/diskX") or to run the Tart binary as root, which affects locating Tart VMs.

  To work around this pass TART_HOME explicitly:

  sudo TART_HOME="$HOME/.tart" tart run sonoma --disk=/dev/disk0
  """, valueName: "path[:ro]"))
  var disk: [String] = []

  #if arch(arm64)
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
  #endif
  var rosettaTag: String?

  @Option(help: ArgumentHelp("Additional directory shares with an optional read-only and mount tag options (e.g. --dir=\"~/src/build\" or --dir=\"~/src/sources:ro\")", discussion: """
  Requires host to be macOS 13.0 (Ventura) or newer. macOS guests must be running macOS 13.0 (Ventura) or newer too.

  Options are comma-separated and are as follows:

  * ro — mount this directory share in read-only mode instead of the default read-write (e.g. --dir=\"~/src/sources:ro\")

  * tag=<TAG> — by default, the \"com.apple.virtio-fs.automount\" mount tag is used for all directory shares. On macOS, this causes the directories to be automatically mounted to "/Volumes/My Shared Files" directory. On Linux, you have to do it manually: "mount -t virtiofs com.apple.virtio-fs.automount /mount/point".

  Mount tag can be overridden by appending tag property to the directory share (e.g. --dir=\"~/src/build:tag=build\" or --dir=\"~/src/build:ro,tag=build\"). Then it can be mounted via "mount_virtiofs build ~/build" inside guest macOS and "mount -t virtiofs build ~/build" inside guest Linux.

  In case of passing multiple directories per mount tag it is required to prefix them with names e.g. --dir=\"build:~/src/build\" --dir=\"sources:~/src/sources:ro\". These names will be used as directory names under the mounting point inside guests. For the example above it will be "/Volumes/My Shared Files/build" and "/Volumes/My Shared Files/sources" respectively.
  """, valueName: "[name:]path[:options]"))
  var dir: [String] = []

  @Option(help: ArgumentHelp("""
  Use bridged networking instead of the default shared (NAT) networking \n(e.g. --net-bridged=en0 or --net-bridged=\"Wi-Fi\")
  """, discussion: """
  Specify "list" as an interface name (--net-bridged=list) to list the available bridged interfaces.
  """, valueName: "interface name"))
  var netBridged: [String] = []

  @Flag(help: ArgumentHelp("Use software networking instead of the default shared (NAT) networking",
                           discussion: "Learn how to configure Softnet for use with Tart here: https://github.com/cirruslabs/softnet"))
  var netSoftnet: Bool = false

  @Option(help: ArgumentHelp("Comma-separated list of CIDRs to allow the traffic to when using Softnet isolation\n(e.g. --net-softnet-allow=192.168.0.0/24)", valueName: "comma-separated CIDRs"))
  var netSoftnetAllow: String?

  @Flag(help: ArgumentHelp("Restrict network access to the host-only network"))
  var netHost: Bool = false

  #if arch(arm64)
    @Flag(help: ArgumentHelp("Disables audio and entropy devices and switches to only Mac-specific input devices.", discussion: "Useful for running a VM that can be suspended via \"tart suspend\"."))
  #endif
  var suspendable: Bool = false

  #if arch(arm64)
    @Flag(help: ArgumentHelp("Whether system hot keys should be sent to the guest instead of the host",
                             discussion: "If enabled then system hot keys like Cmd+Tab will be sent to the guest instead of the host."))
  #endif
  var captureSystemKeys: Bool = false

  mutating func validate() throws {
    if vnc && vncExperimental {
      throw ValidationError("--vnc and --vnc-experimental are mutually exclusive")
    }

    // check that not more than one network option is specified
    var netFlags = 0
    if netBridged.count > 0 { netFlags += 1 }
    if netSoftnet { netFlags += 1 }
    if netHost { netFlags += 1 }

    if netFlags > 1 {
      throw ValidationError("--net-bridged, --net-softnet and --net-host are mutually exclusive")
    }

    if graphics && noGraphics {
      throw ValidationError("--graphics and --no-graphics are mutually exclusive")
    }

    if (noGraphics || vnc || vncExperimental) && captureSystemKeys {
      throw ValidationError("--captures-system-keys can only be used with the default VM view")
    }

    let localStorage = VMStorageLocal()
    let vmDir = try localStorage.open(name)
    if try vmDir.state() == .Suspended {
      suspendable = true
    }

    if suspendable {
      let config = try VMConfig.init(fromURL: vmDir.configURL)
      if !(config.platform is Darwin) {
        throw ValidationError("You can only suspend macOS VMs")
      }
      if dir.count > 0 {
        throw ValidationError("Suspending VMs with shared directories is not supported")
      }
    }

    for disk in disk {
      if disk.hasSuffix("-amd64.iso") {
        throw ValidationError("Seems you have a disk targeting x86 architecture (hence amd64 in the name). Please use an 'arm64' version of the disk.")
      }
    }
  }

  @MainActor
  func run() async throws {
    let localStorage = VMStorageLocal()
    let vmDir = try localStorage.open(name)

    let storageLock = try FileLock(lockURL: Config().tartHomeDir)
    try storageLock.lock()
    // check if there is a running VM with the same MAC address
    let hasRunningMACCollision = try localStorage.list().contains {
      // check if there is a running VM with the same MAC but different name
      try $1.running() && $1.macAddress() == vmDir.macAddress() && $1.name != vmDir.name
    }
    if hasRunningMACCollision {
      print("There is already a running VM with the same MAC address!")
      print("Resetting VM to assign a new MAC address...")
      try vmDir.regenerateMACAddress()
    }

    if (netSoftnet || netHost) && isInteractiveSession() {
      try Softnet.configureSUIDBitIfNeeded()
    }

    let additionalDiskAttachments = try additionalDiskAttachments()

    var serialPorts: [VZSerialPortConfiguration] = []
    if serial {
      let tty_fd = createPTY()
      if (tty_fd < 0) {
        throw RuntimeError.VMConfigurationError("Failed to create PTY")
      }
      let tty_read = FileHandle.init(fileDescriptor: tty_fd)
      let tty_write = FileHandle.init(fileDescriptor: tty_fd)
      serialPorts.append(createSerialPortConfiguration(tty_read, tty_write))
    } else if serialPath != nil {
      let tty_read = FileHandle.init(forReadingAtPath: serialPath!)
      let tty_write = FileHandle.init(forWritingAtPath: serialPath!)
      if (tty_read == nil || tty_write == nil) {
        throw RuntimeError.VMConfigurationError("Failed to open PTY")
      }
      serialPorts.append(createSerialPortConfiguration(tty_read!, tty_write!))
    }

    vm = try VM(
      vmDir: vmDir,
      network: userSpecifiedNetwork(vmDir: vmDir) ?? NetworkShared(),
      additionalStorageDevices: additionalDiskAttachments,
      directorySharingDevices: directoryShares() + rosettaDirectoryShare(),
      serialPorts: serialPorts,
      suspendable: suspendable,
      audio: !noAudio,
      clipboard: !noClipboard
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
    let lock = try vmDir.lock()
    if try !lock.trylock() {
      throw RuntimeError.VMAlreadyRunning("VM \"\(name)\" is already running!")
    }

    // now VM state will return "running" so we can unlock
    try storageLock.unlock()

    let task = Task {
      do {
        var resume = false

        #if arch(arm64)
          if #available(macOS 14, *) {
            if FileManager.default.fileExists(atPath: vmDir.stateURL.path) {
              print("restoring VM state from a snapshot...")
              try await vm!.virtualMachine.restoreMachineStateFrom(url: vmDir.stateURL)
              try FileManager.default.removeItem(at: vmDir.stateURL)
              resume = true
              print("resuming VM...")
            }
          }
        #endif

        try await vm!.start(recovery: recovery, resume: resume)

        if let vncImpl = vncImpl {
          let vncURL = try await vncImpl.waitForURL(netBridged: !netBridged.isEmpty)

          if noGraphics || ProcessInfo.processInfo.environment["CI"] != nil {
            print("VNC server is running at \(vncURL)")
          } else {
            print("Opening \(vncURL)...")
            NSWorkspace.shared.open(vncURL)
          }
        }

        try await vm!.run()

        if let vncImpl = vncImpl {
          try vncImpl.stop()
        }

        Foundation.exit(0)
      } catch {
        // Capture the error into Sentry
        SentrySDK.capture(error: error)
        SentrySDK.flush(timeout: 2.seconds.timeInterval)

        fputs("\(error)\n", stderr)

        Foundation.exit(1)
      }
    }

    // "tart stop" support
    let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT)
    sigintSrc.setEventHandler {
      task.cancel()
    }
    sigintSrc.activate()

    // "tart suspend" / UI window closing support
    signal(SIGUSR1, SIG_IGN)
    let sigusr1Src = DispatchSource.makeSignalSource(signal: SIGUSR1)
    sigusr1Src.setEventHandler {
      Task {
        do {
          #if arch(arm64)
            if #available(macOS 14, *) {
              try vm!.configuration.validateSaveRestoreSupport()

              print("pausing VM to take a snapshot...")
              try await vm!.virtualMachine.pause()

              print("creating a snapshot...")
              try await vm!.virtualMachine.saveMachineStateTo(url: vmDir.stateURL)

              print("snapshot created successfully! shutting down the VM...")

              task.cancel()
            } else {
              print(RuntimeError.SuspendFailed("this functionality is only supported on macOS 14 (Sonoma) or newer"))

              Foundation.exit(1)
            }
          #endif
        } catch (let e) {
          print(RuntimeError.SuspendFailed(e.localizedDescription))

          Foundation.exit(1)
        }
      }
    }
    sigusr1Src.activate()

    let useVNCWithoutGraphics = (vnc || vncExperimental) && !graphics
    if noGraphics || useVNCWithoutGraphics {
      // enter the main even loop, without bringing up any UI,
      // and just wait for the VM to exit.
      NSApplication.shared.run()
    } else {
      runUI(suspendable, captureSystemKeys)
    }
  }

  private func createSerialPortConfiguration(_ tty_read: FileHandle, _ tty_write: FileHandle) -> VZVirtioConsoleDeviceSerialPortConfiguration {
    let serialPortConfiguration = VZVirtioConsoleDeviceSerialPortConfiguration()
    let serialPortAttachment = VZFileHandleSerialPortAttachment(
      fileHandleForReading: tty_read,
      fileHandleForWriting: tty_write)

    serialPortConfiguration.attachment = serialPortAttachment
    return serialPortConfiguration
  }

  func isInteractiveSession() -> Bool {
    isatty(STDOUT_FILENO) == 1
  }

  func userSpecifiedNetwork(vmDir: VMDirectory) throws -> Network? {
    if netSoftnet {
      let config = try VMConfig.init(fromURL: vmDir.configURL)

      var extraArguments: [String] = []

      if let netSoftnetAllow = netSoftnetAllow {
        extraArguments += ["--allow", netSoftnetAllow]
      }

      return try Softnet(vmMACAddress: config.macAddress.string, extraArguments: extraArguments)
    }

    if netHost {
      let config = try VMConfig.init(fromURL: vmDir.configURL)
      return try Softnet(vmMACAddress: config.macAddress.string, extraArguments: ["--vm-net-type", "host"])
    }

    if netBridged.count > 0 {
      func findBridgedInterface(_ name: String) throws -> VZBridgedNetworkInterface {
        let interface = VZBridgedNetworkInterface.networkInterfaces.first { interface in
          interface.identifier == name || interface.localizedDisplayName == name
        }
        if (interface == nil) {
          throw ValidationError("no bridge interfaces matched \"\(netBridged)\", "
            + "available interfaces: \(bridgeInterfaces())")
        }
        return interface!
      }

      return NetworkBridged(interfaces: try netBridged.map { try findBridgedInterface($0) })
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

  func additionalDiskAttachments() throws -> [VZStorageDeviceConfiguration] {
    var result: [VZStorageDeviceConfiguration] = []
    let readOnlySuffix = ":ro"
    let expandedDiskPaths = disk.map { NSString(string:$0).expandingTildeInPath }

    for rawDisk in expandedDiskPaths {
      let diskReadOnly = rawDisk.hasSuffix(readOnlySuffix)
      let diskPath = diskReadOnly ? String(rawDisk.prefix(rawDisk.count - readOnlySuffix.count)) : rawDisk

      let diskURL = URL(string: diskPath)
      if (["nbd", "nbds", "nbd+unix", "nbds+unix"].contains(diskURL?.scheme)) {
        guard #available(macOS 14, *) else {
          throw UnsupportedOSError("attaching Network Block Devices", "are")
        }

        let nbdAttachment = try VZNetworkBlockDeviceStorageDeviceAttachment(
          url: diskURL!,
          timeout: 30,
          isForcedReadOnly: diskReadOnly,
          synchronizationMode: VZDiskSynchronizationMode.none
        )
        result.append(VZVirtioBlockDeviceConfiguration(attachment: nbdAttachment))
        continue
      }

      let diskFileURL = URL(fileURLWithPath: diskPath)

      if pathHasMode(diskPath, mode: S_IFBLK) {
        guard #available(macOS 14, *) else {
          throw UnsupportedOSError("attaching block devices", "are")
        }

        let fd = open(diskPath, diskReadOnly ? O_RDONLY : O_RDWR)
        if fd == -1 {
          let details = Errno(rawValue: CInt(errno))

          switch details.rawValue {
          case EBUSY:
            throw RuntimeError.FailedToOpenBlockDevice(diskFileURL.url.path, "already in use, try umounting it via \"diskutil unmountDisk\" (when the whole disk) or \"diskutil umount\" (when mounting a single partition)")
          case EACCES:
            throw RuntimeError.FailedToOpenBlockDevice(diskFileURL.url.path, "permission denied, consider changing the disk's owner using \"sudo chown $USER \(diskFileURL.url.path)\" or run Tart as a superuser (see --disk help for more details on how to do that correctly)")
          default:
            throw RuntimeError.FailedToOpenBlockDevice(diskFileURL.url.path, "\(details)")
          }
        }

        let blockAttachment = try VZDiskBlockDeviceStorageDeviceAttachment(fileHandle: FileHandle(fileDescriptor: fd, closeOnDealloc: true),
                                                                           readOnly: diskReadOnly, synchronizationMode: .full)
        result.append(VZVirtioBlockDeviceConfiguration(attachment: blockAttachment))
        continue
      }

      // Error out if the disk is locked by the host (e.g. it was mounted in Finder),
      // see https://github.com/cirruslabs/tart/issues/323 for more details.
      if try !diskReadOnly && !FileLock(lockURL: diskFileURL).trylock() {
        throw RuntimeError.DiskAlreadyInUse("disk \(diskFileURL.url.path) seems to be already in use, unmount it first in Finder")
      }

      let diskImageAttachment = try VZDiskImageStorageDeviceAttachment(
        url: diskFileURL,
        readOnly: diskReadOnly
      )
      result.append(VZVirtioBlockDeviceConfiguration(attachment: diskImageAttachment))
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

    var allDirectoryShares: [DirectoryShare] = []

    for rawDir in dir {
      allDirectoryShares.append(try DirectoryShare(parseFrom: rawDir))
    }

    return try Dictionary(grouping: allDirectoryShares, by: {$0.mountTag}).map { mountTag, directoryShares in
      let sharingDevice = VZVirtioFileSystemDeviceConfiguration(tag: mountTag)

      var allNamedShares = true
      for directoryShare in directoryShares {
        if directoryShare.name == nil {
          allNamedShares = false
        }
      }
      if directoryShares.count == 1 && directoryShares.first!.name == nil {
        let directoryShare = directoryShares.first!
        let singleDirectoryShare = VZSingleDirectoryShare(directory: try directoryShare.createConfiguration())
        sharingDevice.share = singleDirectoryShare
      } else if !allNamedShares {
        throw ValidationError("invalid --dir syntax: for multiple directory shares each one of them should be named")
      } else {
        var directories: [String : VZSharedDirectory] = Dictionary()
        try directoryShares.forEach { directories[$0.name!] = try $0.createConfiguration() }
        sharingDevice.share = VZMultipleDirectoryShare(directories: directories)
      }

      return sharingDevice
    }
  }

  private func rosettaDirectoryShare() throws -> [VZDirectorySharingDeviceConfiguration] {
    guard let rosettaTag = rosettaTag else {
      return []
    }
    #if arch(arm64)
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
    #elseif arch(x86_64)
      // there is no Rosetta on Intel
      return []
    #endif
  }

  private func runUI(_ suspendable: Bool, _ captureSystemKeys: Bool) {
    MainApp.suspendable = suspendable
    MainApp.capturesSystemKeys = captureSystemKeys
    MainApp.main()
  }
}

struct MainApp: App {
  static var suspendable: Bool = false
  static var capturesSystemKeys: Bool = false

  @NSApplicationDelegateAdaptor private var appDelegate: MinimalMenuAppDelegate

  var body: some Scene {
    WindowGroup(vm!.name) {
      Group {
        VMView(vm: vm!, capturesSystemKeys: MainApp.capturesSystemKeys).onAppear {
          NSWindow.allowsAutomaticWindowTabbing = false
        }.onDisappear {
          let ret = kill(getpid(), MainApp.suspendable ? SIGUSR1 : SIGINT)
          if ret != 0 {
            // Fallback to the old termination method that doesn't
            // propagate the cancellation to Task's in case graceful
            // termination via kill(2) is not successful
            NSApplication.shared.terminate(self)
          }
        }
      }.frame(
        minWidth: CGFloat(vm!.config.display.width),
        idealWidth: CGFloat(vm!.config.display.width),
        maxWidth: .infinity,
        minHeight: CGFloat(vm!.config.display.height),
        idealHeight: CGFloat(vm!.config.display.height),
        maxHeight: .infinity
      )
    }.commands {
      // Remove some standard menu options
      CommandGroup(replacing: .help, addition: {})
      CommandGroup(replacing: .newItem, addition: {})
      CommandGroup(replacing: .pasteboard, addition: {})
      CommandGroup(replacing: .textEditing, addition: {})
      CommandGroup(replacing: .undoRedo, addition: {})
      CommandGroup(replacing: .windowSize, addition: {})
      // Replace some standard menu options
      CommandGroup(replacing: .appInfo) { AboutTart(config: vm!.config) }
      CommandMenu("Control") {
        Button("Start") {
          Task { try await vm!.virtualMachine.start() }
        }
        Button("Stop") {
          Task { try await vm!.virtualMachine.stop() }
        }
        Button("Request Stop") {
          Task { try vm!.virtualMachine.requestStop() }
        }
        if #available(macOS 14, *) {
          if (MainApp.suspendable) {
            Button("Suspend") {
              kill(getpid(), SIGUSR1)
            }
          }
        }
      }
    }
  }
}

// The only way to fully remove Edit menu item.
class MinimalMenuAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
  let indexOfEditMenu = 2

  func applicationDidFinishLaunching(_ : Notification) {
    NSApplication.shared.mainMenu?.removeItem(at: indexOfEditMenu)

    let nsApp = NSApplication.shared
    nsApp.setActivationPolicy(.regular)
    nsApp.activate(ignoringOtherApps: true)
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if (kill(getpid(), MainApp.suspendable ? SIGUSR1 : SIGINT) == 0) {
      return .terminateLater
    } else {
      return .terminateNow
    }
  }
}

struct AboutTart: View {
  var credits: NSAttributedString

  init(config: VMConfig) {
    let mutableAttrStr = NSMutableAttributedString()
    let style = NSMutableParagraphStyle()
    style.alignment = NSTextAlignment.center
    let attrCenter: [NSAttributedString.Key : Any] = [
      .paragraphStyle: style,
    ]
    mutableAttrStr.append(NSAttributedString(string: "CPU: \(config.cpuCount) cores\n", attributes: attrCenter))
    mutableAttrStr.append(NSAttributedString(string: "Memory: \(config.memorySize / 1024 / 1024) MB\n", attributes: attrCenter))
    mutableAttrStr.append(NSAttributedString(string: "Display: \(config.display.description)\n", attributes: attrCenter))
    mutableAttrStr.append(NSAttributedString(string: "https://github.com/cirruslabs/tart", attributes: [
      .paragraphStyle: style,
      .link : "https://github.com/cirruslabs/tart"
    ]))
    credits = mutableAttrStr
  }

  var body: some View {
    Button("About Tart") {
      NSApplication.shared.orderFrontStandardAboutPanel(options: [
        NSApplication.AboutPanelOptionKey.applicationIcon: NSApplication.shared.applicationIconImage as Any,
        NSApplication.AboutPanelOptionKey.applicationName: "Tart",
        NSApplication.AboutPanelOptionKey.applicationVersion: CI.version,
        NSApplication.AboutPanelOptionKey.credits: credits,
      ])
    }
  }
}

struct VMView: NSViewRepresentable {
  typealias NSViewType = VZVirtualMachineView

  @ObservedObject var vm: VM
  var capturesSystemKeys: Bool

  func makeNSView(context: Context) -> NSViewType {
    let machineView = VZVirtualMachineView()

    machineView.capturesSystemKeys = capturesSystemKeys

    // Enable automatic display reconfiguration
    // for guests that support it
    //
    // This is disabled for Linux because of poor HiDPI
    // support, which manifests in fonts being too small
    if #available(macOS 14.0, *), vm.config.os != .linux {
      machineView.automaticallyReconfiguresDisplay = true
    }

    return machineView
  }

  func updateNSView(_ nsView: NSViewType, context: Context) {
    nsView.virtualMachine = vm.virtualMachine
  }
}

struct DirectoryShare {
  let name: String?
  let path: URL
  let readOnly: Bool
  let mountTag: String

  init(parseFrom: String) throws {
    var parseFrom = parseFrom

    // Consume options
    (self.readOnly, self.mountTag, parseFrom) = Self.parseOptions(parseFrom)

    // Special case for URLs
    if parseFrom.hasPrefix("http:") || parseFrom.hasPrefix("https:") {
      self.name = nil
      self.path = URL(string: parseFrom)!

      return
    }

    let arguments = parseFrom.split(separator: ":", maxSplits: 1)

    if arguments.count == 2 {
      self.name = String(arguments[0])
      self.path = String(arguments[1]).toRemoteOrLocalURL()
    } else {
      self.name = nil
      self.path = String(arguments[0]).toRemoteOrLocalURL()
    }
  }

  static func parseOptions(_ parseFrom: String) -> (Bool, String, String) {
    var arguments = parseFrom.split(separator: ":")
    let options = arguments.last!.split(separator: ",")

    var readOnly: Bool = false
    var mountTag: String = VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag

    var found: Bool = false

    for option in options {
      switch true {
      case option == "ro":
        readOnly = true
        found = true
      case option.hasPrefix("tag="):
        mountTag = String(option.dropFirst(4))
        found = true
      default:
        continue
      }
    }

    if found {
      arguments.removeLast()
    }

    return (readOnly, mountTag, arguments.joined(separator: ":"))
  }

  func createConfiguration() throws -> VZSharedDirectory {
    if (path.isFileURL) {
      return VZSharedDirectory(url: path, readOnly: readOnly)
    }

    let urlCache = URLCache(memoryCapacity: 0, diskCapacity: 1 * 1024 * 1024 * 1024)

    let archiveRequest = URLRequest(url: path, cachePolicy: .returnCacheDataElseLoad)
    var response: CachedURLResponse? = urlCache.cachedResponse(for: archiveRequest)
    if (response == nil || response?.data.isEmpty == true) {
      print("Downloading \(path)...")
      // download and unarchive remote directories if needed here
      // use old school API to prevent deadlocks since we are running via MainActor
      let downloadSemaphore = DispatchSemaphore(value: 0)
      Task {
        do {
          let (archiveData, archiveResponse) = try await URLSession.shared.data(for: archiveRequest)
          if archiveData.isEmpty {
            print("Remote archive is empty!")
          } else {
            urlCache.storeCachedResponse(CachedURLResponse(response: archiveResponse, data: archiveData, storagePolicy: .allowed), for: archiveRequest)
            print("Cached for future invocations!")
          }
        } catch {
          print("Download failed: \(error)")
        }
        downloadSemaphore.signal()
      }
      downloadSemaphore.wait()
      response = urlCache.cachedResponse(for: archiveRequest)
    } else {
      print("Using cached archive for \(path)...")
    }

    if (response == nil) {
      throw ValidationError("Failed to fetch a remote archive!")
    }

    let temporaryLocation = try Config().tartTmpDir.appendingPathComponent(UUID().uuidString + ".volume")
    try FileManager.default.createDirectory(atPath: temporaryLocation.path, withIntermediateDirectories: true)
    let lock = try FileLock(lockURL: temporaryLocation)
    try lock.lock()

    guard let executableURL = resolveBinaryPath("tar") else {
      throw ValidationError("tar not found in PATH")
    }

    let process = Process.init()
    process.executableURL = executableURL
    process.currentDirectoryURL = temporaryLocation
    process.arguments = ["-xz"]

    let inPipe = Pipe()
    process.standardInput = inPipe
    process.launch()

    inPipe.fileHandleForWriting.write(response!.data)
    try inPipe.fileHandleForWriting.close()
    process.waitUntilExit()

    if !(process.terminationReason == .exit && process.terminationStatus == 0) {
      throw ValidationError("Unarchiving failed!")
    }

    print("Unarchived into a temporary directory!")

    return VZSharedDirectory(url: temporaryLocation, readOnly: readOnly)
  }
}

extension String {
  func toRemoteOrLocalURL() -> URL {
    if (starts(with: "https://") || starts(with: "https://")) {
      URL(string: self)!
    } else {
      URL(fileURLWithPath: NSString(string: self).expandingTildeInPath)
    }
  }
}

func pathHasMode(_ path: String, mode: mode_t) -> Bool {
  var st = stat()
  let statRes = stat(path, &st)
  guard statRes != -1 else {
    return false
  }
  return (st.st_mode & S_IFMT) == mode
}
