import ArgumentParser
import Foundation
import SystemConfiguration

struct IP: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Get VM's IP address")
    
    @Argument(help: "VM name")
    var name: String
    
    func run() throws {
        Task {
            do {
                let vmDir = try VMStorage().read(name)
                let vmConfig = try VMConfig.init(fromURL: vmDir.configURL)
                let vmMacAddress = MACAddress(fromString: vmConfig.macAddress.string)!
                
                guard let ip = try ARPCache.ResolveMACAddress(macAddress: vmMacAddress) else {
                    print("no IP address found")
                    
                    Foundation.exit(1)
                }
                
                print(ip)

                Foundation.exit(0)
            } catch {
                print(error)
                
                Foundation.exit(1)
            }
        }
        
        dispatchMain()
    }
}
