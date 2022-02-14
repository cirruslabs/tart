import Foundation

struct VMStorage {
    var homeDir: URL
    var tartDir: URL
    var vmsDir: URL
    
    init() {
        homeDir = FileManager.default.homeDirectoryForCurrentUser
        tartDir = homeDir.appendingPathComponent(".tart", isDirectory: true)
        vmsDir = tartDir.appendingPathComponent("vms", isDirectory: true)
    }
    
    func create(_ name: String) throws -> VMDirectory {
        let vmDir = VMDirectory(baseURL: vmURL(name))
        
        try vmDir.initialize()
        
        return vmDir
    }
    
    func read(_ name: String) throws -> VMDirectory {
        let vmDir = VMDirectory(baseURL: vmURL(name))
        
        try vmDir.validate()
        
        return vmDir
    }
    
    func delete(_ name: String) throws {
        try FileManager.default.removeItem(at: vmURL(name))
    }
    
    func list() throws -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(at: vmsDir,
                                                               includingPropertiesForKeys: [.isDirectoryKey],
                                                               options: .skipsSubdirectoryDescendants)
        } catch {
            if error.isFileNotFound() {
                return []
            }
            
            throw error
        }
    }
    
    private func vmURL(_ name: String) -> URL {
        return URL.init(fileURLWithPath: name, isDirectory: true, relativeTo: vmsDir)
    }
}

extension Error {
    func isFileNotFound() -> Bool {
        return (self as NSError).code == NSFileReadNoSuchFileError
    }
}
