package struct CI {
  private static let rawVersion = "${CIRRUS_TAG}"

  package static var version: String {
    rawVersion.expanded() ? rawVersion : "SNAPSHOT"
  }

  package static var release: String? {
    rawVersion.expanded() ? "tart@\(rawVersion)" : nil
  }
}

private extension String {
  func expanded() -> Bool {
    !isEmpty && !starts(with: "$")
  }
}
