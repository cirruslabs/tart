import Foundation
import NIOCore
import NIOPosix
import Virtualization

enum SocketMode: String, Codable {
  case bind = "bind"  // Listen on unix socket
  case connect = "connect"  // Connect to unix socket
  case tcp = "tcp"  // Listen on tcp socket
  case udp = "udp"  // Listen on udp socket
  case fd = "fd"  // File descriptor
}

struct SocketDevice: Codable {
  var mode: SocketMode = .bind
  var port: Int = -1
  var bind: String
}

extension SocketDevice: CustomStringConvertible {
  var description: String {
    
    if mode == .bind || mode == .connect {
      return "\(mode)://vsock:\(port)\(bind)"
    }

    return "\(mode)://\(bind):\(port)"
  }

  init(description: String) throws {
    guard let url = URL(string: description) else {
      throw RuntimeError.VMConfigurationError("unsupported socket declaration: \"\(description)\"")
    }

    guard let scheme = url.scheme else {
      throw RuntimeError.VMConfigurationError("unsupported socket declaration: \"\(description)\"")
    }

    guard let mode = SocketMode(rawValue: scheme) else {
      throw RuntimeError.VMConfigurationError("unsupported socket mode: \"\(description)\"")
    }

    guard let port = url.port else {
      throw RuntimeError.VMConfigurationError("port number must be defined")
    }

    guard let host: String = url.host, !host.isEmpty else {
      throw RuntimeError.VMConfigurationError("host must be defined")
    }

    if port < 1024 {
      throw RuntimeError.VMConfigurationError("port number must be greater than 1023")
    }

    self.mode = mode
    self.port = port

    if mode == .fd {
      let fds = host.split(separator: ",")
      
      if fds.count == 0 {
        throw RuntimeError.VMConfigurationError("Invalid file descriptor")
      }

      for fd in fds {
        guard let fd = Int32(fd) else {
          throw RuntimeError.VMConfigurationError("Invalid file descriptor fd=\(fd)")
        }

        if fcntl(fd, F_GETFD) == -1 {
          throw RuntimeError.VMConfigurationError("File descriptor is not valid errno=\(errno)")
        }
      }

      self.bind = host
    } else if mode == .tcp || mode == .udp {
      self.bind = host
    } else {
      if url.path.isEmpty {
        throw RuntimeError.VMConfigurationError("socket path must be defined")
      }

      if url.path.utf8.count > 103 {
          throw RuntimeError.VMConfigurationError("The socket path is too long")
      }

      self.bind = url.path
    }
  }
}

class SocketState {
  let mode: SocketMode
  let port: Int
  let bind: String
  var connection: VZVirtioSocketConnection?
  var channel: Channel?

  var description: String {
    if mode == .tcp || mode == .udp || mode == .fd {
      return "\(mode)://\(bind):\(port)"
    }

    return "unix:\(bind)"
  }

  init(vsock: SocketDevice) {
    self.mode = vsock.mode
    self.port = vsock.port
    self.bind = vsock.bind
    self.connection = nil
  }

  func isFileDescriptorOpen(_ fd: Int32) -> Bool {
    return fcntl(fd, F_GETFD) != -1 || errno != EBADF
  }

  // Called when the guest vsock is closed by remote or host socket is closed
  func closedByRemote() -> Channel? {
    let channel = self.channel

    if let connection = self.connection {
      connection.close()

      self.connection = nil
      self.channel = nil

      defaultLogger.appendNewLine("Socket connection on \(self.description) is closed by remote")
    }

    return channel
  }

  // Check if the connection is broken
  func haveBeenDisconnected() -> Channel? {
    if let connection = connection {
      if self.isFileDescriptorOpen(connection.fileDescriptor) == false {
        self.connection = nil

        if let channel = channel {
          channel.close().whenComplete { _ in
            defaultLogger.appendNewLine("Socket connection on \(self.description) was closed by remote")
          }

          self.channel = nil

          return channel
        } else {
          defaultLogger.appendNewLine("Socket connection on \(self.description) is broken")
        }
      }
    }

    return nil
  }

  func fileDescriptors() -> (Int32, Int32) {
    let fd = bind.split(separator: Character(",")).map { Int32($0) ?? 1 }

    return (fd[0], fd.count == 2 ? fd[1] : dup(fd[0]))
  }
}

class VirtioSocketDevices: NSObject, VZVirtioSocketListenerDelegate, CatchRemoteCloseDelegate {
  private let queue = DispatchQueue(label: "com.cirruslabs.VirtualSocketQueue")
  private let mainGroup: EventLoopGroup
  private var sockets: [Int: SocketState]
  private var channels: [Channel]
  private var socketDevice: VZVirtioSocketDevice?
  private var idle: RepeatedTask?

  deinit {
    try? mainGroup.syncShutdownGracefully()
  }

