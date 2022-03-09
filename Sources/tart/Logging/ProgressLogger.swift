import Foundation

public class ProgressLogger: NSObject {
    let renderer: Logger

    public init(_ renderer: Logger) {
        self.renderer = renderer
    }

    public func FollowProgress(_ progress: Progress) {
        renderer.appendNewLine(ProgressLogger.lineToRender(progress))
        progress.observe(\.fractionCompleted) { progress, _ in
            self.renderer.updateLastLine(ProgressLogger.lineToRender(progress))
        }
    }

    private static func lineToRender(_ progress: Progress) -> String {
        String(100 * progress.completedUnitCount / progress.totalUnitCount) + "%"
    }
}
