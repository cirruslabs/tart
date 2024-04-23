import Foundation

package enum CredentialsProviderError: Error {
  case Failed(message: String)
}

package protocol CredentialsProvider {
  func retrieve(host: String) throws -> (String, String)?
  func store(host: String, user: String, password: String) throws
}
