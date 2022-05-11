import Foundation

enum SoftnetError: Error {
  case InitializationFailed(why: String)
}

class Softnet {
  let binaryURL: URL

  let vmFD: Int32
  let softnetFD: Int32

  init() throws {
    let binaryName = "softnet"

    if let url = Self.resolveBinaryPath(binaryName) {
      binaryURL = url
    } else {
      throw SoftnetError.InitializationFailed(why: "\(binaryName) not found in PATH")
    }

    let fds = UnsafeMutablePointer<Int32>.allocate(capacity: MemoryLayout<Int>.stride * 2)

    let ret = socketpair(AF_UNIX, SOCK_DGRAM, 0, fds)
    if ret != 0 {
      throw SoftnetError.InitializationFailed(why: "socketpair() failed with exit code \(ret)")
    }

    vmFD = fds[0]
    softnetFD = fds[1]

    try setSocketBuffers(vmFD, 1 * 1024 * 1024);
    try setSocketBuffers(softnetFD, 1 * 1024 * 1024);
  }

  func run() throws {
    let proc = Process()

    proc.executableURL = binaryURL
    proc.standardInput = FileHandle(fileDescriptor: softnetFD, closeOnDealloc: false)

    try proc.run()
  }

  private static func resolveBinaryPath(_ name: String) -> URL? {
    guard let path = ProcessInfo.processInfo.environment["PATH"] else {
      return nil
    }

    for pathComponent in path.split(separator: ":") {
      let url = URL(fileURLWithPath: String(pathComponent))
              .appendingPathComponent(name, isDirectory: false)

      if FileManager.default.fileExists(atPath: url.path) {
        return url
      }
    }

    return nil
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
}
