import ArgumentParser
import Dispatch
import SwiftUI

struct Delete: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Delete a VM")

  @Argument(help: "VM name")
  var name: [String]

  func run() async throws {
    for it in name {
      try VMStorageHelper.delete(it)
    }
  }
}
