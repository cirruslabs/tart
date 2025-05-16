import ArgumentParser
import Foundation
import NIOPosix
import GRPC
import Cirruslabs_TartGuestAgent_Grpc_Swift

struct ExecCustomExitCodeError: Error {
  let exitCode: Int32
}

struct Exec: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Execute a command in a running VM")

  @Argument(help: "VM name", completion: .custom(completeLocalMachines))
  var name: String

  @Flag(name: [.customShort("i")], help: "Attach host's standard input to a remote command")
  var interactive: Bool = false

  @Flag(name: [.customShort("t")], help: "Allocate a remote pseudo-terminal (PTY)")
  var tty: Bool = false

  @Argument(parsing: .captureForPassthrough, help: "Command to execute")
  var command: [String]

  func run() async throws {
    // Open VM's directory
    let vmDir = try VMStorageLocal().open(name)

    // Ensure that the VM is running
    if try !vmDir.running() {
      throw RuntimeError.VMNotRunning(name)
    }

    // Create a gRPC channel connected to the VM's control socket
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer {
      try! group.syncShutdownGracefully()
    }

    let channel = try GRPCChannelPool.with(
      target: .unixDomainSocket(vmDir.controlSocketURL.path()),
      transportSecurity: .plaintext,
      eventLoopGroup: group,
    )
    defer {
      try! channel.close().wait()
    }

    // Switch controlling terminal into raw mode when remote pseudo-terminal is requested
    var state: State? = nil

    if tty && Term.IsTerminal() {
      state = try Term.MakeRaw()
    }
    defer {
      // Restore terminal to its initial state
      if let state {
        try! Term.Restore(state)
      }
    }

    // Execute a command in a running VM
    let agentAsyncClient = AgentAsyncClient(channel: channel)
    let execCall = agentAsyncClient.makeExecCall()

    try await execCall.requestStream.send(.with {
      $0.type = .command(.with {
        $0.name = command[0]
        $0.args = Array(command.dropFirst(1))
        $0.interactive = interactive
        $0.tty = tty
        $0.terminalSize = .with {
          let (width, height) = try! Term.GetSize()

          $0.cols = UInt32(width)
          $0.rows = UInt32(height)
        }
      })
    })

    // Process command events and optionally send our standard input and/or terminal dimensions
    try await withThrowingTaskGroup { group in
      // Stream host's standard input if interactive mode is enabled
      if interactive {
        let stdinStream = AsyncStream<Data> { continuation in
          let handle = FileHandle.standardInput

          handle.readabilityHandler = { handle in
            let data = handle.availableData

            continuation.yield(data)

            if data.isEmpty {
              continuation.finish()
            }
          }
        }

        group.addTask {
          for await stdinData in stdinStream {
            try await execCall.requestStream.send(.with {
              $0.type = .standardInput(.with {
                $0.data = stdinData
              })
            })
          }
        }
      }

      // Stream host's terminal dimensions if pseudo-terminal is requested
      signal(SIGWINCH, SIG_IGN)
      let sigwinchSrc = DispatchSource.makeSignalSource(signal: SIGWINCH)
      sigwinchSrc.activate()

      if tty {
        let terminalDimensionsStream = AsyncStream { continuation in
          sigwinchSrc.setEventHandler {
            continuation.yield(try! Term.GetSize())
          }
        }

        group.addTask {
          for await (width, height) in terminalDimensionsStream {
            try await execCall.requestStream.send(.with {
              $0.type = .terminalResize(.with {
                $0.cols = UInt32(width)
                $0.rows = UInt32(height)
              })
            })
          }
        }
      }

      // Process command events
      group.addTask {
        for try await response in execCall.responseStream {
          switch response.type {
          case .standardOutput(let ioChunk):
            try FileHandle.standardOutput.write(contentsOf: ioChunk.data)
          case .standardError(let ioChunk):
            try FileHandle.standardError.write(contentsOf: ioChunk.data)
          case .exit(let exit):
            throw ExecCustomExitCodeError(exitCode: exit.code)
          default:
            // Unknown event, do nothing
            continue
          }
        }
      }

      while !group.isEmpty {
        do {
          try await group.next()
        } catch {
          group.cancelAll()

          throw error
        }
      }
    }
  }
}
