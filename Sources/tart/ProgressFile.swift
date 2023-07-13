import Foundation

enum ProgressError: Error {
  case FailedToCreateProgressFile
  case FailedtoExtractProgressFile
  case FailedtoWriteProgress
  case FailedtoGetChannelProgress
}

//values of each key in progressDict
struct myValues: Codable {
  var channelCount: Int
  var isDownloaded: Bool
}

class ProgressFile{
  let baseURL: URL
  let progressURL: URL
  //progressDict stores [diskLayer : (channelCount, isDownloaded)], where channelCount is the parts of the channel from registry.pullBlob()
  var progressDict: [String: myValues] = [
    "" : myValues(channelCount: -1, isDownloaded: false)]

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

  //update given diskLayer with given channelLayerCount
  func updateProgress(diskLayerCount: Int, channelLayerCount: Int) throws {
    self.progressDict[String(diskLayerCount)] = myValues(channelCount: channelLayerCount, isDownloaded: false)
    try writeProgress()
  }

  //returns if the given diskLayer is downloaded
  func isDiskLayerDownloaded(diskLayer: Int) -> Bool{
    if progressDict.keys.contains(String(diskLayer)) {
      return progressDict[String(diskLayer)]!.isDownloaded
    }
    return false
  }

  //returns if given channel-part is written
  func isChannelWritten(diskLayer: Int, channelLayerCount: Int) -> Bool{
    guard let channelsDownloadedUpTo = progressDict[String(diskLayer)]?.channelCount else {
      return false
    }
    return channelsDownloadedUpTo >= channelLayerCount
  }

  //marks the given diskLayer as downloaded
  func markLayerDownloaded(diskLayer: Int) throws {
    progressDict[String(diskLayer)]!.isDownloaded = true
    try writeProgress()
  }
}
