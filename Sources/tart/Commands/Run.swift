import ArgumentParser
import Dispatch
import SwiftUI
import Virtualization

var vm: VM?

struct Run: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Run a VM")

  @Argument(help: "VM name")
  var name: String

  @Flag var noGraphics: Bool = false

  func run() async throws {
    let vmDir = try VMStorage().read(name)
    vm = try VM(vmDir: vmDir)

    Task {
      do {
        try await vm!.run()

        Foundation.exit(0)
      } catch {
        print(error)

        Foundation.exit(1)
      }
    }

    if noGraphics {
      dispatchMain()
    } else {
      // UI mumbo-jumbo
      let nsApp = await NSApplication.shared
      await nsApp.setActivationPolicy(.regular)
      await nsApp.activate(ignoringOtherApps: true)

      struct MainApp: App {
        var body: some Scene {
          WindowGroup {
            VMView(vm: vm!)
          }
        }
      }

      await MainApp.main()
    }
  }
}

struct VMView: NSViewRepresentable {
  typealias NSViewType = VZVirtualMachineView

  @ObservedObject var vm: VM

  func makeNSView(context: Context) -> NSViewType {
    VZVirtualMachineView()
  }

  func updateNSView(_ nsView: NSViewType, context: Context) {
    nsView.virtualMachine = vm.virtualMachine
  }
}
