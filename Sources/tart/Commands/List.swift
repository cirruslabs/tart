import ArgumentParser
import Dispatch
import SwiftUI

struct List: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "List created VMs")

  @Flag(name: [.short, .long], help: ArgumentHelp("Only display VM names."))
  var quiet: Bool = false

  @Option(help: ArgumentHelp("Only display VMs from the specified source (e.g. --source local, --source oci)."))
  var source: String = ""

  func run() async throws {
    do {
      switch source {
      case "local":
        displayTable("local", try VMStorageLocal().list())
      case "oci":
        displayTable("oci", try VMStorageOCI().list().map { (name, vmDir, _) in (name, vmDir) })
      case "":
        displayTable("local", try VMStorageLocal().list())
        displayTable("oci", try VMStorageOCI().list().map { (name, vmDir, _) in (name, vmDir) })
      default:
        throw ValidationError("Unknown source: '\(source)'")
      }

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }

  private func displayTable(_ source: String, _ vms: [(String, VMDirectory)]) {
    if !quiet {
      print("Source\tName")
    }

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
