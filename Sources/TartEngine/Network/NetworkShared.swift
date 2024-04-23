import Foundation
import Semaphore
import Virtualization

package class NetworkShared: Network {

  package init() {

  }

  package func attachments() -> [VZNetworkDeviceAttachment] {
    [VZNATNetworkDeviceAttachment()]
  }

  package func run(_ sema: AsyncSemaphore) throws {
    // no-op, only used for Softnet
  }

  package func stop() async throws {
    // no-op, only used for Softnet
  }
}
