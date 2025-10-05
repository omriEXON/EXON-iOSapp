import Foundation

enum APIError: LocalizedError {
    case accountInfoFailed
    case subscriptionsFetchFailed
    case catalogFetchFailed
    case catalogNotFound
    case userAlreadyOwnsContent([String])
    case conversionConsentRequired
    case invalidResponse
    case marketMismatch
    case serverError(Int)
    case gatewayTimeout
    
    var errorDescription: String? {
        switch self {
        case .accountInfoFailed:
            return "Failed to fetch account information"
        case .subscriptionsFetchFailed:
            return "Failed to fetch subscriptions"
        case .catalogFetchFailed:
            return "Failed to fetch product catalog"
        case .catalogNotFound:
            return "Product not found in catalog"
        case .userAlreadyOwnsContent(let products):
            return "User already owns: \(products.joined(separator: ", "))"
        case .conversionConsentRequired:
            return "Game Pass conversion consent required"
        case .invalidResponse:
            return "Invalid server response"
        case .marketMismatch:
            return "Market mismatch - region conflict"
        case .serverError(let code):
            return "Server error: \(code)"
        case .gatewayTimeout:
            return "Gateway timeout"
        }
    }
}
