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
  private let isInteractive: Bool

  let vmFD: Int32

  init(vmMACAddress: String) throws {
    let binaryName = "softnet"

    guard let executableURL = resolveBinaryPath(binaryName) else {
      throw SoftnetError.InitializationFailed(why: "\(binaryName) not found in PATH")
    }

    process.executableURL = executableURL

    process.arguments = ["--vm-fd", String(STDIN_FILENO), "--vm-mac-address", vmMACAddress]

    isInteractive = isatty(STDOUT_FILENO) == 1
    if isInteractive {
      process.arguments?.append("--sudo-escalation-interactive")
    }

    let (vmFD, softnetFD) = try Self.establishCommunicationChannel()
    self.vmFD = vmFD
    process.standardInput = FileHandle(fileDescriptor: softnetFD, closeOnDealloc: false)
  }

  func run(_ sema: DispatchSemaphore) throws {
    try process.run()

    if isInteractive {
      // Set TTY's foreground process group to that of the Sudo process,
      // otherwise it will get stopped by a SIGTTIN once user input arrives
      if tcsetpgrp(STDIN_FILENO, process.processIdentifier) == -1 {
        let details = Errno(rawValue: CInt(errno))

        throw RuntimeError.SoftnetFailed("tcsetpgrp(2) failed: \(details)")
      }

      // When the Sofnet is running in interactive escalation mode,
      // Softnet sends SIGSTOP and waits for us, thus allowing us
      // to hold VM the startup procedure until the user actually
      // enters the Sudo password, otherwise we will start a VM
      // that has no networking.
      var infop = siginfo_t()
      if waitid(P_ALL, 0, &infop, WEXITED | WSTOPPED) != 0 {
        let details = Errno(rawValue: CInt(errno))

        throw RuntimeError.SoftnetFailed("waitid(2) failed: \(details)")
      }

      if infop.si_code == CLD_EXITED {
        // Something is wrong, continue running.
        //
        // The monitor task below will do the cleanup for us.
      } else if infop.si_code == CLD_STOPPED {
        // Softnet has stopped itself, resume it.
        //
        // Note that this might be also the case where the user
        // has stopped of our children process by pressing Ctrl+Z,
        // but we consider this case as negligible for now.
        if kill(infop.si_pid, SIGCONT) != 0 {
          let details = Errno(rawValue: CInt(errno))

          throw RuntimeError.SoftnetFailed("failed to resume Softnet process: \(details)")
        }
      }
    }

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

  private static func establishCommunicationChannel() throws -> (Int32, Int32) {
    let fds = UnsafeMutablePointer<Int32>.allocate(capacity: MemoryLayout<Int>.stride * 2)

    let ret = socketpair(AF_UNIX, SOCK_DGRAM, 0, fds)
    if ret != 0 {
      throw SoftnetError.InitializationFailed(why: "socketpair() failed with exit code \(ret)")
    }

    try setSocketBuffers(fds[0], 1 * 1024 * 1024);
    try setSocketBuffers(fds[1], 1 * 1024 * 1024);

    return (fds[0], fds[1])
  }

  private static func setSocketBuffers(_ fd: Int32, _ sizeBytes: Int) throws {
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
}
