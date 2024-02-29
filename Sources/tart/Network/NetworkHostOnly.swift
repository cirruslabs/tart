import Dynamic
import Foundation
import Virtualization

class NetworkHostOnly: Network {
  func attachments() -> [VZNetworkDeviceAttachment] {
    [Dynamic._VZHostOnlyNetworkDeviceAttachment()!]
  }

  func run(_ sema: DispatchSemaphore) throws {
    // no-op, only used for Softnet
  }

  func stop() async throws {
    // no-op, only used for Softnet
  }
}
