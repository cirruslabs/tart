import ArgumentParser
import Dispatch
import SwiftUI

struct List: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "List created VMs")
    
    func run() throws {
        Task {
            do {
                for vmURL in try VMStorage().list() {
                    print(vmURL)
                }
                
                Foundation.exit(0)
            } catch {
                print(error)
                
                Foundation.exit(1)
            }
        }
        
        dispatchMain()
    }
}
