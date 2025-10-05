import Foundation

struct ActiveProxy {
    let region: String
    let host: String
    let port: Int
    let startTime: Date
}

struct AuthCacheEntry {
    let credentials: URLCredential
    let expires: Date
}

struct TokenCacheEntry {
    let token: String
    let expires: Date
}

struct ProxyCredentials: Codable {
    let username: String
    let password: String
    let expiresAt: Date
    
    enum CodingKeys: String, CodingKey {
        case username = "user"
        case password
        case expiresAt = "expires_at"
    }
    
    var isExpired: Bool {
        return Date() >= expiresAt
    }
}
