import Foundation
import Virtualization
import Atomics
import System

enum SoftnetError: Error {
  case InitializationFailed(why: String)
  case RuntimeFailed(why: String)
}

class Softnet: Network {
  private let process = Process()
  private var monitorTask: Task<Void, Error>? = nil
  private let monitorTaskFinished = ManagedAtomic<Bool>(false)

  let vmFD: Int32

  init(vmMACAddress: String) throws {
    let fds = UnsafeMutablePointer<Int32>.allocate(capacity: MemoryLayout<Int>.stride * 2)

    let ret = socketpair(AF_UNIX, SOCK_DGRAM, 0, fds)
    if ret != 0 {
      throw SoftnetError.InitializationFailed(why: "socketpair() failed with exit code \(ret)")
    }

    vmFD = fds[0]
    let softnetFD = fds[1]

    try setSocketBuffers(vmFD, 1 * 1024 * 1024);
    try setSocketBuffers(softnetFD, 1 * 1024 * 1024);

    process.executableURL = try Self.softnetExecutableURL()
    process.arguments = ["--vm-fd", String(STDIN_FILENO), "--vm-mac-address", vmMACAddress]
    process.standardInput = FileHandle(fileDescriptor: softnetFD, closeOnDealloc: false)
  }

  static func softnetExecutableURL() throws -> URL {
    let binaryName = "softnet"

    guard let executableURL = resolveBinaryPath(binaryName) else {
      throw SoftnetError.InitializationFailed(why: "\(binaryName) not found in PATH")
    }

    return executableURL
  }

  func run(_ sema: DispatchSemaphore) throws {
    try process.run()

    monitorTask = Task {
      // Wait for the Softnet to finish
      process.waitUntilExit()

      // Signal to the caller that the Softnet has finished
      sema.signal()

      // Signal to ourselves that the Softnet has finished
      monitorTaskFinished.store(true, ordering: .sequentiallyConsistent)
    }
  }

  func stop() async throws {
    if monitorTaskFinished.load(ordering: .sequentiallyConsistent) {
      // Consume the monitor task's value to ensure the task has finished
      _ = try await monitorTask?.value

      throw SoftnetError.RuntimeFailed(why: "Softnet process terminated prematurely")
    } else {
      process.interrupt()

      // Consume the monitor task's value to ensure the task has finished
      _ = try await monitorTask?.value
    }
  }

  private func setSocketBuffers(_ fd: Int32, _ sizeBytes: Int) throws {
    let option_len = socklen_t(MemoryLayout<Int>.size)

    // The system expects the value of SO_RCVBUF to be at least double the value of SO_SNDBUF,
    // and for optimal performance, the recommended value of SO_RCVBUF is four times the value of SO_SNDBUF.
    // See: https://developer.apple.com/documentation/virtualization/vzfilehandlenetworkdeviceattachment/3969266-maximumtransmissionunit
    var receiveBufferSize = 4 * sizeBytes
    var ret = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &receiveBufferSize, option_len)
    if ret != 0 {
      throw SoftnetError.InitializationFailed(why: "setsockopt(SO_RCVBUF) returned \(ret)")
    }

    var sendBufferSize = sizeBytes
    ret = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &sendBufferSize, option_len)
    if ret != 0 {
      throw SoftnetError.InitializationFailed(why: "setsockopt(SO_SNDBUF) returned \(ret)")
    }
  }

  func attachment() -> VZNetworkDeviceAttachment {
    let fh = FileHandle.init(fileDescriptor: vmFD)
    return VZFileHandleNetworkDeviceAttachment(fileHandle: fh)
  }

  static func configureSUIDBitIfNeeded() throws {
    // Obtain the Softnet executable path
    //
    // It's important to use resolvingSymlinksInPath() here, because otherwise
    // we will get something like "/opt/homebrew/bin/softnet" instead of
    // "/opt/homebrew/Cellar/softnet/0.6.2/bin/softnet"
    let softnetExecutablePath = try Softnet.softnetExecutableURL().resolvingSymlinksInPath().path

    // Check if the SUID bit is already configured
    let info = try FileManager.default.attributesOfItem(atPath: softnetExecutablePath) as NSDictionary
    if info.fileOwnerAccountID() == 0 && (info.filePosixPermissions() & Int(S_ISUID)) != 0 {
      return
    }

    // Check if the passwordless Sudo is already configured for Softnet
    let sudoBinaryName = "sudo"

    guard let sudoExecutableURL = resolveBinaryPath(sudoBinaryName) else {
      throw SoftnetError.InitializationFailed(why: "\(sudoBinaryName) not found in PATH")
    }

    var process = Process()
    process.executableURL = sudoExecutableURL
    process.arguments = ["--non-interactive", "softnet", "--help"]
    process.standardInput = nil
    process.standardOutput = nil
    process.standardError = nil
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus == 0 {
      return
    }

    // Configure the SUID bit by spawning the Sudo process in interactive mode
    // and asking the user for password required to run chown & chmod
    fputs("Softnet requires a Sudo password to set the SUID bit on the Softnet executable, please enter it below.\n",
          stderr)

    process = try Process.run(sudoExecutableURL, arguments: [
      "sh",
      "-c",
      "chown root \(softnetExecutablePath) && chmod u+s \(softnetExecutablePath)",
    ])

    // Set TTY's foreground process group to that of the Sudo process,
    // otherwise it will get stopped by a SIGTTIN once user input arrives
    if tcsetpgrp(STDIN_FILENO, process.processIdentifier) == -1 {
      let details = Errno(rawValue: CInt(errno))

      throw RuntimeError.SoftnetFailed("tcsetpgrp(2) failed: \(details)")
    }

    process.waitUntilExit()

    if process.terminationStatus != 0 {
      throw RuntimeError.SoftnetFailed("failed to configure SUID bit on Softnet executable with Sudo")
    }
  }
}
