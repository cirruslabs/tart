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
          discussion: "Useful since Screen Sharing supports copy/paste, drag and drop, etc.\n"
            + "Note that Remote Login option should be enabled inside the VM."))
  var vnc: Bool = false

  @Flag(help: ArgumentHelp(
    "Use Virtualization.Framework's VNC server instead of the build-in UI.",
    discussion: "Useful since this type of VNC is available in recovery mode and in macOS installation.\n"
      + "Note that this feature is experimental and there may be bugs present when using VNC."))
  var vncExperimental: Bool = false

  @Flag var withSoftnet: Bool = false

  func validate() throws {
    if vnc && vncExperimental {
      throw ValidationError("--vnc and --vnc-experimental are mutually exclusive")
    }
  }

  @MainActor
  func run() async throws {    
    let vmDir = try VMStorageLocal().open(name)
    vm = try VM(vmDir: vmDir, withSoftnet: withSoftnet)

    let vncImpl: VNC? = try {
      if vnc {
        let vmConfig = try VMConfig.init(fromURL: vmDir.configURL)
        return ScreenSharingVNC(vmConfig: vmConfig)
      } else if vncExperimental {
        return FullFledgedVNC(virtualMachine: vm!.virtualMachine)
      } else {
        return nil
      }
    }()

    let task = Task {
      do {
        if let vncImpl = vncImpl {
          let vncURL = try await vncImpl.waitForURL()

          if noGraphics || ProcessInfo.processInfo.environment["CI"] != nil {
            print("VNC server is running at \(vncURL)")
          } else {
            print("Opening \(vncURL)...")
            NSWorkspace.shared.open(vncURL)
          }
        }

        try await vm!.run(recovery)

        if let vncImpl = vncImpl {
          try vncImpl.stop()
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

    let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT)
    sigintSrc.setEventHandler {
      task.cancel()
    }
    sigintSrc.activate()

    if noGraphics || vnc || vncExperimental {
      dispatchMain()
    } else {
      runUI()
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
