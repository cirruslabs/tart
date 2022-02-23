import ArgumentParser
import Foundation
import SystemConfiguration
import Virtualization

struct Clone: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Clone a VM")
    
    @Argument(help: "source VM name")
    var sourceName: String
    
    @Argument(help: "new VM name")
    var newName: String
    
    func run() throws {
        Task {
            do {
                let vmStorage = VMStorage()
                let sourceVMDir = try vmStorage.read(sourceName)
                let newVMDir = try vmStorage.create(newName)
                
                try FileManager.default.copyItem(at: sourceVMDir.configURL, to: newVMDir.configURL)
                try FileManager.default.copyItem(at: sourceVMDir.nvramURL, to: newVMDir.nvramURL)
                try FileManager.default.copyItem(at: sourceVMDir.diskURL, to: newVMDir.diskURL)
                
                var newVMConfig = try VMConfig(fromURL: newVMDir.configURL)
                newVMConfig.macAddress = VZMACAddress.randomLocallyAdministered()
                try newVMConfig.save(toURL: newVMDir.configURL)
                
                Foundation.exit(0)
            } catch {
                print(error)
                
                Foundation.exit(1)
            }
        }
        
        dispatchMain()
    }
}
