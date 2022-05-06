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
}
