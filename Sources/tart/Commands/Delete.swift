import ArgumentParser
import Dispatch
import SwiftUI

struct Delete: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Delete a VM")
    
    @Argument(help: "VM name")
    var name: String
    
    func run() throws {
        Task {
            do {
                try VMStorage().delete(name)
                
                Foundation.exit(0)
            } catch {
                print(error)
                
                Foundation.exit(1)
            }
        }
        
        dispatchMain()
    }
}
