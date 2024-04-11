import ArgumentParser
import Foundation
import System
import SwiftDate

struct Suspend: AsyncParsableCommand {
  static var configuration = CommandConfiguration(commandName: "suspend", abstract: "Suspend a VM")

  @Argument(help: "VM name", completion: .custom(completeRunningMachines))
  var name: String

  func run() async throws {
    let vmDir = try VMStorageLocal().open(name)
    let lock = try vmDir.lock()

    // Find the VM's PID
    let pid = try lock.pid()
    if pid == 0 {
      throw RuntimeError.VMNotRunning("VM \"\(name)\" is not running")
    }

    // Tell the "tart run" process to suspend the VM
    let ret = kill(pid, SIGUSR1)
    if ret != 0 {
      throw RuntimeError.SuspendFailed("failed to send SIGUSR1 signal to the \"tart run\" process running VM \"\(name)\"")
    }
  }
}
