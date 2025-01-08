import Foundation
import NIOCore
import NIOPosix
import Virtualization

// This class represents the console device and socket devices that is used to communicate with the virtual machine.
class CommunicationDevices {
  let mainGroup: EventLoopGroup
  let virtioSocketDevices: VirtioSocketDevices
  let consoleDevice: ConsoleDevice

  deinit {  
    try? mainGroup.syncShutdownGracefully()
  }

  private init(configuration: VZVirtualMachineConfiguration, consoleURL: URL?, sockets: [SocketDevice]) throws {
    let mainGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    self.mainGroup = mainGroup
    self.virtioSocketDevices = VirtioSocketDevices.setupVirtioSocketDevices(on: mainGroup, configuration: configuration, sockets: sockets)
    self.consoleDevice = try ConsoleDevice.setupConsole(on: mainGroup, consoleURL: consoleURL, configuration: configuration)
  }

  // Close the communication devices
  public func close() {
    virtioSocketDevices.close()
    consoleDevice.close()
  }

  // Connect the virtual machine to the devices
  public func connect(virtualMachine: VZVirtualMachine) {
    virtioSocketDevices.connect(virtualMachine: virtualMachine)
  }

  // Create the communication devices console and socket devices
  public static func setup(configuration: VZVirtualMachineConfiguration, consoleURL: URL?, sockets: [SocketDevice]) throws -> CommunicationDevices {
    return try CommunicationDevices(configuration: configuration, consoleURL: consoleURL, sockets: sockets)
  }
}
