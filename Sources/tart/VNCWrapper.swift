import Foundation
import Dynamic
import Virtualization

class VNCWrapper {
    private let password: String
    private let vnc: Dynamic

    init(virtualMachine: VZVirtualMachine) {
        password = Array(PassphraseGenerator().prefix(4)).joined(separator: "-")
        let securityConfiguration = Dynamic._VZVNCAuthenticationSecurityConfiguration(password: password)
        vnc = Dynamic._VZVNCServer(port: 0, queue: DispatchQueue.global(),
                securityConfiguration: securityConfiguration)
        vnc.virtualMachine = virtualMachine
        vnc.start()
    }

    func open() async {
        do {
            let port = try await Self.waitForPort(vnc: vnc)

            let url = URL(string: "vnc://:\(password)@127.0.0.1:\(port)")!
            print("Opening \(url)...")

            if ProcessInfo.processInfo.environment["CI"] == nil {
                NSWorkspace.shared.open(url)
            }
        } catch {
            print("Failed to retrieve a VNC server port: \(error)")
        }
    }

    func stop() throws {
        vnc.stop()
    }

    deinit {
        try? stop()
    }

    private static func waitForPort(vnc: Dynamic) async throws -> UInt16 {
        while true {
            // Port is 0 shortly after start(),
            // but will be initialized later
            if let port = vnc.port.asUInt16, port != 0 {
                return port
            }

            // Wait 50 ms.
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
