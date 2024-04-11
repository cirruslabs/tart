import ArgumentParser
import Foundation
import SystemConfiguration

struct FQN: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Get a fully-qualified VM name", shouldDisplay: false)

  @Argument(help: "VM name", completion: .custom(completeMachines))
  var name: String

  func run() async throws {
    if var remoteName = try? RemoteName(name) {
      let digest = try VMStorageOCI().digest(remoteName)

      remoteName.reference = Reference(digest: digest)

      print(remoteName)
    } else {
      print(name)
    }
  }
}
