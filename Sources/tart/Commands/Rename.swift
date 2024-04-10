import ArgumentParser
import Foundation

struct Rename: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Rename a VM")

  @Argument(help: "VM name", completion: .custom(completeLocalMachines))
  var name: String

  @Argument(help: "new VM name")
  var newName: String

  func validate() throws {
    if newName.contains("/") {
      throw ValidationError("<new-name> should be a local name")
    }
  }

  func run() async throws {
    let localStorage = VMStorageLocal()

    if !localStorage.exists(name) {
      throw ValidationError("failed to rename a non-existent VM: \(name)")
    }

    if localStorage.exists(newName) {
      throw ValidationError("failed to rename VM \(name), target VM \(newName) already exists, delete it first!")
    }

    try localStorage.rename(name, newName)
  }
}
