import ArgumentParser
import Foundation
import CoreGraphics
import Darwin

fileprivate struct VMInfo: Encodable {
  let OS: OS
  let CPU: Int
  let Memory: UInt64
  let Disk: Int
  let DiskFormat: String
  let Size: String
  let Display: String
  let Running: Bool
  let State: String
  let NoGraphics: Bool?

  enum CodingKeys: String, CodingKey {
    case OS, CPU, Memory, Disk, DiskFormat, Size, Display, Running, State, NoGraphics
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(OS, forKey: .OS)
    try container.encode(CPU, forKey: .CPU)
    try container.encode(Memory, forKey: .Memory)
    try container.encode(Disk, forKey: .Disk)
    try container.encode(DiskFormat, forKey: .DiskFormat)
    try container.encode(Size, forKey: .Size)
    try container.encode(Display, forKey: .Display)
    try container.encode(Running, forKey: .Running)
    try container.encode(State, forKey: .State)
    if let noGraphics = NoGraphics {
      try container.encode(noGraphics, forKey: .NoGraphics)
    } else {
      try container.encodeNil(forKey: .NoGraphics)
    }
  }
}

struct Get: AsyncParsableCommand {
  static var configuration = CommandConfiguration(commandName: "get", abstract: "Get a VM's configuration")

  @Argument(help: "VM name.", completion: .custom(completeLocalMachines))
  var name: String

  @Option(help: "Output format: text or json")
  var format: Format = .text

  func run() async throws {
    let vmDir = try VMStorageLocal().open(name)
    let vmConfig = try VMConfig(fromURL: vmDir.configURL)
    let memorySizeInMb = vmConfig.memorySize / 1024 / 1024

    // Check if VM is running without graphics (no windows)
    var noGraphics: Bool? = nil
    if try vmDir.running() {
      let lock = try vmDir.lock()
      let pid = try lock.pid()
      if pid > 0 {
        noGraphics = try hasNoWindows(pid: pid)
      }
    }

    let info = VMInfo(OS: vmConfig.os, CPU: vmConfig.cpuCount, Memory: memorySizeInMb, Disk: try vmDir.sizeGB(), DiskFormat: vmConfig.diskFormat.rawValue, Size: String(format: "%.3f", Float(try vmDir.allocatedSizeBytes()) / 1000 / 1000 / 1000), Display: vmConfig.display.description, Running: try vmDir.running(), State: try vmDir.state().rawValue, NoGraphics: noGraphics)
    print(format.renderSingle(info))
  }

  private func hasNoWindows(pid: pid_t) throws -> Bool {
    // Check if the process and its children have any windows using Core Graphics Window Server
    // This is more reliable than checking command-line arguments since there are
    // multiple ways a VM might run without graphics (--no-graphics flag, CI environment, etc.)

    // Get all PIDs to check (parent + children)
    var pidsToCheck = [pid]
    pidsToCheck.append(contentsOf: try getChildProcesses(of: pid))

    // Get all window information from the window server
    guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
      // If we can't get window info, assume no graphics
      return true
    }

    // Check if any window belongs to our process or its children
    for windowInfo in windowList {
      if let windowPID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
         pidsToCheck.contains(windowPID) {
        // Found a window for this process tree, so it has graphics
        return false
      }
    }

    // No windows found for this process tree
    return true
  }

  private func getChildProcesses(of parentPID: pid_t) throws -> [pid_t] {
    var children: [pid_t] = []

    // Use sysctl to get process information
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
    var size: size_t = 0

    // Get size needed
    if sysctl(&mib, 4, nil, &size, nil, 0) != 0 {
      // If we can't get process list, return empty array
      return children
    }

    // Allocate memory and get process list
    let count = size / MemoryLayout<kinfo_proc>.size
    var procs = Array<kinfo_proc>(repeating: kinfo_proc(), count: count)

    if sysctl(&mib, 4, &procs, &size, nil, 0) != 0 {
      // If we can't get process list, return empty array
      return children
    }

    // Find direct children of the given parent PID
    for proc in procs {
      let ppid = proc.kp_eproc.e_ppid
      let pid = proc.kp_proc.p_pid
      if ppid == parentPID && pid > 0 {
        children.append(pid)
        // Recursively get children of children
        if let grandchildren = try? getChildProcesses(of: pid) {
          children.append(contentsOf: grandchildren)
        }
      }
    }

    return children
  }
}
