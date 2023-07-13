import Foundation
import AsyncAlgorithms

enum BlobsTmpDirError: Error {
  case FailedToCreateBlobsDir
}

class BlobTmpDir {
  let baseURL : URL
  let blobsURL : URL

  init(baseURL: URL) throws {
    self.baseURL = baseURL
    self.blobsURL = baseURL.appendingPathComponent("blobs", isDirectory: true)
    if !FileManager.default.fileExists(atPath: blobsURL.path){
      do {
        try FileManager.default.createDirectory(at: blobsURL, withIntermediateDirectories: false)
        print("Initialized BlobTmpDir")
      } catch {
        throw BlobsTmpDirError.FailedToCreateBlobsDir
      }
    } else {
        print("BlobTmpDir exists, extracting")
    }
  }

  func get(name: String) throws -> Data? {
      let blobURL = blobsURL.appendingPathComponent(name)
      if !FileManager.default.fileExists(atPath: blobURL.path){
          return nil
      }
      let blob = try FileHandle(forReadingFrom: blobURL)
      let data = blob.readDataToEndOfFile()
      return data
  }

  func set(contents: AsyncThrowingChannel<Data, Error>, name: String) async throws {
    let blobURL = blobsURL.appendingPathComponent(name)
      await FileManager.default.createFile(atPath: blobURL.path, contents: try contents.asData())
    }
    
    func getAllBlobs() throws -> [Data] {
      var blobs: [Data] = []
      let fileManager = FileManager.default
      let blobFiles = try fileManager.contentsOfDirectory(at: blobsURL, includingPropertiesForKeys: nil)

      //Sort blobFiles by ascending order
      let sortedBlobFiles = blobFiles.sorted { url1, url2 in
          let name1 = url1.lastPathComponent
          let name2 = url2.lastPathComponent
          return name1.localizedStandardCompare(name2) == .orderedAscending
        }

      for blobFile in sortedBlobFiles{
        let blobData = try Data(contentsOf: blobFile)
        blobs.append(blobData)
      }
        
        return blobs
    }
}
