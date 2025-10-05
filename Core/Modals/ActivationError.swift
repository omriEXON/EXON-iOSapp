import Foundation

enum ActivationError: LocalizedError {
    case invalidSession
    case sessionExpired
    case productNotFound
    case noKeys
    case invalidKey
    case alreadyRedeemed
    case regionMismatch
    case regionRestricted
    case regionCheckFailed
    case activeSubscription
    case proxyError
    case proxyCredentialsFailed
    case proxyAuthenticationFailed
    case unsupportedRegion
    case noToken
    case tokenTimeout
    case tokenCaptureFailed(String)
    case networkError
    case validationFailed
    case activationFailed
    case invalidResponse
    case authenticationFailed
    case forbidden
    case conversionFailed
    case conversionTimeout
    case noWebView
    case cancelled
    case maxRetriesExceeded
    case vendorMismatch(expected: String, actual: String)
    case badRequest(String)
    case httpError(Int)
    case noActivationData
    
    var errorDescription: String? {
        switch self {
        case .invalidSession:
            return "Invalid activation session"
        case .sessionExpired:
            return "Session expired - please get a new activation link"
        case .productNotFound:
            return "Product not found"
        case .noKeys:
            return "No activation keys found"
        case .invalidKey:
            return "Invalid activation key"
        case .alreadyRedeemed:
            return "Key has already been redeemed"
        case .regionMismatch:
            return "Your account region doesn't match the product region"
        case .regionRestricted:
            return "This product is restricted to a specific region"
        case .regionCheckFailed:
            return "Failed to check account region"
        case .activeSubscription:
            return "You already have an active Game Pass subscription"
        case .proxyError:
            return "Failed to connect to proxy server"
        case .proxyCredentialsFailed:
            return "Failed to get proxy credentials"
        case .proxyAuthenticationFailed:
            return "Proxy authentication failed"
        case .unsupportedRegion:
            return "Unsupported region"
        case .noToken:
            return "Failed to get Microsoft token"
        case .tokenTimeout:
            return "Token capture timed out"
        case .tokenCaptureFailed(let reason):
            return "Token capture failed: \(reason)"
        case .networkError:
            return "Network error occurred"
        case .validationFailed:
            return "Key validation failed"
        case .activationFailed:
            return "Activation failed"
        case .invalidResponse:
            return "Invalid server response"
        case .authenticationFailed:
            return "Authentication failed"
        case .forbidden:
            return "Access forbidden"
        case .conversionFailed:
            return "Game Pass conversion failed"
        case .conversionTimeout:
            return "Game Pass conversion timed out"
        case .noWebView:
            return "WebView not available"
        case .cancelled:
            return "Operation cancelled"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        case .vendorMismatch(let expected, let actual):
            return "Vendor mismatch: expected \(expected), got \(actual)"
        case .badRequest(let details):
            return "Bad request: \(details)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .noActivationData:
            return "No activation data available"
        }
    }
}
