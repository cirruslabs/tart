import Foundation

public class ProgressObserver: NSObject {
  @objc var progressToObserve: Progress
  var observation: NSKeyValueObservation?
  var lastTimeUpdated = Date.now
  private var lastRenderedLine: String?

  public init(_ progress: Progress) {
    progressToObserve = progress
  }

  func log(_ renderer: Logger) {
    let initialLine = ProgressObserver.lineToRender(progressToObserve)
    renderer.appendNewLine(initialLine)
    lastRenderedLine = initialLine
    observation = observe(\.progressToObserve.fractionCompleted) { progress, _ in
      let currentTime = Date.now
      if self.progressToObserve.isFinished || currentTime.timeIntervalSince(self.lastTimeUpdated) >= 1.0 {
        self.lastTimeUpdated = currentTime
        let line = ProgressObserver.lineToRender(self.progressToObserve)
        // Skip identical renders so non-interactive logs only see new percent values.
        guard line != self.lastRenderedLine else {
          return
        }

        self.lastRenderedLine = line
        renderer.updateLastLine(line)
      }
    }
  }

  private static func lineToRender(_ progress: Progress) -> String {
    String(Int(100 * progress.fractionCompleted)) + "%"
  }
}
