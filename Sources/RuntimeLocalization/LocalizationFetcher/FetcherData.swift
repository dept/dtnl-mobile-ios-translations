import Foundation

enum Method: String {
    case head = "HEAD"
    case get = "GET"
}

enum HeaderField: String {
    case authorization = "Authorization"
    case modifiedTime = "ModifiedTime"
}

struct TranslationResponse {
    let translations: [String: [String: String]]
    let version: Int
}
