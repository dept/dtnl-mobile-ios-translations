import Foundation
import Combine

class Disposables {
    
    var cancellables: [AnyCancellable] = []
    
}

class BundleFetcher {
    
    static let shared = BundleFetcher()
    let serialQueue = DispatchQueue(label: "SerialQueue")
    var bundleUrl: URL?
    
    var mainBundle: Bundle {
        get {
            var url: URL?
            serialQueue.sync {
                url = bundleUrl
            }
            if let urlUnwrapped = url, let bundle = Bundle(url: urlUnwrapped){
                return bundle
            }
            return .main
        }
        set {
            let newBundleUrl = newValue.bundleURL
            serialQueue.sync {
                bundleUrl = newBundleUrl
            }
        }
    }
}

public extension Bundle {
    
    fileprivate static var documentsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    fileprivate static var savedBundle: Bundle {
        get {
            return BundleFetcher.shared.mainBundle
        }
        set {
            BundleFetcher.shared.mainBundle = newValue
        }
    }
    
    fileprivate static var localizationBundleGeneric: Bundle {
        if (VersionHandler.localVersion > 0) {
            if let bundle = Bundle(url: documentsDirectory) {
                return bundle
            }
            return savedBundle
        }
        return savedBundle
    }
    
    static func localizationBundle(language: String) -> Bundle {
        let path = localizationBundleGeneric.path(forResource: language, ofType: "lproj") ?? savedBundle.bundlePath
        let bundle = Bundle(path: path) ?? localizationBundleGeneric
        return bundle
    }
    
    static func localizationFileUrl(language : String) -> URL? {
        return localizationBundle(language: language).url(forResource: "Localizable", withExtension: "strings")
    }
    
    static var localizationBundle: Bundle {
        let language = Localize.currentLanguage()
        let path = localizationBundleGeneric.path(forResource: language, ofType: "lproj") ?? savedBundle.bundlePath
        let bundle = Bundle(path: path) ?? localizationBundleGeneric
        return bundle
    }
    
    static var localizationFileUrl: URL? {
        return localizationBundle.url(forResource: "Localizable", withExtension: "strings")
    }
}


public struct Localize {
    
    private static var disposables = Disposables()

}

// Handle saving and fetching translations
public extension Localize {
    
    private static func updateTranslations(language: String, translations: [String: String]) {
        if let fileUrl = Bundle.localizationFileUrl(language: language) {
           let newData = translations.reduce("", { (result, new) in
               let escapedValue = new.value.replacingOccurrences(of: "\"", with: "\\\"")
               return result + "\"\(new.key)\"=\"\(escapedValue)\";\n"
           })
            do {
                try newData.write(to: fileUrl, atomically: true, encoding: String.localizeEncoding)
//                print(try String(contentsOf: fileUrl, encoding: String.localizeEncoding))
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    private static func syncToRemote(version: Int) {
        let fetcher = LocalizationFetcher()
        fetcher.shouldUpdate(version: version)
        .sink { shouldUpdate in
            if shouldUpdate {
                fetcher.getRemoteTranslations()?
                .sink {response in
                    if response.version > -1 {
                        response.translations.forEach {
                            updateTranslations(language: $0, translations: $1)
                        }
                    }
                }.store(in: &disposables.cancellables)
            }
        }.store(in: &disposables.cancellables)
    }
    
    private static func saveAllLanguages() {
        for language in Localize.availableLanguages() {
            if let sourceUrl = Bundle.savedBundle.url(forResource: language, withExtension: "lproj") {
                let destUrl = Bundle.documentsDirectory.appendingPathComponent("\(language).lproj/")
                do { try FileManager.default.copyItem(at: sourceUrl, to: destUrl) } catch { }
            }
        }
    }
    
    static func sync(localizeFile: LocalizeProtocol.Type? = nil, localVersion _localVersion: Int = 1) {
        let localVersion = localizeFile?.versionNumber ?? _localVersion
        if (_localVersion == -1) {
            VersionHandler.resetVersion()
        }
        if VersionHandler.localVersion <= 0 || localVersion > VersionHandler.localVersion {
            saveAllLanguages()
            VersionHandler.localVersion = localVersion
            syncToRemote(version: localVersion)
            return
        } else {
            syncToRemote(version: localVersion)
        }
    }
    
    static func config(_ config: LocalizationFetcherConfig, bundle: Bundle = .main) {
        Bundle.savedBundle = bundle
        config.save()
    }
    
    static var localizationFileContent: String {
        if let fileUrl = Bundle.localizationFileUrl, let content = try? String(contentsOf: fileUrl, encoding: String.localizeEncoding) {
            return content
        }
        return ""
    }
}


// Select and change language
public extension Localize {
    static func availableLanguages(excludeBase: Bool = false) -> [String] {
        var availableLanguages = Bundle.savedBundle.localizations
        if let indexOfBase = availableLanguages.firstIndex(of: "Base") , excludeBase == true {
            availableLanguages.remove(at: indexOfBase)
        }
        return availableLanguages
    }
    
    static func currentLanguage() -> String {
        if let currentLanguage = UserDefaults.standard.object(forKey: LocalizeConstants.CurrentLanguageKey) as? String {
            return currentLanguage
        }
        return defaultLanguage()
    }
    
    static func defaultLanguage() -> String {
        var defaultLanguage: String = String()
        guard let preferredLanguage = Bundle.savedBundle.preferredLocalizations.first else {
            return LocalizeConstants.DefaultLanguage
        }
        let availableLanguages: [String] = self.availableLanguages()
        if (availableLanguages.contains(preferredLanguage)) {
            defaultLanguage = preferredLanguage
        }
        else {
            defaultLanguage = LocalizeConstants.DefaultLanguage
        }
        return defaultLanguage
    }
    
    static func setCurrentLanguage(_ language: String) {
        let selectedLanguage = availableLanguages().contains(language) ? language : defaultLanguage()
        if (selectedLanguage != currentLanguage()){
            UserDefaults.standard.set(selectedLanguage, forKey: LocalizeConstants.CurrentLanguageKey)
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(name: Notification.Name(rawValue: LocalizeConstants.LanguageChangeNotification), object: nil)
        }
    }
    
    static func resetCurrentLanguageToDefault() {
        setCurrentLanguage(self.defaultLanguage())
    }
    
    static func displayNameForLanguage(_ language: String) -> String {
        let locale : NSLocale = NSLocale(localeIdentifier: currentLanguage())
        if let displayName = locale.displayName(forKey: NSLocale.Key.identifier, value: language) {
            return displayName
        }
        return String()
    }
}
