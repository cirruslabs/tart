import Foundation

class DictionaryCredentialsProvider: CredentialsProvider {
    var credentials: Dictionary<String, (String, String)>

    init(_ credentials: Dictionary<String, (String, String)>) {
        self.credentials = credentials
    }

    func retrieve(host: String) throws -> (String, String)? {
        credentials[host]
    }

    func store(host: String, user: String, password: String) throws {
        credentials[host] = (user, password)
    }
}
