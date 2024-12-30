import Darwin.POSIX
import Foundation
import NIOCore
import NIOPosix
import Virtualization

final class ConsoleDevice: CatchRemoteCloseDelegate {
  let mainGroup: EventLoopGroup
  let consoleURL: URL
  var channel: Channel?
  var pipeChannel: Channel?

  private init(on: EventLoopGroup, consoleURL: URL) {
    //self.consoleSocket = URL(fileURLWithPath: "tart-agent.sock", isDirectory: false, relativeTo: diskURL).absoluteURL
    self.consoleURL = consoleURL
    self.mainGroup = on
  }

  private func setChannel(_ channel: any NIOCore.Channel) {
    self.channel = channel
  }

  private func createUnixConsole() -> (FileHandle, FileHandle){
    let inputPipe = Pipe()
    let outputPipe = Pipe()

    let bootstrap: ServerBootstrap = ServerBootstrap(group: self.mainGroup)
      .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .childChannelOption(.maxMessagesPerRead, value: 16)
      .childChannelOption(.recvAllocator, value: AdaptiveRecvByteBufferAllocator())  
      .childChannelInitializer { inboundChannel in
        // Dup fd pipe because nio close it then the socket is closed
        let input = dup(inputPipe.fileHandleForReading.fileDescriptor)
        let output = dup(outputPipe.fileHandleForWriting.fileDescriptor)

        // When the child channel is created, create a new pipe and add the handlers
        return NIOPipeBootstrap(group: inboundChannel.eventLoop)
          .takingOwnershipOfDescriptors(input: input, output: output)
          .flatMap { childChannel in
            let (ours, theirs) = GlueHandler.matchedPair()

            self.pipeChannel = childChannel

            return childChannel.pipeline.addHandlers([CatchRemoteClose(port: 1, delegate: self), ours])
              .flatMap {
                inboundChannel.pipeline.addHandlers([CatchRemoteClose(port: 0, delegate: self), theirs])
              }
          }
      }

    // Listen on the console socket
    let binder = bootstrap.bind(unixDomainSocketPath: self.consoleURL.path(), cleanupExistingSocketFile: true)

    // When the bind is complete, set the channel
    binder.whenComplete { result in
      switch result {
      case let .success(channel):
        self.setChannel(channel)
        defaultLogger.appendNewLine("Console listening on \(self.consoleURL.absoluteString)")
      case let .failure(error):
        defaultLogger.appendNewLine("Failed to bind console on \(self.consoleURL.absoluteString), \(error)")
      }
    }

    return (outputPipe.fileHandleForReading, inputPipe.fileHandleForWriting)
  }

  private func create(configuration: VZVirtualMachineConfiguration) throws -> ConsoleDevice {
    let consolePort: VZVirtioConsolePortConfiguration = VZVirtioConsolePortConfiguration()
    let consoleDevice: VZVirtioConsoleDeviceConfiguration = VZVirtioConsoleDeviceConfiguration()
    let fileHandleForReading: FileHandle
    let fileHandleForWriting: FileHandle

    if self.consoleURL.scheme == "unix" || self.consoleURL.isFileURL {
      (fileHandleForReading, fileHandleForWriting) = createUnixConsole()
    } else if let host = self.consoleURL.host(), self.consoleURL.scheme == "fd" {
      // fd://0,1
      let fd = host.split(separator: Character(","))

      fileHandleForReading = FileHandle(fileDescriptor: Int32(fd[0])!, closeOnDealloc: false)

      if fd.count == 2 {
        fileHandleForWriting = FileHandle(fileDescriptor: Int32(fd[1])!, closeOnDealloc: false)
      } else {
        fileHandleForWriting = FileHandle(fileDescriptor: dup(Int32(fd[0])!), closeOnDealloc: false)
      }
    } else {
      throw RuntimeError.VMConfigurationError("Unsupported console URL \(self.consoleURL.absoluteString)")
    }

    // Create console device attachement
    //To send data to the guest operating system, write data to the file handle in the fileHandleForReading property.
    //To receive data from the guest operating system, read data from the file handle in the fileHandleForWriting property.
    consolePort.name = "tart-agent"
    consolePort.attachment = VZFileHandleSerialPortAttachment(
      fileHandleForReading: fileHandleForReading,
      fileHandleForWriting: fileHandleForWriting)

    consoleDevice.ports[0] = consolePort

    configuration.consoleDevices.append(consoleDevice)


    return self
  }

  func close() {
    if let channel {
      let closeFuture = channel.close()

      closeFuture.whenComplete { result in
        switch result {
        case .success:
          defaultLogger.appendNewLine("Console closed \(self.consoleURL.absoluteString)")
        case let .failure(error):
          defaultLogger.appendNewLine("Failed to close console \(self.consoleURL.absoluteString), \(error)")
        }
      }

      try? closeFuture.wait()
    }
  }

  func closedByRemote(port: Int) {
    if self.pipeChannel != nil {
      self.pipeChannel = nil

      if port == 0 {
        defaultLogger.appendNewLine("Console closed by the host on \(self.consoleURL.absoluteString)")
      } else {
        defaultLogger.appendNewLine("Console closed by the guest on \(self.consoleURL.absoluteString)")
      }
    }
  }

  static public func setupConsole(on: EventLoopGroup, consoleURL: URL, configuration: VZVirtualMachineConfiguration) throws  -> ConsoleDevice{
    try ConsoleDevice(on: on, consoleURL: consoleURL).create(configuration: configuration)
  }
}
