import ArgumentParser
import Dispatch
import SwiftUI
import Virtualization

var vm: VM?

struct IPNotFound: Error {
}

struct Run: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Run a VM")

  @Argument(help: "VM name")
  var name: String

  @Flag var noGraphics: Bool = false

  @Flag var recovery: Bool = false
  
  @Flag var vnc: Bool = false

  @MainActor
  func run() async throws {
    if recovery && vnc {
      print("You can't run in recovery and use VNC!")
      Foundation.exit(1)      
    }
    
    let vmDir = try VMStorageLocal().open(name)
    vm = try VM(vmDir: vmDir)

    await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        do {
          try await vm!.run(recovery)

          Foundation.exit(0)
        } catch {
          print(error)

          Foundation.exit(1)
        }
      }
      if vnc {
        group.addTask(operation: {
          do {
            let resolvedIP = try await IP.resolveIP(vm!.config, secondsToWait: 60)
            guard let ip = resolvedIP else {
              throw IPNotFound()
            }
            let url = URL(string: "vnc://admin:admin\(ip)")!
            NSWorkspace.shared.open(url)
          } catch {
            print("Failed to get an IP for screen sharing: \(error)")
          }
        })
      }

      if noGraphics || vnc {
        dispatchMain()
      } else {
        runUI()
      }
    }
  }

  private func runUI() {
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
                  // Replace some standard menu options
                  CommandGroup(replacing: .appInfo) { AboutTart() }
                }
      }
    }

    MainApp.main()
  }
}

struct AboutTart: View {
  var body: some View {
    Button("About Tart") {
      NSApplication.shared.orderFrontStandardAboutPanel(options: [
        NSApplication.AboutPanelOptionKey.applicationIcon: NSApplication.shared.applicationIconImage as Any,
        NSApplication.AboutPanelOptionKey.applicationName: "Tart",
        NSApplication.AboutPanelOptionKey.applicationVersion: CI.version,
        NSApplication.AboutPanelOptionKey.credits: try! NSAttributedString(markdown: "https://github.com/cirruslabs/tart"),
      ])
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
