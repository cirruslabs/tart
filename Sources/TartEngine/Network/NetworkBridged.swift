import Foundation
import Semaphore
import Virtualization

package class NetworkBridged: Network {
  let interfaces: [VZBridgedNetworkInterface]

  package init(interfaces: [VZBridgedNetworkInterface]) {
    self.interfaces = interfaces
  }

  package func attachments() -> [VZNetworkDeviceAttachment] {
    interfaces.map { VZBridgedNetworkDeviceAttachment(interface: $0) }
  }

  package func run(_ sema: AsyncSemaphore) throws {
    // no-op, only used for Softnet
  }

  package func stop() async throws {
    // no-op, only used for Softnet
  }
}
