import Foundation

struct Product: Codable, Identifiable {
    let id: String
    let productName: String
    let productImage: String?
    let productKey: String?
    let productKeys: [String]?
    let region: String
    let sessionToken: String?
    let vendor: String?
    let status: String?
    let isGamePass: Bool?
    let isBundle: Bool
    let activationMethod: String?
    let orderNumber: String?
    let portalUrl: String?
    let productId: String?
    let expiresAt: Date?
    var addedAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case productName = "product_name"
        case productImage = "product_image"
        case productKey = "product_key"
        case productKeys = "product_keys"
        case region
        case sessionToken = "session_token"
        case vendor
        case status
        case isGamePass = "is_game_pass"
        case isBundle = "is_bundle"
        case activationMethod = "activation_method"
        case orderNumber = "order_number"
        case portalUrl = "portal_url"
        case productId = "product_id"
        case expiresAt = "expires_at"
        case addedAt = "added_at"
        case updatedAt = "updated_at"
    }
    
    var allKeys: [String] {
        if let keys = productKeys, !keys.isEmpty {
            return keys
        } else if let key = productKey {
            return [key]
        }
        return []
    }
    
    init(from activation: PendingActivation) {
        self.id = UUID().uuidString
        self.productName = activation.productName
        self.productImage = activation.productImage
        self.productKey = activation.productKey
        self.productKeys = activation.productKeys
        self.region = activation.region
        self.sessionToken = activation.sessionToken
        self.vendor = activation.vendor ?? "Microsoft Store"
        self.status = "pending"
        self.isGamePass = false
        self.isBundle = (activation.productKeys?.count ?? 0) > 1
        self.activationMethod = activation.activationMethod
        self.orderNumber = activation.orderNumber
        self.portalUrl = activation.portalUrl
        self.productId = nil
        self.expiresAt = nil
        self.addedAt = Date()
        self.updatedAt = Date()
    }
}
