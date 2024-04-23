import ArgumentParser
import Dispatch
import SwiftUI
import TartEngine

struct Delete: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Delete a VM")

  @Argument(help: "VM name", completion: .custom(completeMachines))
  var name: [String]

  func run() async throws {
    for it in name {
      try VMStorageHelper.delete(it, config: Config.processConfig)
    }
  }
}
