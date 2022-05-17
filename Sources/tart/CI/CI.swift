struct CI {
  private static let rawVersion = "${CIRRUS_TAG}"

  static var version: String {
    rawVersion.expanded() ? rawVersion : "SNAPSHOT"
  }
}

private extension String {
  func expanded() -> Bool {
    !isEmpty && !starts(with: "$")
  }
}
