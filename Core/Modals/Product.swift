import Foundation

struct Product: Codable, Identifiable {
    let id: String
    var sessionToken: String?
    let productKey: String?
    let productKeys: [String]?
    let region: String
    let productName: String
    let productImage: String?
    let productId: String?
    let vendor: String?
    let status: String?
    let isBundle: Bool
    let activationMethod: String?
    let orderNumber: String?
    var portalUrl: String?
    let orderId: String?
    let expiresAt: Date?
    let isTestMode: Bool
    var addedAt: Date?
    var updatedAt: Date?
    
    // Add computed properties
    var isGamePass: Bool {
        guard let productId = productId else { return false }
        return ["CFQ7TTC0K5DJ", "CFQ7TTC0KHS0"].contains(productId)
    }
    
    init(
        id: String = UUID().uuidString,
        sessionToken: String? = nil,
        productKey: String? = nil,
        productKeys: [String]? = nil,
        region: String,
        productName: String,
        productImage: String? = nil,
        productId: String? = nil,
        vendor: String? = "Microsoft Store",
        status: String? = nil,
        isBundle: Bool = false,
        activationMethod: String? = nil,
        orderNumber: String? = nil,
        portalUrl: String? = nil,
        orderId: String? = nil,
        expiresAt: Date? = nil,
        isTestMode: Bool = false,
        addedAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.sessionToken = sessionToken
        self.productKey = productKey
        self.productKeys = productKeys
        self.region = region
        self.productName = productName
        self.productImage = productImage
        self.productId = productId
        self.vendor = vendor
        self.status = status
        self.isBundle = isBundle
        self.activationMethod = activationMethod
        self.orderNumber = orderNumber
        self.portalUrl = portalUrl
        self.orderId = orderId
        self.expiresAt = expiresAt
        self.isTestMode = isTestMode
        self.addedAt = addedAt
        self.updatedAt = updatedAt
    }
}
