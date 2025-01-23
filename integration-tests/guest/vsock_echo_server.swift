#!/usr/bin/env swift

import Foundation

let VMADDR_CID_ANY: UInt32 = UInt32(bitPattern: -1)
let VSOCK_PORT: UInt32 = 9999

class VSockEchoServer {
  var serverSocket: Int32

  deinit {
    close(serverSocket)
  }

  init(vsockCID: UInt32, vsockPort: UInt32) {
    self.serverSocket = socket(AF_VSOCK, SOCK_STREAM, 0)

    guard serverSocket >= 0 else {
      perror("Socket creation failed")
      exit(1)
    }

    // Configurer l'adresse du socket VSOCK
    var addr = sockaddr_vm()

    addr.svm_len = UInt8(MemoryLayout<sockaddr_vm>.size)
    addr.svm_family = sa_family_t(AF_VSOCK)
    addr.svm_reserved1 = 0
    addr.svm_port = vsockPort
    addr.svm_cid = vsockCID
    addr.svm_reserved1 = 0

    // Lier le socket à l'adresse
    let bindResult = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_vm>.size))
      }
    }

    guard bindResult == 0 else {
      perror("Binding failed")
      exit(1)
    }
  }

  func read_socket(_ socket: Int32) -> [UInt8] {
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

    return messageBuffer
  }

  func write_socket(_ socket: Int32, _ messageBuffer: [UInt8]) {
    let lengthBuffer = withUnsafeBytes(of: messageBuffer.count.bigEndian) {
      var lengthBuffer = [UInt8](repeating: 0, count: 8)

      for i in 0..<$0.count {
        lengthBuffer[i] = $0[i]
      }

      return lengthBuffer
    }

    write(socket, lengthBuffer, lengthBuffer.count)
    write(socket, messageBuffer, messageBuffer.count)
  }

  func accept() -> Int32 {
    var clientAddr = sockaddr_vm()
    var clientAddrLen = socklen_t(MemoryLayout<sockaddr_vm>.size)
    let clientSocket = withUnsafeMutablePointer(to: &clientAddr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Foundation.accept(serverSocket, $0, &clientAddrLen)
      }
    }

    guard clientSocket >= 0 else {
      perror("Accept failed")
      exit(1)
    }

    return clientSocket
  }

  func echo() -> VSockEchoServer {
    print("Waiting connection...")
    let listenResult = listen(serverSocket, 10)

    guard listenResult == 0 else {
      perror("Listening failed")
      exit(1)
    }

    self.writePID(to: "/tmp/vsock_echo.pid")

    let clientSocket = accept()
    print("Connected.")

    var message = read_socket(clientSocket)
    write_socket(clientSocket, message)

    message = read_socket(clientSocket)

    close(clientSocket)
    print("Disconnected.")

    return self
  }

  func writePID(to filePath: String) {
    let pid = getpid()
    let pidString = "\(pid)\n"

    do {
      try pidString.write(toFile: filePath, atomically: true, encoding: .utf8)
    } catch {
      perror("Failed to write PID to file")
      exit(1)
    }
  }

  func disconnect() {
    try? FileManager.default.removeItem(atPath: "/tmp/vsock_echo.pid")

    close(serverSocket)
  }
}

VSockEchoServer(vsockCID: VMADDR_CID_ANY, vsockPort: VSOCK_PORT).echo().disconnect()
