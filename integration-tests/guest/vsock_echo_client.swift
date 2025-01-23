#!/usr/bin/env swift

import Foundation

let VMADDR_CID_HOST: UInt32 = 2
let VSOCK_PORT: UInt32 = 9999

class VsockEchoClient {
  let vsockPort: UInt32
  let vsockCID: UInt32
  var socketFD: Int32

  init(vsockCID: UInt32, vsockPort: UInt32) {
    self.vsockCID = vsockCID
    self.vsockPort = vsockPort
    self.socketFD = -1
  }

  func read_socket(_ socket: Int32) -> String {
    var lengthBuffer = [UInt8](repeating: 0, count: 8)
    let lengthRead = recv(socket, &lengthBuffer, 8, MSG_WAITALL)

    guard lengthRead > 0 else {
      perror("Read message length failed")
      exit(1)
    }

    let length = lengthBuffer.withUnsafeBytes {
      $0.load(as: Int.self).bigEndian
    }

    print("Read message length: \(length)")

    var messageBuffer = [UInt8](repeating: 0, count: length)
    let messageRead = recv(socket, &messageBuffer, length, MSG_WAITALL)

    guard messageRead > 0 else {
      perror("Read message failed")
      exit(1)
    }

    guard let message = String(bytes: messageBuffer, encoding: .utf8) else {
      perror("Message decoding failed")
      exit(1)
    }

    return message
  }

  func write_socket(_ socket: Int32, _ message: String) {
    let messageData = message.data(using: .utf8)!
    let messageBuffer = [UInt8](messageData)
    let lengthBuffer = withUnsafeBytes(of: message.utf8.count.bigEndian) {
      var lengthBuffer = [UInt8](repeating: 0, count: 8)

      for i in 0..<$0.count {
        lengthBuffer[i] = $0[i]
      }

      return lengthBuffer
    }

    write(socket, lengthBuffer, lengthBuffer.count)
    write(socket, messageBuffer, messageBuffer.count)
  }

  func etablish() -> VsockEchoClient {
    let socketFD = socket(AF_VSOCK, SOCK_STREAM, 0)
    guard socketFD >= 0 else {
      perror("Failed to create socket")
      exit(1)
    }

    print("AF_VSOCK=\(AF_VSOCK), SOCK_STREAM=\(SOCK_STREAM)")

    var addr = sockaddr_vm()
    addr.svm_len = UInt8(MemoryLayout<sockaddr_vm>.size)
    addr.svm_family = sa_family_t(AF_VSOCK)
    addr.svm_cid = vsockCID
    addr.svm_port = vsockPort
    addr.svm_reserved1 = 0

    let addrSize = socklen_t(MemoryLayout<sockaddr_vm>.size)
    let connectResult = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(socketFD, $0, addrSize)
      }
    }

    guard connectResult >= 0 else {
      perror("Failed to connect to vsock socket")
      exit(1)
    }

    print("Connected to vsock socket")

    self.socketFD = socketFD

    return self
  }

  func echo() -> VsockEchoClient {
    var message = read_socket(socketFD)
    write_socket(socketFD, message)

    message = read_socket(socketFD)

    return self
  }

  func disconnect() {
    close(socketFD)
  }
}

VsockEchoClient(vsockCID: VMADDR_CID_HOST, vsockPort: VSOCK_PORT).etablish().echo().disconnect()
