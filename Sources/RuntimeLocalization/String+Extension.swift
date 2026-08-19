import Foundation

public extension String {
    
    static var localizeEncoding: String.Encoding = .utf16
    
    var localized: String {
        return Bundle.localizedString(forKey: self, value: self)
    }
    
    func localized(with args: CVarArg...) -> String {
        return String(format: self.localized, arguments: args)
    }
}
