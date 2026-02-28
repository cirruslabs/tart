import Darwin
import Foundation
import Semaphore
import Virtualization

class NetworkFD: Network {
  private let fd: Int32

  init(fd: Int32) throws {
    self.fd = fd

    try Self.validateFD(fd)
    try Self.validateSocketType(fd)
    try Self.validateConnected(fd)
  }

  func attachments() -> [VZNetworkDeviceAttachment] {
    [VZFileHandleNetworkDeviceAttachment(fileHandle: FileHandle(fileDescriptor: fd))]
  }

  func run(_ sema: AsyncSemaphore) throws {
    // no-op, only used for Softnet
  }

  func stop() async throws {
    // no-op, only used for Softnet
  }

  private static func validateFD(_ fd: Int32) throws {
    if fcntl(fd, F_GETFD) == -1 {
      throw RuntimeError.VMConfigurationError(
        "invalid --net-fd \(fd): file descriptor is not open (\(errnoDescription(errno)))"
      )
    }
  }

  private static func validateSocketType(_ fd: Int32) throws {
    var socketType: Int32 = 0
    var optionLength = socklen_t(MemoryLayout<Int32>.size)

    if getsockopt(fd, SOL_SOCKET, SO_TYPE, &socketType, &optionLength) == -1 {
      throw RuntimeError.VMConfigurationError(
        "invalid --net-fd \(fd): file descriptor must reference a socket (\(errnoDescription(errno)))"
      )
    }

    if socketType != SOCK_DGRAM {
      throw RuntimeError.VMConfigurationError(
        "invalid --net-fd \(fd): expected SOCK_DGRAM socket, got \(socketType)"
      )
    }
  }

  private static func validateConnected(_ fd: Int32) throws {
    var address = sockaddr_storage()
    var addressLength = socklen_t(MemoryLayout<sockaddr_storage>.size)

    let result = withUnsafeMutablePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
        getpeername(fd, sockaddrPointer, &addressLength)
      }
    }

    if result == -1 {
      throw RuntimeError.VMConfigurationError(
        "invalid --net-fd \(fd): socket must be connected (\(errnoDescription(errno)))"
      )
    }
  }

  private static func errnoDescription(_ code: CInt) -> String {
    String(cString: strerror(code))
  }
}
