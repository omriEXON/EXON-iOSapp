import SwiftUI
import WebKit

struct StoreWebView: UIViewRepresentable {
    let url: URL
    @Binding var webView: WKWebView?
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        // Inject CSS to hide website navigation and chat elements
        let cssString = """
        /* Hide website header */
        #shopify-section-sections--18779914961142__header,
        .header,
        .site-header,
        .main-header,
        .navbar,
        nav.navbar,
        .top-bar {
            display: none !important;
        }
        
        /* Hide website footer */
        .footer,
        .site-footer,
        .main-footer,
        #shopify-section-footer {
            display: none !important;
        }
        
        /* Hide Intercom chat - comprehensive selectors */
        #intercom-container-body,
        .intercom-lightweight-app-launcher,
        .launcher__floating-button.launcher__widget,
        .launcher__floating-button--closed,
        .launcher__floating-button-content,
        .launcher__floating-button,
        button.launcher__floating-button,
        div.launcher__floating-button,
        .intercom-launcher,
        .intercom-app,
        iframe#intercom-frame,
        [class*="launcher__floating-button"],
        [class*="intercom"],
        div[class*="launcher"],
        button[class*="launcher"] {
            display: none !important;
            visibility: hidden !important;
            opacity: 0 !important;
        }
        
        /* Hide breadcrumbs */
        .breadcrumb,
        .breadcrumbs,
        .breadcrumb-navigation {
            display: none !important;
        }
        
        /* Hide social media buttons */
        .social-share,
        .share-buttons,
        .social-buttons {
            display: none !important;
        }
        
        /* Hide newsletter signup */
        .newsletter,
        .newsletter-signup,
        .email-signup {
            display: none !important;
        }
        
        /* Hide cookie banners */
        .cookie-banner,
        .cookie-notice,
        .gdpr-banner,
        .consent-banner {
            display: none !important;
        }
        
        /* Hide any other bottom floating elements */
        .fixed.z-\\[990\\],
        .fixed.bottom-4,
        .fixed.bottom-6,
        .fixed.bottom-8,
        .sticky-bottom,
        .floating-button,
        .fab {
            display: none !important;
        }
        
        /* Hide mobile app download banners */
        .app-banner,
        .download-app,
        .mobile-app-banner,
        .smart-app-banner {
            display: none !important;
        }
        
        /* Hide back to top buttons */
        .back-to-top,
        .scroll-to-top,
        #back-to-top {
            display: none !important;
        }
        
        /* Hide language/currency selectors if not needed */
        .language-selector,
        .currency-selector,
        .locale-selector {
            display: none !important;
        }
        
        /* Add some top padding to compensate for hidden header if needed */
        body.warehouse--v4.template-product,
        .warehouse--v4.template-product,
        body,
        .main-content,
        .page-container {
            padding-top: 0 !important;
            margin-top: 0 !important;
        }
        
        /* Ensure full viewport usage */
        body {
            padding-top: 0 !important;
            margin-top: 0 !important;
        }
        
        /* Hide any promotional banners */
        .promo-banner,
        .announcement-bar,
        .top-banner {
            display: none !important;
        }
        """
        
        let script = """
        // Apply CSS styles
        var style = document.createElement('style');
        style.innerHTML = `\(cssString)`;
        document.head.appendChild(style);
        
        // Function to actively remove Intercom elements
        function removeIntercomElements() {
            const selectors = [
                '#intercom-container-body',
                '.intercom-lightweight-app-launcher',
                '.launcher__floating-button',
                '.launcher__floating-button-content',
                'button.launcher__floating-button',
                'div.launcher__floating-button',
                '.launcher__floating-button.launcher__widget',
                '.launcher__floating-button--closed',
                '.intercom-launcher',
                '.intercom-app',
                'iframe#intercom-frame',
                '[class*="launcher__floating-button"]',
                '[class*="intercom"]',
                'div[class*="launcher"]',
                'button[class*="launcher"]'
            ];
            
            selectors.forEach(selector => {
                document.querySelectorAll(selector).forEach(el => {
                    el.remove();
                });
            });
        }
        
        // Run removal function immediately
        removeIntercomElements();
        
        // Run removal function when DOM is ready
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', removeIntercomElements);
        }
        
        // Run removal function periodically to catch dynamically added elements
        setInterval(removeIntercomElements, 1000);
        
        // Observer for dynamically added elements
        const observer = new MutationObserver(function(mutations) {
            removeIntercomElements();
        });
        
        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
        """
        
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(userScript)
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = true
        
        // Assign to binding so ContentView can access it
        DispatchQueue.main.async {
            self.webView = webView
        }
        
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Leave empty - the loading happens in makeUIView
    }
}