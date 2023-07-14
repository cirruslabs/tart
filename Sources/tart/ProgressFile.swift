import Foundation

enum ProgressError: Error {
  case FailedToCreateProgressFile
  case FailedtoExtractProgressFile
  case FailedtoWriteProgress
  case FailedtoGetChannelProgress
}

//values of each key in progressDict
struct myValues: Codable {
  var isDownloaded: Bool
}

class ProgressFile{
  let baseURL: URL
  let progressURL: URL
  //progressDict stores [diskLayer : (isDownloaded)]
  var progressDict: [String: myValues] = [
    "" : myValues(isDownloaded: false)]

  //Create progress.json if it doesn't exist yet, else extract the dict
  init(baseURL: URL) throws{
    self.baseURL = baseURL
    self.progressURL = baseURL.appendingPathComponent("progress.json")
    if !FileManager.default.fileExists(atPath: progressURL.path){
      if !FileManager.default.createFile(atPath: progressURL.path, contents: nil){
        throw ProgressError.FailedToCreateProgressFile
      }
      print("Initialized progressFile")
      try writeProgress()
    } else {
      print("progressFile exists already, extracting")
      try getProgress()
    }
  }

  //write dict to progress.json
  private func writeProgress() throws {
    do {
      let data = try JSONEncoder().encode(progressDict)
      try data.write(to: progressURL)
    } catch {
      throw ProgressError.FailedtoWriteProgress
    }
  }

  //extract dict from progress.json
  private func getProgress() throws {
    do {
      let data = try Data(contentsOf: progressURL)
      progressDict = try JSONDecoder().decode([String:myValues].self, from: data)
    } catch {
      throw ProgressError.FailedtoExtractProgressFile
    }
  }

  //return if a diskLayer exists
  private func layerExists(diskLayer: Int) -> Bool {
    return progressDict.keys.contains(String(diskLayer))
  }

  //returns if the given diskLayer is downloaded
  func isDiskLayerDownloaded(diskLayer: Int) -> Bool{
    if layerExists(diskLayer: diskLayer) {
      return progressDict[String(diskLayer)]!.isDownloaded
    }
    return false
  }

  //marks the given diskLayer as downloaded
  func markLayerDownloaded(diskLayer: Int) throws {
    if layerExists(diskLayer: diskLayer){
      self.progressDict[String(diskLayer)]!.isDownloaded = true
    } else {
      self.progressDict[String(diskLayer)] = myValues(isDownloaded: true)
    }
    try writeProgress()
  }
}
