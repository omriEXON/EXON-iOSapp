import Foundation

struct PendingActivation {
    let productKey: String?
    let productKeys: [String]?
    let region: String
    let productName: String
    let productImage: String?
    let vendor: String?
    let sessionToken: String?
    let isTestMode: Bool
    let activationMethod: String?
    let orderNumber: String?
    let portalUrl: String?
    
    init(
        productKey: String? = nil,
        productKeys: [String]? = nil,
        region: String,
        productName: String,
        productImage: String? = nil,
        vendor: String? = "Microsoft Store",
        sessionToken: String? = nil,
        isTestMode: Bool = false,
        activationMethod: String? = nil,
        orderNumber: String? = nil,
        portalUrl: String? = nil
    ) {
        self.productKey = productKey
        self.productKeys = productKeys ?? (productKey.map { [$0] })
        self.region = region
        self.productName = productName
        self.productImage = productImage
        self.vendor = vendor
        self.sessionToken = sessionToken
        self.isTestMode = isTestMode
        self.activationMethod = activationMethod
        self.orderNumber = orderNumber
        self.portalUrl = portalUrl
    }
}

struct KeyValidationResult {
    let isValid: Bool
    let isAlreadyRedeemed: Bool
    let tokenState: String
    let productInfo: [String: Any]?
    let catalogError: Bool
}

struct BundleProgress {
    let total: Int
    var completed: Int
    var succeeded: Int
    var failed: Int
    var currentKey: String?
    var currentIndex: Int?
}

struct ActivationRecord: Codable {
    let id: String
    let productName: String
    let sessionToken: String?
    let timestamp: Date
    let success: Bool
    let errorMessage: String?
}

enum ActivationSource {
    case deepLink(sessionToken: String)
    case portal(sessionToken: String)
    case inApp(productKey: String, region: String)
    case testMode(license: String, region: String)
    case urlMonitor(sessionToken: String)
    case externalMessage(sessionToken: String)
    case manual(activation: PendingActivation)
}
