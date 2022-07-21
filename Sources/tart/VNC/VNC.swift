import Foundation

protocol VNC {
  func waitForURL() async throws -> URL
  func stop() throws
}
