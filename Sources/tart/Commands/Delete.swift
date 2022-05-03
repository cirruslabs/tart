import ArgumentParser
import Dispatch
import SwiftUI

struct Delete: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Delete a VM")

  @Argument(help: "VM name")
  var name: String

  func run() async throws {
    do {
      try VMStorageHelper.delete(name)

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}
