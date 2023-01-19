import Foundation

struct VersionHandler {
    
    static var timeoutVersion: Int {
        let timeoutVersion = UserDefaults.standard.integer(forKey: LocalizeConstants.VersionTimeout)
        let currentDateTime = Int(Date().timeIntervalSince1970)
        if currentDateTime > timeoutVersion {
            return currentDateTime
        }
        return localVersion
    }
    
    static func resetTimeout() {
        UserDefaults.standard.set(Int(Date().timeIntervalSince1970) + LocalizeConstants.TimeoutSeconds,
                                  forKey: LocalizeConstants.VersionTimeout)
    }
    
    static var localVersion: Int {
        get {
            UserDefaults.standard.integer(forKey: LocalizeConstants.Version)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: LocalizeConstants.Version)
        }
    }
    
}


