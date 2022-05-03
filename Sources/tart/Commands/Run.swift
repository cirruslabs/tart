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

  @MainActor
  func run() async throws {
    let vmDir = try VMStorageLocal().open(name)
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
      let nsApp = NSApplication.shared
      nsApp.setActivationPolicy(.regular)
      nsApp.activate(ignoringOtherApps: true)

      nsApp.applicationIconImage = NSImage(data: AppIconData)

      struct MainApp: App {
        var body: some Scene {
          WindowGroup(vm!.name) {
            Group {
              VMView(vm: vm!).onAppear {
                NSWindow.allowsAutomaticWindowTabbing = false
              }
            }.frame(width: CGFloat(vm!.config.display.width), height: CGFloat(vm!.config.display.height))
          }.commands {
            // Remove some standard menu options
            CommandGroup(replacing: .help, addition: {})
            CommandGroup(replacing: .newItem, addition: {})
            CommandGroup(replacing: .pasteboard, addition: {})
            CommandGroup(replacing: .textEditing, addition: {})
            CommandGroup(replacing: .undoRedo, addition: {})
            CommandGroup(replacing: .windowSize, addition: {})
          }
        }
      }

      MainApp.main()
    }
  }
}

struct VMView: NSViewRepresentable {
  typealias NSViewType = VZVirtualMachineView

  @ObservedObject var vm: VM

  func makeNSView(context: Context) -> NSViewType {
    let machineView = VZVirtualMachineView()
    machineView.capturesSystemKeys = true
    return machineView
  }

  func updateNSView(_ nsView: NSViewType, context: Context) {
    nsView.virtualMachine = vm.virtualMachine
  }
}
