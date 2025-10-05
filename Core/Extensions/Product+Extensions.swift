import Foundation

extension Product {
    func withUpdatedTimestamp() -> Product {
        var copy = self
        copy.updatedAt = Date()
        return copy
    }
    
    func withAddedTimestamp() -> Product {
        var copy = self
        copy.addedAt = Date()
        copy.updatedAt = Date()
        return copy
    }
    
    var allKeys: [String] {
        if let keys = productKeys, !keys.isEmpty {
            return keys
        } else if let key = productKey {
            return [key]
        }
        return []
    }
}
