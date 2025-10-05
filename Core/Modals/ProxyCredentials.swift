import Foundation

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
