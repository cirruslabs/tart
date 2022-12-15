import ArgumentParser
import Dispatch
import SwiftUI

struct List: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "List created VMs")

  @Flag(name: [.short, .long], help: ArgumentHelp("Only display VM names."))
  var quiet: Bool = false

  @Option(help: ArgumentHelp("Only display VMs from the specified source (e.g. --source local, --source oci)."))
  var source: String?

  func validate() throws {
    guard let source = source else {
      return
    }

    if !["local", "oci"].contains(source) {
      throw ValidationError("'\(source)' is not a valid <source>")
    }
  }

  func run() async throws {
    if !quiet {
      print("Source\tName")
    }

    if source == nil || source == "local" {
      displayTable("local", try VMStorageLocal().list())
    }

    if source == nil || source == "oci" {
      displayTable("oci", try VMStorageOCI().list().map { (name, vmDir, _) in (name, vmDir) })
    }
  }

  private func displayTable(_ source: String, _ vms: [(String, VMDirectory)]) {
    for (name, _) in vms.sorted(by: { left, right in left.0 < right.0 }) {
      if quiet {
        print(name)
      } else {
        let source = source.padding(toLength: "Source".count, withPad: " ", startingAt: 0)
        print("\(source)\t\(name)")
      }
    }
  }
}
