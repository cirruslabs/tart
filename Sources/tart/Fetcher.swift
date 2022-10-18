import Foundation
import AsyncAlgorithms

class Fetcher: NSObject, URLSessionTaskDelegate, URLSessionDelegate, URLSessionDataDelegate {
    let responseCh = AsyncThrowingChannel<URLResponse, Error>()
    let dataCh = AsyncThrowingChannel<Data, Error>()

    func fetch(_ request: URLRequest) async throws -> (AsyncThrowingChannel<Data, Error>, URLResponse) {
        let task = URLSession.shared.dataTask(with: request)
        task.delegate = self
        task.resume()

        // Wait for the response and only then return
        var iter = responseCh.makeAsyncIterator()
        let response = try await iter.next()!

        return (dataCh, response)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) async -> URLSession.ResponseDisposition {
        await responseCh.send(response)

        return .allow
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let sema = DispatchSemaphore(value: 0)

        Task {
            await dataCh.send(data)
            sema.signal()
        }

        sema.wait()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Premature termination
            responseCh.fail(error)
            dataCh.fail(error)
        } else {
            dataCh.finish()
        }
    }
}
