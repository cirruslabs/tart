import Foundation
import AsyncAlgorithms

enum BlobsTmpDirError: Error {
  case FailedToCreateBlobsTmpDir
  case FailedToCreateBlobsDir
  case FailedToGetBlob
  case FailedToSetBlob
  case FailedToGetAllBlobs
}

class BlobTmpDir {
  let baseURL : URL
  let blobsURL : URL

  init(baseURL: URL) throws {
    do {
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

    } catch {
      throw BlobsTmpDirError.FailedToCreateBlobsTmpDir
    }
  }

  func get(name: String) throws -> Data? {
    do {
      let blobURL = blobsURL.appendingPathComponent(name)
      if !FileManager.default.fileExists(atPath: blobURL.path){
        return nil
      }
      let blob = try FileHandle(forReadingFrom: blobURL)
      let data = blob.readDataToEndOfFile()
      return data

    } catch {
      throw BlobsTmpDirError.FailedToGetBlob
    }
  }

  func set(contents: AsyncThrowingChannel<Data, Error>, name: String) async throws {
    do {
      let blobURL = blobsURL.appendingPathComponent(name)
      await FileManager.default.createFile(atPath: blobURL.path, contents: try contents.asData())

    } catch {
      throw BlobsTmpDirError.FailedToSetBlob
    }
  }

  func getAllBlobs() throws -> [Data] {
    do {
      var blobs: [Data] = []
      let fileManager = FileManager.default
      let blobFiles = try fileManager.contentsOfDirectory(at: blobsURL, includingPropertiesForKeys: nil)

      //Sort blobFiles by ascending order
      let sortedBlobFiles = blobFiles.sorted { url1, url2 in
        let name1 = url1.lastPathComponent
        let name2 = url2.lastPathComponent
        return name1.localizedStandardCompare(name2) == .orderedAscending
      }

      //This loop takes a ton of memory
      //Reads each blob file and puts into an blobs array
      for blobFile in sortedBlobFiles{
        let blobData = try Data(contentsOf: blobFile)
        blobs.append(blobData)
      }
      return blobs

    } catch {
      throw BlobsTmpDirError.FailedToGetAllBlobs
    }
  }

}
