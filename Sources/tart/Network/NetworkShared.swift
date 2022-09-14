import Foundation
import Virtualization

class NetworkShared: Network {
    func attachment() -> VZNetworkDeviceAttachment {
        VZNATNetworkDeviceAttachment()
    }

    func run() throws {
        // no-op, only used for Softnet
    }

    func stop() throws {
        // no-op, only used for Softnet
    }
}
