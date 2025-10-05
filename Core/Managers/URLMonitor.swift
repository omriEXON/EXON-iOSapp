import Foundation
import WebKit

final class URLMonitor {
    weak var activationManager: ActivationManager?
    private var lastProcessedURL: String?
    
    func shouldProcessURL(_ url: URL) -> Bool {
        // Check if it's a redeem page
        guard url.path.contains("/billing/redeem") ||
              url.path.contains("/redeem") else {
            return false
        }
        
        // Avoid processing same URL twice
        let urlString = url.absoluteString
        if urlString == lastProcessedURL {
            return false
        }
        
        lastProcessedURL = urlString
        return true
    }
    
    func extractActivationData(from url: URL) -> PendingActivation? {
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        
        // Check for session token
        if let sessionToken = queryItems?.first(where: { $0.name == "session" })?.value {
            return PendingActivation(
                productKey: nil,
                productKeys: nil,
                region: "IL",
                productName: "Loading...",
                productImage: nil,
                vendor: "Microsoft Store",
                sessionToken: sessionToken,
                isTestMode: false
            )
        }
        
        // Check for test mode
        if let license = queryItems?.first(where: { $0.name == "license" })?.value {
            let region = queryItems?.first(where: { $0.name == "region" })?.value ?? "IL"
            
            return PendingActivation(
                productKey: license,
                productKeys: [license],
                region: region,
                productName: "Test Product",
                productImage: nil,
                vendor: "Microsoft Store",
                sessionToken: nil,
                isTestMode: true
            )
        }
        
        return nil
    }
}
