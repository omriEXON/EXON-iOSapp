import Foundation

struct DiagnosticResults {
    let cookiesEnabled: Bool
    let loggedIn: Bool
    let networkAvailable: Bool
    let accountRegion: String?
    let hasGamePass: Bool
}

enum DiagnosticError: LocalizedError {
    case cookiesDisabled
    case notLoggedIn
    case noNetwork
    
    var errorDescription: String? {
        switch self {
        case .cookiesDisabled:
            return "Cookies are disabled - please enable them to continue"
        case .notLoggedIn:
            return "Not logged in to Microsoft account"
        case .noNetwork:
            return "No network connection available"
        }
    }
}
