import Foundation

struct VMStorage {
    public static let tartHomeDir: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".tart", isDirectory: true)
    
    public static let tartVMsDir: URL = tartHomeDir.appendingPathComponent("vms", isDirectory: true)
    public static let tartCacheDir: URL = tartHomeDir.appendingPathComponent("cache", isDirectory: true)
    
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
            return try FileManager.default.contentsOfDirectory(
                at: VMStorage.tartVMsDir,
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
        return URL.init(
            fileURLWithPath: name, 
            isDirectory: true, 
            relativeTo: VMStorage.tartVMsDir)
    }
}

extension Error {
    func isFileNotFound() -> Bool {
        return (self as NSError).code == NSFileReadNoSuchFileError
    }
}
