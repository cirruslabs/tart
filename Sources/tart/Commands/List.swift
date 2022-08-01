import ArgumentParser
import Dispatch
import SwiftUI

struct List: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "List created VMs")

  func run() async throws {
    do {
      print("Source\tName")

      displayTable("local", try VMStorageLocal().list())
      displayTable("oci", try VMStorageOCI().list().map { (name, vmDir, _) in (name, vmDir) })

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }

  private func displayTable(_ source: String, _ vms: [(String, VMDirectory)]) {
    for (name, _) in vms.sorted(by: { left, right in left.0 < right.0 }) {
      print("\(source)\t\(name)")
    }
  }
}
