import Foundation

protocol VNC {
  func waitForURL(netBridged: Bool) async throws -> URL
  func stop() throws
}
