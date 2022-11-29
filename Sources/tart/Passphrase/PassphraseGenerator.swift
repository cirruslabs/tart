import Foundation

struct PassphraseGenerator: Sequence {
  func makeIterator() -> PassphraseIterator {
    PassphraseIterator()
  }
}

struct PassphraseIterator: IteratorProtocol {
  mutating func next() -> String? {
    passphrases[Int(arc4random_uniform(UInt32(passphrases.count)))]
  }
}
