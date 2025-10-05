import Foundation
import SwiftUI

final class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    @AppStorage("stored_products") private var productsData: Data = Data()
    @Published var products: [Product] = []
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        loadProducts()
    }
    
    // Save with deduplication
    func saveProduct(_ product: Product) async {
        await MainActor.run {
            // Check for duplicates by session token or key
            if let index = products.firstIndex(where: { existing in
                // Match by session token
                if let token1 = existing.sessionToken,
                   let token2 = product.sessionToken,
                   token1 == token2 {
                    return true
                }
                
                // Match by product key
                if let key1 = existing.productKey,
                   let key2 = product.productKey,
                   key1 == key2 {
                    return true
                }
                
                // Match by product keys array
                if let keys1 = existing.productKeys,
                   let keys2 = product.productKeys,
                   !Set(keys1).isDisjoint(with: Set(keys2)) {
                    return true
                }
                
                return false
            }) {
                // Update existing
                products[index] = product.withUpdatedTimestamp()
                print("[Storage] Updated existing product at index \(index)")
            } else {
                // Add new
                products.insert(product.withAddedTimestamp(), at: 0)
                print("[Storage] Added new product")
            }
            
            persistProducts()
        }
    }
    
    func removeProduct(_ product: Product) {
        products.removeAll { $0.id == product.id }
        persistProducts()
    }
    
    func clearExpiredProducts() {
        let now = Date()
        products.removeAll { product in
            guard let expiresAt = product.expiresAt else { return false }
            return expiresAt < now
        }
        persistProducts()
    }
    
    private func loadProducts() {
        guard !productsData.isEmpty else { return }
        
        do {
            products = try decoder.decode([Product].self, from: productsData)
            clearExpiredProducts()
        } catch {
            print("[Storage] Failed to decode products: \(error)")
            products = []
        }
    }
    
    private func persistProducts() {
        do {
            productsData = try encoder.encode(products)
        } catch {
            print("[Storage] Failed to encode products: \(error)")
        }
    }
}

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
}
