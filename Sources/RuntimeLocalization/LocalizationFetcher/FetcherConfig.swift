import Foundation

public struct LocalizationFetcherConfig {
    let translationUrl: String
    let headers: [String: String]
    
    public init(url: String, authorization: String? = nil, headers: [String: String] = [:]) {
        self.translationUrl = url
        self.headers = authorization != nil ? [HeaderField.authorization.rawValue: authorization!]:headers
    }
    
    func save() {
        UserDefaults.standard.set(translationUrl, forKey: LocalizeConstants.FetcherLocalizationUrl)
        UserDefaults.standard.set(headers, forKey: LocalizeConstants.FetcherHeaders)
    }
    
    static func load() -> LocalizationFetcherConfig? {
        if let url = UserDefaults.standard.string(forKey: LocalizeConstants.FetcherLocalizationUrl),
           let headers = UserDefaults.standard.dictionary(forKey: LocalizeConstants.FetcherHeaders) as? [String: String] {
            return .init(url: url, headers: headers)
        }
        return nil
    }
}
