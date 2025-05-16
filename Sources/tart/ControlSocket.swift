import Foundation
import Network
import Logging

class ControlSocket {
  let controlSocketURL: URL
  let vmPort: UInt32
  let queue: DispatchQueue = DispatchQueue.global(qos: .userInitiated)
  let logger: Logging.Logger = Logging.Logger(label: "org.cirruslabs.tart.control-socket")

  init(_ controlSocketURL: URL, vmPort: UInt32 = 8080) {
    self.controlSocketURL = controlSocketURL
    self.vmPort = vmPort
  }

  func run() async throws {
    // Remove control socket file from previous "tart run" invocations,
    // if any, otherwise we may get the "address already in use" error
    try? FileManager.default.removeItem(atPath: controlSocketURL.path())

    let parameters = NWParameters()
    parameters.defaultProtocolStack.transportProtocol = NWProtocolTCP.Options()
    parameters.requiredLocalEndpoint = NWEndpoint.unix(path: controlSocketURL.path())

    let listener = try NWListener(using: parameters)

    listener.newConnectionHandler = { connection in
      self.logger.info("received new control socket connection from a client")

      connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
          Task {
            self.logger.info("dialing to \(vm) on port \(self.vmPort)...")

            do {
              guard let vmConnection = try await vm?.connect(toPort: self.vmPort) else {
                throw RuntimeError.VMSocketFailed(self.vmPort, "VM is not running")
              }

              self.logger.info("running control socket proxy")

              await ControlSocketProxy(queue: self.queue, left: connection, right: vmConnection).run()

              self.logger.info("control socket client disconnected")
            } catch (let error) {
              self.logger.error("control socket connection failed: \(error)")

              connection.cancel()
            }
          }
        default:
          // Do nothing
          return
        }
      }

      connection.start(queue: self.queue)
    }

    try await withCheckedThrowingContinuation { continuation in
      listener.stateUpdateHandler = { state in
        switch state {
        case .ready:
          continuation.resume(returning: ())
        case .failed(let error):
          continuation.resume(throwing: error)
        default:
          // Do nothing
          return
        }
      }

      listener.start(queue: self.queue)
    }
  }
}