  private init(on: EventLoopGroup, sockets: [SocketDevice]) {
    var socketStates: [Int: SocketState] = [:]

    for socket in sockets.map({ SocketState(vsock: $0) }) {
      socketStates[socket.port] = socket
    }

    self.channels = []
    self.sockets = socketStates
    self.mainGroup = on
  }

  // Close all channels
  func close() {
    if self.channels.isEmpty {
      return
    }

    let eventLoop = mainGroup.next()

    _ = try? EventLoopFuture.whenAllComplete(
      self.sockets.map { socket in
        // The socket is connected with a channel
        if let channel = socket.value.channel {
          return self.queue.sync {
            self.channels.removeAll { $0 === channel }

            let futureResult: EventLoopFuture<Void> = channel.close()
            // When the channel is closed, close the connection
            futureResult.whenComplete { _ in
              if let connection = socket.value.connection {
                connection.close()
              }
            }

            return futureResult
          }
        } else {
          // Maybe the host connection is not established yet but guest connection is already established
          if let connection = socket.value.connection {
            connection.close()
          }

          // Make happy the event loop
          return eventLoop.makeSucceededFuture(())
        }
      }, on: eventLoop
    ).wait()
  }

  func closedByRemote(port: Int) {
    if let socket = sockets[port] {

      if let channel = socket.closedByRemote() {
        self.queue.sync {
          self.channels.removeAll { $0 === channel }
        }
      }
    }
  }

  // The guest initiates the connection to the host, the host must listen for the connection on the port
  private func connectionInitiatedByGuest(inboundChannel: Channel, connection: VZVirtioSocketConnection)
    -> EventLoopFuture<Void>
  {
    return NIOPipeBootstrap(group: inboundChannel.eventLoop)
      .takingOwnershipOfDescriptor(inputOutput: dup(connection.fileDescriptor))
      .flatMap { childChannel in
        let (ours, theirs) = GlueHandler.matchedPair()

        return childChannel.pipeline.addHandlers([
          CatchRemoteClose(port: Int(connection.destinationPort), delegate: self), ours,
        ])
        .flatMap {
          inboundChannel.pipeline.addHandlers([
            CatchRemoteClose(port: Int(connection.destinationPort), delegate: self), theirs,
          ])
        }
      }
  }

  // The host initiates the connection to the guest, the guest must listen for the connection on the port
  private func connectionInitiatedByHost(inboundChannel: Channel, socketDevice: VZVirtioSocketDevice, port: Int)
    -> EventLoopFuture<Void>
  {
    // Create a promise to notify the connection status
    let promise: EventLoopPromise<Void> = inboundChannel.eventLoop.makePromise(of: Void.self)

    // Try to connect to the socket device, if the connection is successful, start nio pipe
    socketDevice.connect(toPort: UInt32(port)) { result in
      switch result {
      case let .success(connection):

        guard let socket = self.sockets[port] else {
          promise.fail(RuntimeError.VMConfigurationError("Socket device not found on port:\(port)"))
          return
        }

        // Keep the connection for the socket
        socket.connection = connection

        do {
          // Pipe the connection to the channel
          try NIOPipeBootstrap(group: inboundChannel.eventLoop)
            .takingOwnershipOfDescriptor(inputOutput: dup(connection.fileDescriptor))
            .flatMap { childChannel in
              let (ours, theirs) = GlueHandler.matchedPair()

              return childChannel.pipeline.addHandlers([CatchRemoteClose(port: port, delegate: self), ours])
                .flatMap {
                  inboundChannel.pipeline.addHandlers([CatchRemoteClose(port: port, delegate: self), theirs])
                }
            }.wait()

          // Notify the promise that the connection is successful
          promise.succeed(())
        } catch {
          defaultLogger.appendNewLine("Failed to connect to socket device on port:\(port), \(error)")
          promise.fail(error)
        }
      case let .failure(error):
        defaultLogger.appendNewLine("Failed to connect to socket device on port:\(port), \(error)")
        // Notify the promise that the connection is failed
        promise.fail(error)
      }
    }

    return promise.futureResult
  }

