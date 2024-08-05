import Foundation

extension Data {
  /*
   * Performant version of splitting a Data into chunks of a given size.
   * It appers that "Data.chunks` is not as performant as chunking the range of the data
   * into subranges and getting subdata directly.
   */
  func subdataChunks(ofCount: Int) -> [Data] {
    var chunks: [Data] = []

    for subrange in (0..<self.count).chunks(ofCount: ofCount) {
      chunks.append(self.subdata(in: subrange))
    }

    return chunks
  }
}