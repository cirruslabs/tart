import Foundation

actor AuthenticationKeeper {
  var authentication: Authentication? = nil

  func set(_ authentication: Authentication) {
    self.authentication = authentication
  }

  func header() -> (String, String)? {
    if let authentication = authentication {
      // Do not suggest any headers if the
      // authentication token has expired
      if !authentication.isValid() {
        return nil
      }

      return authentication.header()
    }

    // Do not suggest any headers if the
    // authentication token is not set
    return nil
  }
}
