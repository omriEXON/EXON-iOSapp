import Foundation

struct SessionData: Codable {
    let sessionToken: String
    let orderId: String
    let lineItemId: String
    let licenseKey: String?
    let licenseKeys: [String]?
    let region: String?
    let productName: String?
    let productId: String?
    let productImage: String?
    let vendor: String?
    let status: String?
    let expiresAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case sessionToken = "session_token"
        case orderId = "order_id"
        case lineItemId = "line_item_id"
        case licenseKey = "license_key"
        case licenseKeys = "license_keys"
        case region, vendor, status
        case productName = "product_name"
        case productId = "product_id"
        case productImage = "product_image"
        case expiresAt = "expires_at"
    }
}

struct ReadinessData: Codable {
    let activationMethod: String?
    let orderNumber: String?
    
    enum CodingKeys: String, CodingKey {
        case activationMethod = "activation_method"
        case orderNumber = "order_number"
    }
}
