import SwiftUI
import Foundation

class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()
    
    @Published var pendingActivation: ActivationRequest?
    @Published var shouldShowActivation = false
    
    struct ActivationRequest {
        let sessionToken: String
        let productId: String?
        let source: ActivationSource
    }
    
    enum ActivationSource {
        case deepLink
        case portal
        case inApp
    }
    
    private init() {}
    
    func handle(_ url: URL) {
        print("[DeepLink] Handling URL: \(url.absoluteString)")
        
        // Handle: exonactivate://session/{token}
        if url.scheme == "exonactivate" {
            if url.host == "session" {
                let pathComponents = url.pathComponents.filter { $0 != "/" }
                if let token = pathComponents.first {
                    print("[DeepLink] Found activation token: \(token)")
                    triggerActivation(token: token, source: .deepLink)
                }
            }
        }
        
        // Handle: exonstore://activate/{token}
        else if url.scheme == "exonstore" {
            if url.host == "activate" {
                let pathComponents = url.pathComponents.filter { $0 != "/" }
                if let token = pathComponents.first {
                    print("[DeepLink] Found store activation token: \(token)")
                    triggerActivation(token: token, source: .deepLink)
                }
            }
        }
        
        // Handle universal links: https://portal.exongames.co.il/activate/{token}
        else if url.host == "portal.exongames.co.il" {
            if url.path.contains("/activate/") {
                let components = url.pathComponents.filter { $0 != "/" && $0 != "activate" }
                if let token = components.first {
                    print("[DeepLink] Found portal activation token: \(token)")
                    triggerActivation(token: token, source: .portal)
                }
            }
        }
    }
    
    func triggerActivation(token: String, source: ActivationSource) {
        DispatchQueue.main.async {
            self.pendingActivation = ActivationRequest(
                sessionToken: token,
                productId: nil,
                source: source
            )
            self.shouldShowActivation = true
        }
    }
    
    func clearActivation() {
        DispatchQueue.main.async {
            self.pendingActivation = nil
            self.shouldShowActivation = false
        }
    }
}
