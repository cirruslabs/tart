import Foundation

// RFC3339 date parser from DateFormatter documentation[1]
//
// [1]: https://developer.apple.com/documentation/foundation/dateformatter
extension Date {
  init?(fromRFC3339: String) {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

    if let date = dateFormatter.date(from: fromRFC3339) {
      self = date
    } else {
      return nil
    }
  }
}
