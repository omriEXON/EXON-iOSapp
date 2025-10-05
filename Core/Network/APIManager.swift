import Foundation

final class ApiManager {
    static let shared = ApiManager()
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Fetch Product from Session
    func fetchProductFromSession(_ sessionToken: String) async throws -> Product {
        let url = URL(string: "\(Config.Supabase.url)/rest/v1/activation_sessions")!
            .appending(queryItems: [
                URLQueryItem(name: "session_token", value: "eq.\(sessionToken)"),
                URLQueryItem(name: "select", value: "*")
            ])
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(Config.Supabase.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Config.Supabase.anonKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ActivationError.invalidSession
        }
        
        let products = try JSONDecoder().decode([Product].self, from: data)
        guard let product = products.first else {
            throw ActivationError.productNotFound
        }
        
        // Check if session is expired
        if let expiresAt = product.expiresAt,
           expiresAt < Date() {
            throw ActivationError.sessionExpired
        }
        
        return product
    }
    
    // MARK: - Mark Activated
    func markActivated(sessionToken: String, success: Bool = true) async throws {
        let url = URL(string: "\(Config.Supabase.url)/functions/v1/mark-activated")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.Supabase.anonKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "session_token": sessionToken,
            "success": success
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            print("[API] Warning: Failed to mark as activated - status \(httpResponse.statusCode)")
        }
    }
    
    // MARK: - Enrich Product Data
    func enrichProductData(_ tokenData: [String: Any], market: String) async throws -> [String: Any] {
        var enrichedData = tokenData
        
        // Extract product ID from assetId
        guard let assetId = tokenData["assetId"] as? String,
              let productId = assetId.split(separator: "/").first.map(String.init) else {
            return tokenData
        }
        
        let catalogUrl = URL(string: "https://displaycatalog.mp.microsoft.com/v7.0/products/\(productId)?market=\(market)&languages=en-US")!
        
        var request = URLRequest(url: catalogUrl)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let product = json["Product"] as? [String: Any],
                  let localizedProps = (product["LocalizedProperties"] as? [[String: Any]])?.first else {
                return tokenData
            }
            
            // Add enriched data
            enrichedData["productName"] = localizedProps["ProductTitle"] as? String ??
                                         localizedProps["ShortTitle"] as? String ??
                                         "Microsoft Product"
            
            // Get best image
            if let images = localizedProps["Images"] as? [[String: Any]] {
                let imageTypes = ["Poster", "BoxArt", "SuperHeroArt", "Hero", "Tile", "Logo"]
                for type in imageTypes {
                    if let image = images.first(where: { $0["ImagePurpose"] as? String == type }),
                       let uri = image["Uri"] as? String {
                        enrichedData["productImage"] = uri.starts(with: "//") ? "https:\(uri)" : uri
                        break
                    }
                }
            }
            
            enrichedData["productId"] = productId
            
        } catch {
            print("[API] Failed to enrich product data: \(error)")
        }
        
        return enrichedData
    }
    
    // MARK: - Check Account Region
    func fetchAccountRegion(token: String) async throws -> (region: String, market: String) {
        let url = URL(string: "https://account.microsoft.com/profile/api/v1/personal-info")!
        
        var request = URLRequest(url: url)
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.accountInfoFailed
        }
        
        let region = json["region"] as? String ?? json["country"] as? String ?? "US"
        let market = json["market"] as? String ?? region
        
        return (region: region, market: market)
    }
    
    // MARK: - Check Active Subscriptions
    func fetchActiveSubscriptions(token: String) async throws -> SubscriptionStatus {
        let url = URL(string: "https://account.microsoft.com/services/api/subscriptions-and-alerts?excludeWindowsStoreInstallOptions=false&excludeLegacySubscriptions=false")!
        
        var request = URLRequest(url: url)
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.subscriptionsFetchFailed
        }
        
        var hasActiveGamePass = false
        var activeSubscription: ActiveSubscription?
        
        if let activeList = json["active"] as? [[String: Any]] {
            for sub in activeList {
                guard let productId = sub["productId"] as? String else { continue }
                
                // Check for Game Pass Core or Ultimate
                if productId == "CFQ7TTC0K5DJ" || productId == "CFQ7TTC0KHS0" {
                    hasActiveGamePass = true
                    
                    let hasPaymentIssue = (sub["billingState"] as? Int) == 3 ||
                                         !(sub["autorenews"] as? Bool ?? false) ||
                                         (sub["payment"] as? [String: Any])?["valid"] as? Bool == false
                    
                    activeSubscription = ActiveSubscription(
                        name: sub["name"] as? String ?? "Game Pass",
                        productId: productId,
                        endDate: sub["endDate"] as? String,
                        daysRemaining: sub["daysRemaining"] as? Int,
                        hasPaymentIssue: hasPaymentIssue,
                        autorenews: sub["autorenews"] as? Bool ?? false
                    )
                    break
                }
            }
        }
        
        return SubscriptionStatus(
            hasActiveGamePass: hasActiveGamePass,
            activeSubscription: activeSubscription
        )
    }
    
    struct SubscriptionStatus {
        let hasActiveGamePass: Bool
        let activeSubscription: ActiveSubscription?
    }
}
