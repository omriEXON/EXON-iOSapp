import WebKit

struct WebViewScripts {
    
    static func createTokenCaptureScript() -> WKUserScript {
        let source = """
        (function() {
            window.ExonTokenCapture = {
                isReady: false,
                
                captureToken: async function() {
                    try {
                        const response = await fetch(
                            'https://account.microsoft.com/auth/acquire-onbehalf-of-token?scopes=MSComServiceMBISSL',
                            {
                                method: 'GET',
                                credentials: 'include',
                                headers: {
                                    'X-Requested-With': 'XMLHttpRequest',
                                    'Accept': 'application/json'
                                }
                            }
                        );
                        
                        if (!response.ok) {
                            throw new Error('Token request failed: ' + response.status);
                        }
                        
                        const data = await response.json();
                        
                        let token = null;
                        if (Array.isArray(data) && data[0]?.token) {
                            token = data[0].token;
                        } else if (data?.token) {
                            token = data.token;
                        }
                        
                        if (token) {
                            window.webkit.messageHandlers.tokenCapture.postMessage({
                                success: true,
                                token: token
                            });
                        } else {
                            throw new Error('Token not found in response');
                        }
                    } catch (error) {
                        window.webkit.messageHandlers.tokenCapture.postMessage({
                            success: false,
                            error: error.message
                        });
                    }
                }
            };
            
            // Auto-capture when ready
            if (document.readyState === 'complete') {
                window.ExonTokenCapture.isReady = true;
                if (window.location.hostname === 'account.microsoft.com') {
                    setTimeout(() => window.ExonTokenCapture.captureToken(), 1000);
                }
            } else {
                window.addEventListener('load', () => {
                    window.ExonTokenCapture.isReady = true;
                    if (window.location.hostname === 'account.microsoft.com') {
                        setTimeout(() => window.ExonTokenCapture.captureToken(), 1000);
                    }
                });
            }
        })();
        """
        
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }
    
    static func createFormHidingScript() -> WKUserScript {
        let source = """
        (function() {
            if (!window.location.href.includes('/billing/redeem')) return;
            
            const style = document.createElement('style');
            style.textContent = `
                body[data-exon-active="true"] #redeem-container,
                body[data-exon-active="true"] #store-cart-root,
                body[data-exon-active="true"] .redeemEnterCodePageContainer,
                body[data-exon-active="true"] [class*="redeemEnterCodePageContainer"] {
                    position: absolute !important;
                    left: -9999px !important;
                    top: -9999px !important;
                    width: 1px !important;
                    height: 1px !important;
                    overflow: hidden !important;
                }
            `;
            
            if (document.head) {
                document.head.insertBefore(style, document.head.firstChild);
            } else {
                document.addEventListener('DOMContentLoaded', () => {
                    document.head.insertBefore(style, document.head.firstChild);
                });
            }
            
            window.ExonFormHiding = {
                enable: function() {
                    document.body.setAttribute('data-exon-active', 'true');
                },
                disable: function() {
                    document.body.removeAttribute('data-exon-active');
                }
            };
        })();
        """
        
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
    }
    
    static func createConversionMonitorScript() -> WKUserScript {
        let source = """
        (function() {
            const originalFetch = window.fetch;
            window.conversionResults = {
                prepareRedeem: null,
                redeemToken: null
            };
            
            window.fetch = async function(...args) {
                const response = await originalFetch.apply(this, args);
                const url = args[0];
                
                if (typeof url === 'string') {
                    if (url.includes('PrepareRedeem')) {
                        const cloned = response.clone();
                        try {
                            const data = await cloned.json();
                            window.conversionResults.prepareRedeem = {
                                status: response.status,
                                success: response.ok,
                                data: data
                            };
                            window.webkit.messageHandlers.conversionHandler.postMessage({
                                type: 'prepareRedeem',
                                data: data
                            });
                        } catch (e) {}
                    }
                    
                    if (url.includes('RedeemToken')) {
                        const cloned = response.clone();
                        try {
                            const data = await cloned.json();
                            window.conversionResults.redeemToken = {
                                status: response.status,
                                success: response.ok,
                                data: data
                            };
                            window.webkit.messageHandlers.conversionHandler.postMessage({
                                type: 'redeemToken',
                                success: response.ok,
                                data: data
                            });
                        } catch (e) {}
                    }
                }
                
                return response;
            };
        })();
        """
        
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }
    
    static func createURLMonitorScript() -> WKUserScript {
        let source = """
        (function() {
            let lastURL = window.location.href;
            
            function checkURL() {
                if (window.location.href !== lastURL) {
                    lastURL = window.location.href;
                    
                    if (window.location.pathname.includes('/billing/redeem')) {
                        window.webkit.messageHandlers.urlMonitor.postMessage({
                            url: window.location.href,
                            isRedeemPage: true
                        });
                    }
                }
            }
            
            // Monitor pushState/replaceState
            const originalPushState = history.pushState;
            const originalReplaceState = history.replaceState;
            
            history.pushState = function() {
                originalPushState.apply(history, arguments);
                checkURL();
            };
            
            history.replaceState = function() {
                originalReplaceState.apply(history, arguments);
                checkURL();
            };
            
            window.addEventListener('popstate', checkURL);
            
            // Check on load
            if (document.readyState === 'complete') {
                checkURL();
            } else {
                window.addEventListener('load', checkURL);
            }
        })();
        """
        
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
    }
    
    static func createConversionAutomationScript(key: String) -> String {
        return """
        (function() {
            // Auto-fill key and process conversion
            setTimeout(() => {
                const input = document.querySelector('input[placeholder*="25-character"]');
                if (input) {
                    input.value = '\(key)';
                    input.dispatchEvent(new Event('input', { bubbles: true }));
                    
                    // Click Next
                    setTimeout(() => {
                        const nextBtn = document.querySelector('button.primary--DMe8vsrv');
                        if (nextBtn && !nextBtn.disabled) {
                            nextBtn.click();
                            
                            // Handle conversion flow
                            setTimeout(() => {
                                // Click Continue
                                const continueBtn = Array.from(document.querySelectorAll('button')).find(b => 
                                    b.textContent.trim() === 'Continue'
                                );
                                if (continueBtn) {
                                    continueBtn.click();
                                    
                                    // Turn off recurring billing and confirm
                                    setTimeout(() => {
                                        const toggle = document.querySelector('input[type="checkbox"]');
                                        if (toggle && toggle.checked) {
                                            toggle.click();
                                        }
                                        
                                        setTimeout(() => {
                                            const confirmBtn = Array.from(document.querySelectorAll('button')).find(b => 
                                                b.textContent.trim() === 'Confirm'
                                            );
                                            if (confirmBtn) {
                                                confirmBtn.click();
                                            }
                                        }, 1500);
                                    }, 2000);
                                }
                            }, 2500);
                        }
                    }, 2000);
                }
            }, 1000);
        })();
        """
    }
}