  func connect(virtualMachine: VZVirtualMachine) {
    if let socketDevice: VZVirtioSocketDevice = virtualMachine.socketDevices.first as? VZVirtioSocketDevice {
      // Keep the socket device
      self.socketDevice = socketDevice
      let eventLoop = mainGroup.next()

      // Start the idle task to check broken connections
      // If the connection is broken, close the channel
      // Needed because we don't have a way to listen for the channel close event
      self.idle = eventLoop.scheduleRepeatedAsyncTask(
        initialDelay: TimeAmount.seconds(10), delay: TimeAmount.milliseconds(500)
      ) {
        RepeatedTask in

        return self.queue.sync {
          self.sockets.forEach { port, socket in
            if let channel = socket.haveBeenDisconnected() {
              self.channels.removeAll { $0 === channel }
            }
          }

          return eventLoop.makeSucceededVoidFuture()
        }
      }

      let listener: VZVirtioSocketListener = VZVirtioSocketListener()

      listener.delegate = self

      // Set the listener delegate for each socket
      self.sockets.forEach { port, socket in
        let channel: EventLoopFuture<Channel>

        // Add the listener to the socket device for the port
        socketDevice.setSocketListener(listener, forPort: UInt32(port))

        if socket.mode == .bind || socket.mode == .tcp || socket.mode == .udp {
          let channelInitializer: @Sendable (Channel) -> EventLoopFuture<Void> = { channel in
            // Here we connect to the guest socket device
            if let connection = socket.connection {
              // The connection is initiated by the guest
              return self.connectionInitiatedByGuest(inboundChannel: channel, connection: connection)
            } else {
              // The connection is initiated by the host
              // !!! This is a blocking call, we need to run it on the main thread !!!
              return DispatchQueue.main.sync {
                return self.connectionInitiatedByHost(inboundChannel: channel, socketDevice: socketDevice, port: port)
              }
            }
          }

          if socket.mode == .udp {
            // Start listening on the udp socket
            let bootstrap = DatagramBootstrap(group: mainGroup)
              .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
              .channelInitializer(channelInitializer)

            // Bind udp socket to the port
            channel = bootstrap.bind(host: socket.bind, port: port)
          } else if socket.mode == .tcp {
            // Start listening on tcp socket
            let bootstrap = ServerBootstrap(group: mainGroup)
              .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
              .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
              .childChannelInitializer(channelInitializer)

              // Bind tcp socket to the port
              channel = bootstrap.bind(host: socket.bind, port: port)
          } else {
            // Start listening on unix socket
            let bootstrap = ServerBootstrap(group: mainGroup)
              .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
              .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
              .childChannelInitializer(channelInitializer)

              // Bind the unix socket device to the port
              // ??? We need to unlink the unix socket before binding the socket ???
              channel = bootstrap.bind(unixDomainSocketPath: socket.bind, cleanupExistingSocketFile: true)
          }

          // Get the channel to be ready
          channel.whenComplete { result in
            self.queue.sync {
              switch result {
              case let .success(channel):
                self.channels.append(channel)
                self.sockets[port]?.channel = channel
                defaultLogger.appendNewLine("Socket device connected on \(socket.description)")
              case let .failure(error):
                defaultLogger.appendNewLine("Failed to connect socket device on \(socket.description), \(error)")
              }
            }
          }
        }
      }
    }
  }

  func listener(
    _ listener: VZVirtioSocketListener,
    shouldAcceptNewConnection connection: VZVirtioSocketConnection,
    from socketDevice: VZVirtioSocketDevice
  ) -> Bool {
    // The connection is initiated by the guest
    guard let socket = sockets[Int(connection.destinationPort)] else {
      // Unbound socket port
      return false
    }

    if socket.mode == .connect {
      do {
        // Connect to the unix socket
        return try self.queue.sync {
          let channel = try ClientBootstrap(group: mainGroup)
            .channelInitializer { channel in
              // The connection is initiated by the guest
              return self.connectionInitiatedByGuest(inboundChannel: channel, connection: connection)
            }
            .connect(unixDomainSocketPath: socket.bind).wait()

          // Ok to accept the connection
          self.channels.append(channel)
          socket.channel = channel
          socket.connection = connection

          return true
        }
      } catch {
        // Reject vsock connection if the connection to unix socket failed
        defaultLogger.appendNewLine("Failed to connect the socket device on \(socket.description), \(error)")
        return false
      }
    } else if socket.mode == .fd {
      // The connection is initiated by the guest
      do {
        return try self.queue.sync {
          let (input, output) = socket.fileDescriptors()

          let channel = try NIOPipeBootstrap(group: mainGroup)
            .channelInitializer { channel in
              // The connection is initiated by the guest
              return self.connectionInitiatedByGuest(inboundChannel: channel, connection: connection)
            }
            .takingOwnershipOfDescriptors(input: dup(input), output: dup(output)).wait()

          // Ok to accept the connection
          self.channels.append(channel)
          socket.channel = channel
          socket.connection = connection

          return true
        }
      } catch {
        // Reject vsock connection if the connection to unix socket failed
        defaultLogger.appendNewLine("Failed to connect the socket device on \(socket.description), \(error)")
        return false
      }
    
    }

    // Assume the connection is possible in bind mode
    socket.connection = connection

    return true
  }

  private func configure(configuration: VZVirtualMachineConfiguration) -> VirtioSocketDevices {
    if self.sockets.isEmpty {
      return self
    }

    configuration.socketDevices.append(VZVirtioSocketDeviceConfiguration())

    return self
  }

  static func setupVirtioSocketDevices(
    on: EventLoopGroup,
    configuration: VZVirtualMachineConfiguration, sockets: [SocketDevice]
  ) -> VirtioSocketDevices {
    return VirtioSocketDevices(on: on, sockets: sockets).configure(configuration: configuration)
  }
}
