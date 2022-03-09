import Foundation

public class ProgressObserver: NSObject {
    @objc var progressToObserve: Progress
    var observation: NSKeyValueObservation?

    public init(_ progress: Progress) {
        progressToObserve = progress
    }
    
    func log(_ renderer: Logger) {
        renderer.appendNewLine(ProgressObserver.lineToRender(progressToObserve))
        observation = observe(\.progressToObserve.fractionCompleted) { progress, _ in
            renderer.updateLastLine(ProgressObserver.lineToRender(self.progressToObserve))
        }        
    }

    private static func lineToRender(_ progress: Progress) -> String {
        String(100 * progress.completedUnitCount / progress.totalUnitCount) + "%"
    }
}
