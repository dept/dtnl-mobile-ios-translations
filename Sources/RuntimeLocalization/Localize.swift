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

    static func localizedString(forKey key: String, value: String? = nil, table tableName: String? = nil) -> String {
        let fallbackValue = value ?? key
        let localizedValue = localizationBundle.localizedString(forKey: key, value: fallbackValue, table: tableName)

        guard localizedValue == fallbackValue,
              let stringsBundle = stringsLocalizationBundle else {
            return localizedValue
        }

        return stringsBundle.localizedString(forKey: key, value: fallbackValue, table: tableName)
    }

    private static var stringsLocalizationBundle: Bundle? {
        let language = Localize.currentLanguage()
        // "Strings/<lang>.lproj" is only ever bundled with the app, never copied into the documents cache
        guard let path = savedBundle.path(forResource: language, ofType: "lproj", inDirectory: "Strings") else {
            return nil
        }

        return Bundle(path: path)
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
               return result + "\"\(escapeForStringsFile(new.key))\"=\"\(escapeForStringsFile(new.value))\";\n"
           })
            // A single malformed entry makes the whole .strings file unreadable, so never replace a valid file with it
            guard let data = newData.data(using: .utf8),
                  (try? PropertyListSerialization.propertyList(from: data, format: nil)) is [String: String] else {
                print("RuntimeLocalization: skipped writing invalid strings file for \(language)")
                return
            }
            do {
                try newData.write(to: fileUrl, atomically: true, encoding: String.localizeEncoding)
//                print(try String(contentsOf: fileUrl, encoding: String.localizeEncoding))
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    // Remote values may already contain .strings escapes (e.g. \n, \"), so only escape quotes that aren't escaped yet
    internal static func escapeForStringsFile(_ value: String) -> String {
        var result = ""
        var backslashCount = 0
        for character in value {
            if character == "\"" && backslashCount % 2 == 0 {
                result.append("\\")
            }
            backslashCount = character == "\\" ? backslashCount + 1 : 0
            result.append(character)
        }
        // A dangling backslash would escape the closing quote
        if backslashCount % 2 == 1 {
            result.append("\\")
        }
        return result
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
