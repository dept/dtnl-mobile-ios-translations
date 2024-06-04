import Foundation

public extension String {
    
    static var localizeEncoding: String.Encoding = .utf16
    
    var localized: String {
        return NSLocalizedString(self, bundle: Bundle.localizationBundle, value: self, comment: self)
    }
    
    func localized(with args: CVarArg...) -> String {
        return String(format: self.localized, arguments: args)
    }
}
