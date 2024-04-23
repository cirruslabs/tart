import Foundation

package actor AuthenticationKeeper {
  package var authentication: Authentication? = nil

  package func set(_ authentication: Authentication) {
    self.authentication = authentication
  }

  package func header() -> (String, String)? {
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
