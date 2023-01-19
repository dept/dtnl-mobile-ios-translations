import Foundation
import Combine

struct LocalizationFetcher {
    
    var config: LocalizationFetcherConfig? = .load()
    
    init(config: LocalizationFetcherConfig? = nil) {
        self.config = config != nil ? config:.load()
    }
    
    func getRemoteVersion() -> AnyPublisher<Int, Never> {
        return requestFor(method: .head)?
            .map {$0.response.version}
            .catch { error in
                Just(VersionHandler.timeoutVersion)
            }
            .eraseToAnyPublisher() ?? Just(VersionHandler.timeoutVersion).eraseToAnyPublisher()
    }
    
    func shouldUpdate(version: Int) -> AnyPublisher<Bool, Never> {
        getRemoteVersion().map {
            return $0 > UserDefaults.standard.integer(forKey: LocalizeConstants.Version)
        }.eraseToAnyPublisher()
    }
    
    private func getTranslationResponseFromOutput(output: URLSession.DataTaskPublisher.Output) -> TranslationResponse? {
        guard let value = try? JSONSerialization.jsonObject(with: output.data, options: []) as? [String: [String: String]] else {
            return nil
        }
        let version = output.response.version
        VersionHandler.localVersion = version
        VersionHandler.resetTimeout()
        return TranslationResponse.init(translations: value, version: version)
    }
    
    func getRemoteTranslations() -> AnyPublisher<TranslationResponse, Never>? {
        return requestFor(method: .get)?.compactMap {
            getTranslationResponseFromOutput(output: $0)
        }
        .catch { error in
            Just(.init(translations: [:], version: -1))
        }
        .map { response in
            var transformed: [String: [String: String]] = [:]
            response.translations.forEach {(key: String, langs: [String: String]) in
                langs.forEach {(lang: String, value: String) in
                    if (!transformed.keys.contains(lang)) { transformed[lang] = [:] }
                    transformed[lang]?[key] = value
                }
            }
            return TranslationResponse.init(translations: transformed, version: response.version)
        }.eraseToAnyPublisher()
    }
    
    private func requestFor(method: Method) -> AnyPublisher<URLSession.DataTaskPublisher.Output, URLError>? {
        if let urlString = config?.translationUrl,
           let url = URL(string: urlString),
           let headers = config?.headers {
            var request = URLRequest(url: url)
            headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
            request.httpMethod = method.rawValue
            return URLSession.shared.dataTaskPublisher(for: request).eraseToAnyPublisher()
        }
        return nil
    }
}
