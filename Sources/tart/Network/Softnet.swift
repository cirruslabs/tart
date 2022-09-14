import Foundation
import Virtualization

enum SoftnetError: Error {
  case InitializationFailed(why: String)
}

class Softnet: Network {
  private let process = Process()

  let vmFD: Int32

  init(vmMACAddress: String) throws {
    let binaryName = "softnet"

    guard let executableURL = resolveBinaryPath(binaryName) else {
      throw SoftnetError.InitializationFailed(why: "\(binaryName) not found in PATH")
    }

    let fds = UnsafeMutablePointer<Int32>.allocate(capacity: MemoryLayout<Int>.stride * 2)

    let ret = socketpair(AF_UNIX, SOCK_DGRAM, 0, fds)
    if ret != 0 {
      throw SoftnetError.InitializationFailed(why: "socketpair() failed with exit code \(ret)")
    }

    vmFD = fds[0]
    let softnetFD = fds[1]

    try setSocketBuffers(vmFD, 1 * 1024 * 1024);
    try setSocketBuffers(softnetFD, 1 * 1024 * 1024);

    process.executableURL = executableURL
    process.arguments = ["--vm-fd", String(STDIN_FILENO), "--vm-mac-address", vmMACAddress]
    process.standardInput = FileHandle(fileDescriptor: softnetFD, closeOnDealloc: false)
  }

  func run() throws {
    try process.run()
  }

  func stop() throws {
    process.interrupt()
    process.waitUntilExit()
  }

  private func setSocketBuffers(_ fd: Int32, _ sizeBytes: Int) throws {
    var option_value = sizeBytes
    let option_len = socklen_t(MemoryLayout<Int>.size)

    var ret = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &option_value, option_len)
    if ret != 0 {
      throw SoftnetError.InitializationFailed(why: "setsockopt(SO_RCVBUF) returned \(ret)")
    }

    ret = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &option_value, option_len)
    if ret != 0 {
      throw SoftnetError.InitializationFailed(why: "setsockopt(SO_SNDBUF) returned \(ret)")
    }
  }

  func attachment() -> VZNetworkDeviceAttachment {
    let fh = FileHandle.init(fileDescriptor: vmFD)
    return VZFileHandleNetworkDeviceAttachment(fileHandle: fh)
  }
}
