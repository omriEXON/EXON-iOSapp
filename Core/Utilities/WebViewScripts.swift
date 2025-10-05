import WebKit

struct WebViewScripts {
    
    // MARK: - Token Capture Script (Matching Chrome Extension)
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
                        
                        // Extract token from various response formats
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
    
    // MARK: - Form Hiding Script (Matching Chrome Extension)
    static func createFormHidingScript() -> WKUserScript {
        let source = """
        (function() {
            if (!window.location.href.includes('/billing/redeem')) return;
            
            const style = document.createElement('style');
            style.textContent = `
                body[data-exon-active="true"] #redeem-container,
                body[data-exon-active="true"] #store-cart-root,
                body[data-exon-active="true"] .store-cart-root,
                body[data-exon-active="true"] [id="store-cart-root"],
                body[data-exon-active="true"] .redeemEnterCodePageContainer,
                body[data-exon-active="true"] [class*="redeemEnterCodePageContainer"],
                body[data-exon-active="true"] .content--XhykSwL6,
                body[data-exon-active="true"] .buttonGroup--WqDVN3o8 {
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
    
    // MARK: - Conversion Monitor Script (Matching Chrome Extension)
    static func createConversionMonitorScript() -> WKUserScript {
        let source = """
        (function() {
            if (window.__EXON_CONVERSION_MONITOR__) return;
            window.__EXON_CONVERSION_MONITOR__ = true;
            window.__EXON_CONVERSION_COMPLETE__ = false;
            
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
                            console.log('[EXON] PrepareRedeem captured');
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
                            console.log('[EXON] RedeemToken captured');
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
    
    // MARK: - Conversion Automation Script (Dynamic - matching Chrome Extension)
    static func createConversionAutomationScript(key: String) -> String {
        return """
        (function() {
            console.log('[EXON] Starting conversion automation for key');
            
            // Check if already attempted
            if (window.__EXON_CONVERSION_COMPLETE__) {
                console.log('[EXON] Conversion already attempted');
                return;
            }
            
            // Step 1: Find and fill the input
            function fillKey() {
                const input = document.querySelector('input[placeholder*="25-character"]') ||
                              document.querySelector('input[placeholder="Enter 25-character code"]');
                
                if (!input) {
                    console.log('[EXON] Input not found, retrying...');
                    setTimeout(fillKey, 500);
                    return;
                }
                
                input.value = '\(key)';
                
                // Trigger React onChange
                const reactKey = Object.keys(input).find(key => key.startsWith('__react'));
                if (reactKey) {
                    const reactProps = input[reactKey];
                    if (reactProps?.memoizedProps?.onChange) {
                        reactProps.memoizedProps.onChange({
                            target: input,
                            currentTarget: input
                        });
                    }
                }
                
                // Also trigger standard events
                input.dispatchEvent(new Event('input', { bubbles: true }));
                input.dispatchEvent(new Event('change', { bubbles: true }));
                
                console.log('[EXON] Key filled');
                
                // Wait for validation then click Next
                setTimeout(clickNext, 2000);
            }
            
            // Step 2: Click Next button
            function clickNext() {
                const nextBtn = document.querySelector('button[data-bi-dnt="true"].primary--DMe8vsrv') ||
                               document.querySelector('button.primary--DMe8vsrv') ||
                               Array.from(document.querySelectorAll('button')).find(b => 
                                   b.textContent.trim() === 'Next'
                               );
                
                if (!nextBtn || nextBtn.disabled) {
                    console.log('[EXON] Next button not ready, retrying...');
                    setTimeout(clickNext, 500);
                    return;
                }
                
                nextBtn.click();
                console.log('[EXON] Next button clicked');
                
                // Wait for page transition
                setTimeout(clickContinue, 2500);
            }
            
            // Step 3: Click Continue
            function clickContinue() {
                const continueBtn = Array.from(document.querySelectorAll('button')).find(b =>
                    b.textContent.trim() === 'Continue'
                ) || document.querySelector('button.primary--DMe8vsrv');
                
                if (!continueBtn || continueBtn.disabled) {
                    console.log('[EXON] Continue button not ready, retrying...');
                    setTimeout(clickContinue, 500);
                    return;
                }
                
                continueBtn.click();
                console.log('[EXON] Continue button clicked');
                
                // Wait for billing page
                setTimeout(handleBilling, 2000);
            }
            
            // Step 4: Handle billing options
            function handleBilling() {
                // Turn off recurring billing
                const toggle = document.querySelector('input[type="checkbox"]');
                if (toggle && toggle.checked) {
                    toggle.click();
                    console.log('[EXON] Recurring billing turned OFF');
                }
                
                // Click Confirm
                setTimeout(() => {
                    const confirmBtn = Array.from(document.querySelectorAll('button')).find(btn =>
                        btn.textContent.trim() === 'Confirm'
                    );
                    
                    if (confirmBtn && !confirmBtn.disabled) {
                        confirmBtn.click();
                        console.log('[EXON] Confirm button clicked');
                        
                        // Mark as complete
                        window.__EXON_CONVERSION_COMPLETE__ = true;
                        
                        // Check for success
                        setTimeout(checkSuccess, 3000);
                    } else {
                        setTimeout(handleBilling, 500);
                    }
                }, 1500);
            }
            
            // Step 5: Check for success
            function checkSuccess() {
                if (window.location.href.includes('redeem-success')) {
                    console.log('[EXON] Redemption successful!');
                    window.webkit.messageHandlers.conversionHandler.postMessage({
                        type: 'success',
                        source: 'success-page'
                    });
                } else if (window.conversionResults?.redeemToken) {
                    console.log('[EXON] RedeemToken captured');
                    window.webkit.messageHandlers.conversionHandler.postMessage({
                        type: 'success',
                        data: window.conversionResults.redeemToken
                    });
                } else {
                    // Keep checking
                    setTimeout(checkSuccess, 1000);
                }
            }
            
            // Start the automation
            fillKey();
        })();
        """
    }
    
    // MARK: - URL Monitor Script
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
}
