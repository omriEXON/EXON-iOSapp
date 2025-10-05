import Foundation

enum ActivationState: Equatable {
    case idle
    case initializing
    case runningDiagnostics
    case fetchingProduct
    case validatingKey
    case checkingGamePass
    case capturingToken
    case activating
    case activatingBundle
    case handlingConversion
    case success(productName: String, keys: [String])
    case partialSuccess(succeeded: Int, total: Int, failed: [(key: String, error: String, isAlreadyOwned: Bool, isAlreadyRedeemed: Bool, ownedProducts: [String])])
    case error(String)
    case alreadyOwned(products: [String])
    case alreadyRedeemed
    case regionMismatch(accountRegion: String, keyRegion: String)
    case activeSubscription(subscription: ActiveSubscription)
    case expiredSession
    case requiresDigitalAccount
    case diagnosticsError(DiagnosticError)
    
    var isProcessing: Bool {
        switch self {
        case .idle, .success, .partialSuccess, .error, .alreadyOwned,
             .alreadyRedeemed, .regionMismatch, .activeSubscription,
             .expiredSession, .requiresDigitalAccount, .diagnosticsError:
            return false
        default:
            return true
        }
    }
}
