import Foundation

struct ActiveSubscription: Codable {
    let name: String
    let productId: String
    let endDate: String?
    let daysRemaining: Int?
    let hasPaymentIssue: Bool
    let autorenews: Bool
}
