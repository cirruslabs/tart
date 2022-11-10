import ArgumentParser
import Foundation
import System
import SwiftDate

struct Stop: AsyncParsableCommand {
  static var configuration = CommandConfiguration(commandName: "stop", abstract: "Stop a VM")

  @Argument(help: "VM name")
  var name: String

  @Option(name: [.short, .long], help: "Seconds to wait for graceful termination before forcefully terminating the VM")
  var timeout: UInt64 = 30

  func run() async throws {
    do {
      let vmDir = try VMStorageLocal().open(name)
      let lock = try PIDLock(lockURL: vmDir.configURL)

      // Find the VM's PID
      var pid = try lock.pid()
      if pid == 0 {
        print("VM \(name) is not running")

        Foundation.exit(1)
      }

      // Try to gracefully terminate the VM
      //
      // Note that we don't check the return code here
      // to provide a clean exit from "tart stop" in cases
      // when the VM is already shutting down and we hit
      // a race condition.
      //
      // We check the return code in the kill(2) below, though,
      // because it's a less common scenario and it would be
      // nice to know for the user that we've tried all methods
      // and failed to shutdown the VM.
      kill(pid, SIGINT)

      // Ensure that the VM has terminated
      var gracefulWaitDuration = Measurement(value: Double(timeout), unit: UnitDuration.seconds)
      let gracefulTickDuration = Measurement(value: Double(100), unit: UnitDuration.milliseconds)

      while gracefulWaitDuration.value > 0 {
        pid = try lock.pid()
        if pid == 0 {
          Foundation.exit(0)
        }

        try await Task.sleep(nanoseconds: UInt64(gracefulTickDuration.converted(to: .nanoseconds).value))
        gracefulWaitDuration = gracefulWaitDuration - gracefulTickDuration
      }

      // Seems that VM is still running, proceed with forceful termination
      let ret = kill(pid, SIGKILL)
      if ret != 0 {
        let details = Errno(rawValue: CInt(errno))

        print("failed to forcefully terminate the VM \(name): \(details)")

        Foundation.exit(1)
      }

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}
