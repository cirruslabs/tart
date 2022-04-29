import ArgumentParser
import Foundation
import SystemConfiguration

struct Clone: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Clone a VM")

  @Argument(help: "source VM name")
  var sourceName: String

  @Argument(help: "new VM name")
  var newName: String

  func run() async throws {
    do {
      try VMStorageHelper.open(sourceName).clone(to: VMStorageLocal().create(newName))

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}
