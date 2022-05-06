import Foundation

extension URL {
  func absolutize(_ baseURL: URL) -> Self {
    URL(string: absoluteString, relativeTo: baseURL)!
  }
}
