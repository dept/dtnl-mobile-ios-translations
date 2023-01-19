import Foundation

extension URLResponse {
    var version: Int {
        let httpRespnse = self as? HTTPURLResponse
        let headers = httpRespnse?.allHeaderFields as? [String: String]
        if let remoteVersion = Int(headers?[HeaderField.modifiedTime.rawValue] ?? "") {
            return remoteVersion
        }
        return VersionHandler.timeoutVersion
    }
}

