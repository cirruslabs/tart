import Foundation

struct UninitializedVMDirectoryError: Error {}
struct AlreadyInitializedVMDirectoryError: Error {}

struct VMDirectory {
    var baseURL: URL
    
    var configURL: URL { self.baseURL.appendingPathComponent("config") }
    var diskURL: URL { self.baseURL.appendingPathComponent("disk") }
    var nvramURL: URL { self.baseURL.appendingPathComponent("nvram") }
    
    var initialized: Bool {
        FileManager.default.fileExists(atPath: configURL.path) &&
        FileManager.default.fileExists(atPath: diskURL.path) &&
        FileManager.default.fileExists(atPath: nvramURL.path)
    }
    
    func initialize() throws {
        if initialized {
            throw AlreadyInitializedVMDirectoryError()
        }
        
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    func validate() throws {
        if !initialized {
            throw UninitializedVMDirectoryError()
        }
    }
}
