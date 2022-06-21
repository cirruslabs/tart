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

  @Flag(help: ArgumentHelp(
          "Don't open a UI window.",
          discussion: "Useful for integrating Tart VMs into other tools.\nUse `tart ip` in order to get an IP for SSHing or VNCing into the VM.")) 
  var noGraphics: Bool = false

  @Flag(help: "Boot into recovery mode") 
  var recovery: Bool = false
  
  @Flag(help: ArgumentHelp(
          "Use screen sharing instead of the built-in UI.",
          discussion: "Useful since VNC supports copy/paste, drag and drop, etc.\nNote that Remote Login option should be enabled inside the VM.")) 
  var vnc: Bool = false

  @MainActor
  func run() async throws {    
    let vmDir = try VMStorageLocal().open(name)
    vm = try VM(vmDir: vmDir)

    var vncWrapper: VNCWrapper?
    defer {
      do {
        try vncWrapper?.stop()
      } catch {
        print("Failed to stop VNC: \(error)")
      }
    }

    if vnc {
      vncWrapper = VNCWrapper(virtualMachine: vm!.virtualMachine)
    }

    // run VM in a child task which supports proper cancellation
    // https://github.com/apple/swift-evolution/blob/main/proposals/0317-async-let.md
    async let runTask: Never = runImpl()
    
    if let vncWrapper = vncWrapper {
      do {
        let (port, password) = try await vncWrapper.credentials()
        let url = URL(string: "vnc://:\(password)@127.0.0.1:\(port)")!
        print("Opening \(url)...")
        if ProcessInfo.processInfo.environment["CI"] == nil {
          NSWorkspace.shared.open(url)
        }
      } catch {
        print("Failed to get an IP for screen sharing: \(error)")
      }
    } else if !noGraphics {
      runUI()
    }

    // wait for VM to get into a final state
    await runTask
  }

  private func runImpl() async -> Never {
    do {
      try await vm!.run(recovery)

      // wait for VM to be in a final state before exit
      while !(vm?.inFinalState ?? false) {
        try await Task.sleep(nanoseconds: 1_000_000)
      }

      Foundation.exit(0)
    } catch {
      if error.localizedDescription.contains("Failed to lock auxiliary storage.") {
        print("Virtual machine \"\(name)\" is already running!")
      } else {
        print(error)
      }

      Foundation.exit(1)
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
