import ArgumentParser
import Darwin
import Foundation
import OpenTelemetryApi

@main
struct Root: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "tart",
    version: CI.version,
    subcommands: [
      Create.self,
      Clone.self,
      Run.self,
      Set.self,
      Get.self,
      List.self,
      Login.self,
      Logout.self,
      IP.self,
      Exec.self,
      Pull.self,
      Push.self,
      Import.self,
      Export.self,
      Prune.self,
      Rename.self,
      Stop.self,
      Delete.self,
      FQN.self,
    ])

  public static func main() async throws {
    // Add commands that are only available on specific macOS versions
    if #available(macOS 14, *) {
      configuration.subcommands.append(Suspend.self)
    }

    // Ensure the default SIGINT handled is disabled,
    // otherwise there's a race between two handlers
    signal(SIGINT, SIG_IGN);
    // Handle cancellation by Ctrl+C ourselves
    let task = withUnsafeCurrentTask { $0 }!
    let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT)
    sigintSrc.setEventHandler {
      task.cancel()
    }
    sigintSrc.activate()

    // Set line-buffered output for stdout
    setlinebuf(stdout)

    do {
      // Parse command
      var command = try parseAsRoot()

      // Initialize OpenTelemetry if configured
      Telemetry.bootstrapFromEnv()
      defer { Telemetry.flush() }

      // Run garbage-collection before each command (shouldn't take too long)
      if type(of: command) != type(of: Pull()) && type(of: command) != type(of: Clone()){
        do {
          try Config().gc()
        } catch {
          fputs("Failed to perform garbage collection!\n\(error)\n", stderr)
        }
      }

      // Run command
      if var asyncCommand = command as? AsyncParsableCommand {
        try await asyncCommand.run()
      } else {
        try command.run()
      }
    } catch {
      // Not an error, just a custom exit code from "tart exec"
      if let execCustomExitCodeError = error as? ExecCustomExitCodeError {
        Foundation.exit(execCustomExitCodeError.exitCode)
      }

      // Record the error into OpenTelemetry
      Telemetry.recordError(error)
      Telemetry.flush()

      // Handle a non-ArgumentParser's exception that requires a specific exit code to be set
      if let errorWithExitCode = error as? HasExitCode {
        fputs("\(error)\n", stderr)

        Foundation.exit(errorWithExitCode.exitCode)
      }

      // Handle any other exception, including ArgumentParser's ones
      exit(withError: error)
    }
  }

  private static func parseCirrusSentryTag(_ tag: String.SubSequence) -> (String, String)? {
    let splits = tag.split(separator: "=", maxSplits: 1)
    if splits.count != 2 {
      return nil
    }

    return (String(splits[0]), String(splits[1]))
  }
}
