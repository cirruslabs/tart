import Foundation
import Virtualization
import Dynamic

// Kudos to @saagarjha's VirtualApple for finding about _VZVirtualMachineStartOptions

extension VZVirtualMachine {
  @MainActor @available(macOS 12, *)
  func start(_ recovery: Bool) async throws {
    if !recovery {
      // just use the regular API
      return try await self.start()
    }

    // use some private stuff only for recovery
    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      let handler: @convention(block) (_ result: Any?) -> Void = { result in
        if let error = result as? Error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: ())
        }
      }
      // dynamic magic
      let options = Dynamic._VZVirtualMachineStartOptions()
      options.bootMacOSRecovery = recovery
      Dynamic(self)._start(withOptions: options, completionHandler: handler)
    }
  }
}
