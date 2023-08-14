import Foundation
import Virtualization

class NetworkShared: Network {
  func attachments() -> [VZNetworkDeviceAttachment] {
    [VZNATNetworkDeviceAttachment()]
  }

  func run(_ sema: DispatchSemaphore) throws {
    // no-op, only used for Softnet
  }

  func stop() async throws {
    // no-op, only used for Softnet
  }
}
