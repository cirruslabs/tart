import Foundation

extension URL {
  func absolutize(baseURL: URL) -> Self {
    URL(string: absoluteString, relativeTo: baseURL)!
  }
}
