import Foundation

public class URLSessionLogger: NSObject, URLSessionTaskDelegate {
    let renderer: Logger

    public init(_ renderer: Logger) {
        self.renderer = renderer
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        renderer.updateLastLine(URLSessionLogger.lineToRender(task.progress))
    }

    private static func lineToRender(_ progress: Progress) -> String {
        String(100 * progress.completedUnitCount / progress.totalUnitCount) + "%"
    }
}
