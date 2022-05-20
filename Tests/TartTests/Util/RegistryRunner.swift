import Foundation
@testable import tart

enum RegistryRunnerError: Error {
    case DockerFailed(exitCode: Int32)
}

class RegistryRunner {
    let containerID: String
    let registry: Registry

    static func dockerCmd(_ arguments: String...) throws -> String {
        let stdoutPipe = Pipe()

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
        proc.arguments = arguments
        proc.standardOutput = stdoutPipe
        try proc.run()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()

        proc.waitUntilExit()

        if proc.terminationStatus != 0 {
            throw RegistryRunnerError.DockerFailed(exitCode: proc.terminationStatus)
        }

        return String(data: stdoutData, encoding: .utf8) ?? ""
    }

    init() async throws {
        // Start container
        let container = try Self.dockerCmd("run", "-d", "--rm", "-p", "5000", "registry:2")
                .trimmingCharacters(in: CharacterSet.newlines)
        containerID = container

        // Get forwarded port
        let port = try Self.dockerCmd("inspect", containerID, "--format", "{{(index (index .NetworkSettings.Ports \"5000/tcp\") 0).HostPort}}")
                .trimmingCharacters(in: CharacterSet.newlines)

        registry = try Registry(urlComponents: URLComponents(string: "http://127.0.0.1:\(port)/v2/")!,
                namespace: "vm-image")

        // Wait for the Docker Registry to start
        while ((try? await registry.ping()) == nil) {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    deinit {
        _ = try! Self.dockerCmd("kill", containerID)
    }
}
