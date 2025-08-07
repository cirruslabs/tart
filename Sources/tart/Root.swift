import ArgumentParser
import Darwin
import Foundation
import Sentry

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

      // Initialize Sentry
      if let dsn = ProcessInfo.processInfo.environment["SENTRY_DSN"] {
        SentrySDK.start { options in
          options.dsn = dsn
          options.releaseName = CI.release
          options.tracesSampleRate = Float(
            ProcessInfo.processInfo.environment["SENTRY_TRACES_SAMPLE_RATE"] ?? "1.0"
          ) as NSNumber?

          // By default only 5XX are captured
          // Let's capture everything but 401 (unauthorized)
          options.enableCaptureFailedRequests = true
          options.failedRequestStatusCodes = [
            HttpStatusCodeRange(min: 400, max: 400),
            HttpStatusCodeRange(min: 402, max: 599)
          ]
        }
      }
      defer { SentrySDK.flush(timeout: 2.seconds.timeInterval) }

      SentrySDK.configureScope { scope in
        scope.setExtra(value: ProcessInfo.processInfo.arguments, key: "Command-line arguments")
      }

      // Enrich future events with Cirrus CI-specific tags
      if let tags = ProcessInfo.processInfo.environment["CIRRUS_SENTRY_TAGS"] {
        SentrySDK.configureScope { scope in
          for (key, value) in tags.split(separator: ",").compactMap({ parseCirrusSentryTag($0) }) {
            scope.setTag(value: value, key: key)
          }
        }
      }

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

      // Capture the error into Sentry
      SentrySDK.capture(error: error)
      SentrySDK.flush(timeout: 2.seconds.timeInterval)

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
