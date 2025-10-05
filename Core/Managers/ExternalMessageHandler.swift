import Foundation
import WebKit

final class ExternalMessageHandler: NSObject {
    static let shared = ExternalMessageHandler()
    
    private weak var webView: WKWebView?
    private let allowedDomains = ["exongames.co.il", "exon-israel.myshopify.com"]
    
    func setupWebView(_ webView: WKWebView) {
        self.webView = webView
        
        // Add message handler for external messages
        webView.configuration.userContentController.add(self, name: "externalMessage")
        
        // Inject script to handle postMessage from Shopify
        let script = """
        window.addEventListener('message', function(event) {
            // Verify origin
            const allowedOrigins = ['https://exongames.co.il', 'https://exon-israel.myshopify.com'];
            
            if (!allowedOrigins.some(origin => event.origin === origin)) {
                return;
            }
            
            // Forward to native
            if (event.data && event.data.action === 'ACTIVATE_PRODUCT') {
                window.webkit.messageHandlers.externalMessage.postMessage({
                    action: event.data.action,
                    session_token: event.data.session_token
                });
            }
        });
        """
        
        let userScript = WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        
        webView.configuration.userContentController.addUserScript(userScript)
    }
    
    func handleMessage(_ message: [String: Any]) async {
        guard let action = message["action"] as? String,
              action == "ACTIVATE_PRODUCT",
              let sessionToken = message["session_token"] as? String else {
            return
        }
        
        print("[ExternalMessage] Received activation request for session: \(sessionToken)")
        
        // Store product and trigger activation
        await StorageManager.shared.saveProductFromSession(sessionToken)
        
        // Trigger activation
        await ActivationManager.shared.startActivation(
            from: .externalMessage(sessionToken: sessionToken)
        )
    }
}

extension ExternalMessageHandler: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "externalMessage",
              let body = message.body as? [String: Any] else {
            return
        }
        
        Task {
            await handleMessage(body)
        }
    }
}
