import Foundation

struct ErrorAnalyzer {
    
    struct ErrorInfo {
        let message: String
        let isRecoverable: Bool
        let isAlreadyOwned: Bool
        let isAlreadyRedeemed: Bool
        let requiresConversion: Bool
        let ownedProducts: [String]
    }
    
    static func analyzeActivationError(_ error: Error, key: String? = nil) -> ErrorInfo {
        let errorMessage = error.localizedDescription
        
        // Check for already owned
        if errorMessage.contains("UserAlreadyOwnsContent") {
            var ownedProducts: [String] = []
            
            // Try to extract owned product IDs from error
            if let range = errorMessage.range(of: "\"data\":[") {
                let substring = String(errorMessage[range.upperBound...])
                if let endRange = substring.range(of: "]") {
                    let productsString = String(substring[..<endRange.lowerBound])
                    ownedProducts = productsString
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"' ")) }
                }
            }
            
            return ErrorInfo(
                message: "User already owns this content",
                isRecoverable: false,
                isAlreadyOwned: true,
                isAlreadyRedeemed: false,
                requiresConversion: false,
                ownedProducts: ownedProducts
            )
        }
        
        // Check for already redeemed
        let redeemedIndicators = [
            "TokenAlreadyRedeemed",
            "already been redeemed",
            "already redeemed",
            "is Redeemed"
        ]
        
        if redeemedIndicators.contains(where: errorMessage.contains) {
            return ErrorInfo(
                message: "Key has already been redeemed",
                isRecoverable: false,
                isAlreadyOwned: false,
                isAlreadyRedeemed: true,
                requiresConversion: false,
                ownedProducts: []
            )
        }
        
        // Check for conversion required
        if errorMessage.contains("ConversionConsentRequired") ||
           errorMessage.contains("Game Pass conversion") {
            return ErrorInfo(
                message: "Game Pass conversion required",
                isRecoverable: true,
                isAlreadyOwned: false,
                isAlreadyRedeemed: false,
                requiresConversion: true,
                ownedProducts: []
            )
        }
        
        // Check for network/timeout errors (recoverable)
        let recoverableErrors = [
            "timeout",
            "network",
            "connection lost",
            "gateway",
            "503",
            "502",
            "504"
        ]
        
        let isRecoverable = recoverableErrors.contains {
            errorMessage.lowercased().contains($0)
        }
        
        return ErrorInfo(
            message: errorMessage,
            isRecoverable: isRecoverable,
            isAlreadyOwned: false,
            isAlreadyRedeemed: false,
            requiresConversion: false,
            ownedProducts: []
        )
    }
    
    static func shouldRetryError(_ error: Error) -> Bool {
        let errorInfo = analyzeActivationError(error)
        return errorInfo.isRecoverable
    }
    
    static func isProxyAuthError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("407") ||
               message.contains("proxy authentication") ||
               message.contains("proxy auth")
    }
    
    static func isCatalogError(_ error: Error) -> Bool {
        let message = error.localizedDescription
        return message.contains("CatalogSkuDataNotFound") ||
               message.contains("catalog not found")
    }
    
    static func isMarketMismatchError(_ error: Error) -> Bool {
        let message = error.localizedDescription
        return message.contains("ActiveMarketMismatch") ||
               message.contains("market mismatch")
    }
}
