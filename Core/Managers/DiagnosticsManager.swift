import Foundation
import WebKit

final class DiagnosticsManager {
    
    func runDiagnostics(webView: WKWebView?) async -> DiagnosticResults {
        async let cookiesCheck = checkCookiesEnabled(webView: webView)
        async let loginCheck = checkMicrosoftLogin(webView: webView)
        async let networkCheck = checkNetworkAvailability()
        async let regionCheck = checkAccountRegion(webView: webView)
        async let gamePassCheck = checkGamePassStatus(webView: webView)
        
        return DiagnosticResults(
            cookiesEnabled: await cookiesCheck,
            loggedIn: await loginCheck,
            networkAvailable: await networkCheck,
            accountRegion: await regionCheck,
            hasGamePass: await gamePassCheck
        )
    }
    
    private func checkCookiesEnabled(webView: WKWebView?) async -> Bool {
        guard let webView = webView else { return false }
        
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript("navigator.cookieEnabled") { result, error in
                continuation.resume(returning: (result as? Bool) ?? false)
            }
        }
    }
    
    private func checkMicrosoftLogin(webView: WKWebView?) async -> Bool {
        guard let webView = webView else { return false }
        
        // Load Microsoft account page
        let url = URL(string: "https://account.microsoft.com/")!
        webView.load(URLRequest(url: url))
        
        // Wait for load
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Check for login indicators
        return await withCheckedContinuation { continuation in
            let script = """
                (function() {
                    // Check for various login indicators
                    const loggedIn = 
                        document.querySelector('[data-bi-name="profile"]') !== null ||
                        document.querySelector('.mectrl_header_text') !== null ||
                        document.cookie.includes('MUID=') ||
                        window.location.pathname !== '/account/enroll';
                    return loggedIn;
                })();
            """
            
            webView.evaluateJavaScript(script) { result, error in
                continuation.resume(returning: (result as? Bool) ?? false)
            }
        }
    }
    
    private func checkNetworkAvailability() async -> Bool {
        return NetworkManager.shared.isNetworkAvailable
    }
    
    private func checkAccountRegion(webView: WKWebView?) async -> String? {
        guard let webView = webView else { return nil }
        
        return await withCheckedContinuation { continuation in
            let script = """
                (async function() {
                    try {
                        const response = await fetch(
                            'https://account.microsoft.com/profile/api/v1/personal-info',
                            {
                                method: 'GET',
                                credentials: 'include',
                                headers: {
                                    'X-Requested-With': 'XMLHttpRequest'
                                }
                            }
                        );
                        if (response.ok) {
                            const data = await response.json();
                            return data.country || data.region;
                        }
                    } catch (e) {}
                    return null;
                })();
            """
            
            webView.evaluateJavaScript(script) { result, error in
                continuation.resume(returning: result as? String)
            }
        }
    }
    
    private func checkGamePassStatus(webView: WKWebView?) async -> Bool {
        guard let webView = webView else { return false }
        
        return await withCheckedContinuation { continuation in
            let script = """
                (async function() {
                    try {
                        const response = await fetch(
                            'https://account.microsoft.com/services/api/subscriptions-and-alerts',
                            {
                                method: 'GET',
                                credentials: 'include',
                                headers: {
                                    'X-Requested-With': 'XMLHttpRequest'
                                }
                            }
                        );
                        if (response.ok) {
                            const data = await response.json();
                            if (data.active && Array.isArray(data.active)) {
                                const gamePassIds = ['CFQ7TTC0K5DJ', 'CFQ7TTC0KHS0'];
                                return data.active.some(sub => 
                                    gamePassIds.includes(sub.productId)
                                );
                            }
                        }
                    } catch (e) {}
                    return false;
                })();
            """
            
            webView.evaluateJavaScript(script) { result, error in
                continuation.resume(returning: (result as? Bool) ?? false)
            }
        }
    }
}
