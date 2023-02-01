import ArgumentParser
import Foundation
import Sentry

struct ReportInstallation: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "report-installation",
    abstract: "Send installation event to Sentry if configured",
    discussion: """
    Reports macOS version and device model for analytics purposes.
    Helps Cirrus Labs team to prioritize testing on most popular devices.
    """,
    shouldDisplay: false
  )

  func run() async throws {
    let installationEvent = Event()
    installationEvent.message = SentryMessage(formatted: "installed")
    installationEvent.level = SentryLevel.info
    installationEvent.user = nil
    installationEvent.stacktrace = nil
    let id = SentrySDK.capture(event: installationEvent)
    print("Captured installation event #\(id)!")
  }
}
