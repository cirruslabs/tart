import Foundation
import Semaphore
import Virtualization

class NetworkBridged: Network {
  let interfaces: [VZBridgedNetworkInterface]

  init(interfaces: [VZBridgedNetworkInterface]) {
    self.interfaces = interfaces
  }

  func attachments() -> [VZNetworkDeviceAttachment] {
    interfaces.map { VZBridgedNetworkDeviceAttachment(interface: $0) }
  }

  func run(_ sema: AsyncSemaphore) throws {
    // no-op, only used for Softnet
  }

  func stop() async throws {
    // no-op, only used for Softnet
  }
}
