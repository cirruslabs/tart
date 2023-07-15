import Foundation

protocol VNC {
  func waitForURL() async throws -> URL

  func setUserNotifier(notifier: @escaping (URL) -> ())
  func notifyUser(vncURL: URL)

  func stop() throws
}

class VNCNotifier {
  var notifier: ((URL) -> ())?

  func setUserNotifier(notifier: @escaping (URL) -> ()) {
    self.notifier = notifier
  }

  func notifyUser(vncURL: URL) {
    if let notifier = notifier {
      notifier(vncURL)
    }
  }
}
