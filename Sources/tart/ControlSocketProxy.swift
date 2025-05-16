import Foundation
import Network
import Virtualization
import Logging
import System

let bufferSize: Int = 4096

final class ControlSocketProxy {
  private let left: NWConnection
  private let right: VZVirtioSocketConnection
  private var source: DispatchSourceRead
  private var completionContinuation: CheckedContinuation<Void, Never>?
  let logger: Logging.Logger = Logging.Logger(label: "org.cirruslabs.tart.control-socket.proxy")

  init(queue: DispatchQueue, left: NWConnection, right: VZVirtioSocketConnection) {
    self.left = left
    self.right = right
    self.source = DispatchSource.makeReadSource(fileDescriptor: self.right.fileDescriptor, queue: queue)
  }

  func run() async {
    await withCheckedContinuation { continuation in
      self.completionContinuation = continuation

      // Receive from left, send to right
      self.receiveFromLeft()

      // Receive from right, send to left
      self.receiveFromRight()
    }
  }

  func receiveFromLeft() {
    self.left.receive(minimumIncompleteLength: 0, maximumLength: bufferSize, completion: { (data, _, _, _) in
      guard let data = data else {
        self.cancelAll()

        return
      }

      // Send to right
      let ret = data.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) in
        write(self.right.fileDescriptor, rawBufferPointer.baseAddress, rawBufferPointer.count)
      }
      if ret == -1 {
        let details = Errno(rawValue: CInt(errno))

        self.logger.warning("write(2) to right failed: \(details)")

        self.cancelAll()

        return
      }

      // Re-arm
      self.receiveFromLeft()
    })
  }

  func receiveFromRight() {
    self.source.setEventHandler { [weak self] in
      guard let self = self else { return }

      var buffer = [UInt8](repeating: 0, count: bufferSize)
      let bytesRead = read(self.right.fileDescriptor, &buffer, buffer.count)

      if bytesRead > 0 {
        self.left.send(content: buffer[..<bytesRead], completion: .idempotent)
      } else if bytesRead == 0 {
        // EOF
        self.cancelAll()
      } else {
        let details = Errno(rawValue: CInt(errno))

        self.logger.warning("read(2) from right failed: \(details)")

        self.cancelAll()
      }
    }

    self.source.setCancelHandler {
      self.right.close()
    }

    self.source.resume()
  }

  private func cancelAll() {
    self.logger.info("terminating")

    self.left.cancel()
    self.source.cancel()

    completionContinuation?.resume()
    completionContinuation = nil
  }
}
