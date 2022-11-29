import Foundation
import Virtualization

class NetworkBridged: Network {
  let interface: VZBridgedNetworkInterface

  init(interface: VZBridgedNetworkInterface) {
    self.interface = interface
  }

  func attachment() -> VZNetworkDeviceAttachment {
    VZBridgedNetworkDeviceAttachment(interface: interface)
  }

  func run(_ sema: DispatchSemaphore) throws {
    // no-op, only used for Softnet
  }

  func stop() async throws {
    // no-op, only used for Softnet
  }
}
