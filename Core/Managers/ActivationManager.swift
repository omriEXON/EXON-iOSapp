import Foundation
import WebKit
import Combine

// MARK: - Main Activation Manager (Production Ready)
@MainActor
final class ActivationManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = ActivationManager()
    
    // MARK: - Published State
    @Published var isActivating = false
    @Published var activationState: ActivationState = .idle
    @Published var currentProduct: Product?
    @Published var errorMessage: String?
    @Published var activationProgress: Double = 0.0
    @Published var bundleProgress: BundleProgress?
    
    // MARK: - WebView Management
    private var hiddenWebView: WKWebView?
    private var conversionWebView: WKWebView?
    private var formHidingEnabled = false
    private var lastProcessedURL: String?
    
    // MARK: - State Management (Matching Chrome Extension)
    private var microsoftToken: String?
    private var tokenContinuation: CheckedContinuation<String, Error>?
    private var conversionContinuation: CheckedContinuation<Bool, Error>?
    private var pendingActivation: PendingActivation?
    
    // MARK: - Auth & Proxy Management
    private var authCache: [String: AuthCacheEntry] = [:]
    private var pendingRequests: [String: Int] = [:]
    private var activeProxy: ActiveProxy?
    private var tokenCache: [String: TokenCacheEntry] = [:]
    
    // MARK: - Bundle State (Matching Chrome Extension)
    private var bundleState: BundleActivationState?
    
    // MARK: - Retry Management
    private var tokenRetryCount = 0
    private var proxyAuthRetryCount: [String: Int] = [:]
    
    // MARK: - Managers
    private let credentialsManager = CredentialsManager.shared
    private var cleanupTimer: Timer?
    private var lastCleanup = Date()
    
    // MARK: - Storage
    private var storedProducts: [StoredProduct] = []
    
    // MARK: - Constants (From Chrome Extension)
    private struct Constants {
        static let tokenTimeout: TimeInterval = 30
        static let conversionTimeout: TimeInterval = 30
        static let bundleKeyDelay: TimeInterval = 3
        static let maxTokenRetries = 3
        static let maxProxyRetries = 2
        static let authCacheDuration: TimeInterval = 300
        static let tokenCacheDuration: TimeInterval = 3600
        static let gamePassProductIds = ["CFQ7TTC0K5DJ", "CFQ7TTC0KHS0"]
        static let supportWhatsApp = "972557207138"
        static let microsoftTargetHosts = [
            "account.microsoft.com",
            "redeem.microsoft.com",
            "www.microsoft.com",
            "purchase.mp.microsoft.com",
            "displaycatalog.mp.microsoft.com",
            "browser.events.data.microsoft.com"
        ]
        static let allowedShopifyOrigins = [
            "https://exongames.co.il",
            "https://exon-israel.myshopify.com"
        ]
    }
    
    // MARK: - Types
    struct ActiveProxy {
        let region: String
        let host: String
        let port: Int
        let startTime: Date
    }
    
    struct AuthCacheEntry {
        let credentials: URLCredential
        let expires: Date
    }
    
    struct TokenCacheEntry {
        let token: String
        let expires: Date
    }
    
    // MARK: - Initialization
    override private init() {
        super.init()
        Task { @MainActor in
            setupWebViews()
            setupCleanupTimer()
            loadStoredProducts()
        }
    }
    
    // MARK: - Main Activation Entry Point (Matching Chrome Extension)
    func startActivation(sessionToken: String) async {
        await resetState()
        
        await MainActor.run {
            self.isActivating = true
            self.activationState = .initializing
            self.errorMessage = nil
            self.activationProgress = 0.0
        }
        
        do {
            // Step 1: Get product from session (matching Chrome getProductBySessionToken)
            let product = try await getProductBySessionToken(sessionToken)
            
            await MainActor.run {
                self.currentProduct = product
                self.activationProgress = 0.05
            }
            
            // Check for digital account activation method
            if product.activationMethod == "digital_account" ||
               product.activationMethod == "Digital Account" {
                
                // Generate portal URL if needed
                if product.portalUrl == nil {
                    let portalUrl = try await generatePortalURL(
                        orderId: product.orderId,
                        orderNumber: product.orderNumber
                    )
                    product.portalUrl = portalUrl
                }
                
                await MainActor.run {
                    self.activationState = .requiresDigitalAccount
                    self.isActivating = false
                }
                return
            }
            
            // Store product without duplicates (matching Chrome addProductToStorage)
            await addProductToStorage(product)
            
            // Check if session expired
            if let expiresAt = product.expiresAt, expiresAt < Date() {
                await MainActor.run {
                    self.activationState = .expiredSession
                    self.isActivating = false
                }
                throw ActivationError.sessionExpired
            }
            
            // Step 2: Validate vendor
            let vendorCheck = verifyVendorForCurrentPage(product.vendor ?? "Microsoft Store")
            if !vendorCheck.valid {
                throw ActivationError.vendorMismatch(
                    expected: vendorCheck.expected ?? "Microsoft Store",
                    actual: product.vendor ?? "Unknown"
                )
            }
            
            // Step 3: Check if already redeemed
            if isKeyRedeemed(product.status) {
                await MainActor.run {
                    self.activationState = .alreadyRedeemed
                    self.isActivating = false
                }
                return
            }
            
            // Step 4: Check for Game Pass products
            if isGamePassProduct(product) {
                try await performGamePassChecks(product)
            }
            
            // Step 5: Capture Microsoft Token (with retry logic)
            await MainActor.run {
                self.activationState = .capturingToken
                self.activationProgress = 0.3
            }
            
            let token = try await captureTokenWithRetry()
            self.microsoftToken = token
            
            // Step 6: Enable form hiding
            if !product.isTestMode {
                await enableFormHiding()
            }
            
            // Step 7: Process activation (bundle or single)
            if product.isBundle {
                try await processBundleActivation(product: product, token: token)
            } else {
                try await processSingleKeyActivation(product: product, token: token)
            }
            
            // Step 8: Mark as activated
            try await markAsActivated(sessionToken: sessionToken, success: true)
            
            // Step 9: Cleanup
            await performCleanup()
            
        } catch {
            await handleActivationError(error)
            
            // Try to mark as failed
            try? await markAsActivated(sessionToken: sessionToken, success: false)
        }
    }
    
    // MARK: - Get Product By Session Token (Matching Chrome Extension)
    private func getProductBySessionToken(_ sessionToken: String) async throws -> Product {
        devLog("[Product] Fetching from database for session: \(sessionToken)")
        
        // Fetch session details from Supabase
        let url = URL(string: "\(Config.supabase.url)/rest/v1/activation_sessions")!
            .appending(queryItems: [
                URLQueryItem(name: "session_token", value: "eq.\(sessionToken)"),
                URLQueryItem(name: "select", value: "session_token,order_id,line_item_id,license_key,license_keys,region,product_name,product_id,product_image,vendor,status,expires_at")
            ])
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(Config.supabase.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Config.supabase.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ActivationError.invalidSession
        }
        
        let sessions = try JSONDecoder().decode([SessionData].self, from: data)
        guard let session = sessions.first else {
            throw ActivationError.sessionNotFound
        }
        
        // Check if session expired
        if let expiresAt = session.expiresAt, Date() > expiresAt {
            throw ActivationError.sessionExpired
        }
        
        // Fetch activation method and order number
        var activationMethod: String?
        var orderNumber: String?
        
        do {
            let readinessUrl = URL(string: "\(Config.supabase.url)/rest/v1/line_item_readiness")!
                .appending(queryItems: [
                    URLQueryItem(name: "order_id", value: "eq.\(session.orderId)"),
                    URLQueryItem(name: "line_item_id", value: "eq.\(session.lineItemId)"),
                    URLQueryItem(name: "select", value: "activation_method,order_number")
                ])
            
            var readinessRequest = URLRequest(url: readinessUrl)
            readinessRequest.httpMethod = "GET"
            readinessRequest.setValue(Config.supabase.anonKey, forHTTPHeaderField: "apikey")
            readinessRequest.setValue("Bearer \(Config.supabase.anonKey)", forHTTPHeaderField: "Authorization")
            
            let (readinessData, _) = try await URLSession.shared.data(for: readinessRequest)
            let readinessInfo = try JSONDecoder().decode([ReadinessData].self, from: readinessData)
            
            if let info = readinessInfo.first {
                activationMethod = info.activationMethod
                orderNumber = info.orderNumber
            }
        } catch {
            devLog("[Product] Could not fetch activation method, continuing without it")
        }
        
        // Generate portal URL for digital accounts
        var portalUrl: String?
        if activationMethod == "digital_account" || activationMethod == "Digital Account" {
            portalUrl = try? await generatePortalURL(
                orderId: session.orderId,
                orderNumber: orderNumber
            )
        }
        
        // Create Product object
        let product = Product(
            id: UUID().uuidString,
            sessionToken: sessionToken,
            productKey: session.licenseKey,
            productKeys: session.licenseKeys ?? (session.licenseKey.map { [$0] }),
            region: session.region ?? "IL",
            productName: session.productName ?? "Microsoft Product",
            productImage: session.productImage,
            productId: session.productId,
            vendor: session.vendor ?? "Microsoft Store",
            status: session.status,
            isBundle: (session.licenseKeys?.count ?? 0) > 1,
            activationMethod: activationMethod,
            orderNumber: orderNumber,
            portalUrl: portalUrl,
            orderId: session.orderId,
            expiresAt: session.expiresAt,
            isTestMode: sessionToken.contains("test")
        )
        
        return product
    }
    
    // MARK: - Generate Portal URL (Matching Chrome Extension)
    private func generatePortalURL(orderId: String, orderNumber: String?) async throws -> String {
        let url = URL(string: "\(Config.supabase.url)/functions/v1/portal-auth")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.supabase.anonKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "action": "create_token_and_redirect",
            "data": [
                "order_id": orderId,
                "order_name": orderNumber ?? "",
                "source": "ios_digital_account",
                "customer_email": "",
                "is_authenticated": false
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let portalUrl = json["portal_url"] as? String else {
            throw ActivationError.portalUrlGenerationFailed
        }
        
        devLog("[Product] Portal URL generated for digital account: \(portalUrl)")
        return portalUrl
    }
    
    // MARK: - Bundle Processing (Matching Chrome Extension)
    private func processBundleActivation(product: Product, token: String) async throws {
        devLog("[API] Bundle detected with \(product.allKeys.count) keys")
        
        await MainActor.run {
            self.activationState = .activatingBundle
            self.activationProgress = 0.6
            self.bundleProgress = BundleProgress(
                total: product.allKeys.count,
                completed: 0,
                succeeded: 0,
                failed: 0
            )
        }
        
        // Initialize bundle state
        bundleState = BundleActivationState(keys: product.allKeys)
        
        var results: [BundleKeyResult] = []
        
        for (index, key) in product.allKeys.enumerated() {
            devLog("[API] Redeeming bundle key \(index + 1)/\(product.allKeys.count)")
            
            // Update progress
            await MainActor.run {
                self.bundleProgress?.currentKey = key
                self.bundleProgress?.currentIndex = index
            }
            
            do {
                try await redeemSingleKey(
                    key: key,
                    token: token,
                    region: product.region,
                    product: product
                )
                
                results.append(BundleKeyResult(success: true, key: key, result: nil))
                bundleState?.recordSuccess(key: key)
                
                await MainActor.run {
                    self.bundleProgress?.succeeded += 1
                    self.bundleProgress?.completed += 1
                    self.activationProgress = 0.6 + (0.3 * Double(index + 1) / Double(product.allKeys.count))
                }
                
            } catch {
                // Special handling for conversion-related errors
                if error.localizedDescription.contains("Game Pass conversion") {
                    devLog("[API] Bundle key \(index + 1) requires Game Pass conversion")
                    
                    // Attempt conversion
                    do {
                        try await handleGamePassConversion(
                            key: key,
                            token: token,
                            region: product.region
                        )
                        results.append(BundleKeyResult(success: true, key: key, result: nil))
                        bundleState?.recordSuccess(key: key)
                    } catch {
                        results.append(BundleKeyResult(success: false, key: key, error: error.localizedDescription))
                        bundleState?.recordFailure(key: key, error: error)
                    }
                } else {
                    devError("[API] Failed to redeem bundle key \(index + 1): \(error)")
                    results.append(BundleKeyResult(success: false, key: key, error: error.localizedDescription))
                    bundleState?.recordFailure(key: key, error: error)
                }
                
                await MainActor.run {
                    self.bundleProgress?.failed += 1
                    self.bundleProgress?.completed += 1
                }
            }
            
            // Wait between redemptions (matching Chrome extension)
            if index < product.allKeys.count - 1 {
                devLog("[API] Waiting 3 seconds before next redemption...")
                try await Task.sleep(nanoseconds: UInt64(Constants.bundleKeyDelay * 1_000_000_000))
            }
        }
        
        // Process final results
        await processBundleResults(results: results)
    }
    
    // MARK: - Token Capture with Retry (Matching Chrome Extension)
    private func captureTokenWithRetry() async throws -> String {
        tokenRetryCount = 0
        
        for attempt in 1...Constants.maxTokenRetries {
            do {
                tokenRetryCount = attempt
                
                // Check cache first (matching Chrome extension)
                if let cached = getTokenFromCache() {
                    devLog("[Token] Using cached token")
                    return cached
                }
                
                devLog("[Token] Capturing new token (attempt \(attempt)/\(Constants.maxTokenRetries))")
                
                let token = try await captureToken()
                
                // Cache the token
                cacheToken(token)
                
                return token
                
            } catch {
                devError("[Token] Capture error on attempt \(attempt): \(error)")
                
                if attempt < Constants.maxTokenRetries {
                    // Exponential backoff
                    let delay = pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    throw ActivationError.tokenCaptureFailed(error.localizedDescription)
                }
            }
        }
        
        throw ActivationError.maxRetriesExceeded
    }

    private func captureToken() async throws -> String {
        guard let webView = hiddenWebView else {
            throw ActivationError.noWebView
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.tokenContinuation = continuation
            
            // Execute token capture script (matching Chrome extension)
            let script = """
            (async function() {
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
                        throw new Error(`Token request failed: ${response.status}`);
                    }
                    
                    const data = await response.json();
                    
                    // Extract token from various response formats
                    if (Array.isArray(data) && data[0]?.token) {
                        return data[0].token;
                    } else if (data?.token) {
                        return data.token;
                    }
                    
                    throw new Error('Token not found in response');
                } catch (error) {
                    throw new Error(`Token capture failed: ${error.message}`);
                }
            })();
            """
            
            webView.evaluateJavaScript(script) { result, error in
                if let token = result as? String {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: error ?? ActivationError.noToken)
                }
            }
            
            // Set timeout
            Task {
                try await Task.sleep(nanoseconds: UInt64(Constants.tokenTimeout * 1_000_000_000))
                if self.tokenContinuation != nil {
                    self.tokenContinuation?.resume(throwing: ActivationError.tokenTimeout)
                    self.tokenContinuation = nil
                }
            }
        }
    }

    // MARK: - Single Key Activation (Matching Chrome Extension)
    private func processSingleKeyActivation(product: Product, token: String) async throws {
        guard let key = product.productKey ?? product.productKeys?.first else {
            throw ActivationError.noKeys
        }
        
        await MainActor.run {
            self.activationState = .activating
            self.activationProgress = 0.7
        }
        
        try await redeemSingleKey(
            key: key,
            token: token,
            region: product.region,
            product: product
        )
        
        await MainActor.run {
            self.activationState = .success(
                productName: product.productName,
                keys: [key]
            )
            self.activationProgress = 1.0
            self.isActivating = false
        }
    }

    // MARK: - Key Redemption (Matching Chrome Extension redeemKey)
    private func redeemSingleKey(
        key: String,
        token: String,
        region: String,
        product: Product
    ) async throws {
        
        let isGlobalKey = ["GLOBAL", "WW", "WORLDWIDE"].contains(region.uppercased())
        
        if isGlobalKey {
            try await redeemGlobalKey(key: key, token: token)
        } else {
            try await redeemRegionalKey(
                key: key,
                token: token,
                region: region,
                product: product
            )
        }
    }

    // MARK: - Global Key Redemption (No Proxy)
    private func redeemGlobalKey(key: String, token: String) async throws {
        devLog("[API] Redeeming GLOBAL key (no proxy needed)")
        
        // Step 1: Validate key
        let validationUrl = URL(string: "https://purchase.mp.microsoft.com/v7.0/tokenDescriptions/\(key)?market=US&language=en-US&supportMultiAvailabilities=true")!
        
        var validateRequest = URLRequest(url: validationUrl)
        validateRequest.setValue("WLID1.0=\"\(token)\"", forHTTPHeaderField: "Authorization")
        validateRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (validateData, validateResponse) = try await URLSession.shared.data(for: validateRequest)
        
        guard let httpValidateResponse = validateResponse as? HTTPURLResponse else {
            throw ActivationError.networkError
        }
        
        switch httpValidateResponse.statusCode {
        case 401: throw ActivationError.authenticationFailed
        case 404: throw ActivationError.invalidKey
        case 400: throw ActivationError.alreadyRedeemed
        case 200: break
        default: throw ActivationError.validationFailed
        }
        
        let validationData = try JSONSerialization.jsonObject(with: validateData) as? [String: Any]
        
        if let tokenState = validationData?["tokenState"] as? String,
           tokenState != "Active" {
            throw ActivationError.keyStateInvalid(tokenState)
        }
        
        // Step 2: Redeem key
        let redeemUrl = URL(string: "https://purchase.mp.microsoft.com/v7.0/users/me/orders")!
        
        var redeemRequest = URLRequest(url: redeemUrl)
        redeemRequest.httpMethod = "POST"
        redeemRequest.setValue("WLID1.0=\"\(token)\"", forHTTPHeaderField: "Authorization")
        redeemRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = createRedemptionPayload(key: key, market: "US")
        redeemRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (redeemData, redeemResponse) = try await URLSession.shared.data(for: redeemRequest)
        
        try await handleRedemptionResponse(
            response: redeemResponse,
            data: redeemData,
            key: key,
            token: token,
            region: "GLOBAL"
        )
        
        devLog("[API] GLOBAL key redemption successful")
    }

    // MARK: - Regional Key Redemption (With Proxy)
    private func redeemRegionalKey(
        key: String,
        token: String,
        region: String,
        product: Product
    ) async throws {
        
        let targetRegion = region.uppercased()
        guard let config = ProxyConfiguration.regions[targetRegion] else {
            throw ActivationError.unsupportedRegion
        }
        
        devLog("[API] Redeeming key in \(targetRegion)")
        
        // Get proxy credentials
        let credentials = try await credentialsManager.getCredentials()
        
        // Enable proxy
        try await enableProxy(region: targetRegion, credentials: credentials)
        
        defer {
            Task {
                await disableProxy()
            }
        }
        
        // Create proxy session
        let proxySession = createProxySession(
            config: config,
            credentials: credentials
        )
        
        // Try regional market first, then fall back to US
        do {
            try await redeemWithMarket(
                key: key,
                token: token,
                market: config.market,
                session: proxySession
            )
        } catch APIError.catalogNotFound {
            devLog("[API] Product not in catalog for \(config.market) region, trying US market catalog")
            
            try await redeemWithMarket(
                key: key,
                token: token,
                market: "US",
                session: proxySession
            )
        } catch APIError.marketMismatch {
            devLog("[API] ActiveMarketMismatch detected, retrying with US market while keeping proxy")
            
            try await redeemWithMarket(
                key: key,
                token: token,
                market: "US",
                session: proxySession
            )
        }
        
        devLog("[API] Redemption successful")
    }

    // MARK: - Market-Specific Redemption
    private func redeemWithMarket(
        key: String,
        token: String,
        market: String,
        session: URLSession
    ) async throws {
        
        // Step 1: Validate
        let validateUrl = URL(string: "https://purchase.mp.microsoft.com/v7.0/tokenDescriptions/\(key)?market=\(market)&language=en-US&supportMultiAvailabilities=true")!
        
        var validateRequest = URLRequest(url: validateUrl)
        validateRequest.setValue("WLID1.0=\"\(token)\"", forHTTPHeaderField: "Authorization")
        validateRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (validateData, validateResponse) = try await session.data(for: validateRequest)
        
        guard let httpValidateResponse = validateResponse as? HTTPURLResponse else {
            throw ActivationError.networkError
        }
        
        // Check validation response
        switch httpValidateResponse.statusCode {
        case 200: break
        case 400:
            if let json = try? JSONSerialization.jsonObject(with: validateData) as? [String: Any],
               let innerError = json["innererror"] as? [String: Any],
               let code = innerError["code"] as? String,
               code == "CatalogSkuDataNotFound" {
                throw APIError.catalogNotFound
            }
            throw ActivationError.validationFailed
        case 401: throw ActivationError.authenticationFailed
        case 404: throw ActivationError.invalidKey
        case 407:
            // Proxy auth required - refresh credentials
            await credentialsManager.clearCache()
            throw ActivationError.proxyAuthenticationFailed
        default: throw ActivationError.validationFailed
        }
        
        let validationData = try JSONSerialization.jsonObject(with: validateData) as? [String: Any]
        
        if let tokenState = validationData?["tokenState"] as? String,
           tokenState != "Active" {
            throw ActivationError.keyStateInvalid(tokenState)
        }
        
        // Step 2: Redeem
        let redeemUrl = URL(string: "https://purchase.mp.microsoft.com/v7.0/users/me/orders")!
        
        var redeemRequest = URLRequest(url: redeemUrl)
        redeemRequest.httpMethod = "POST"
        redeemRequest.setValue("WLID1.0=\"\(token)\"", forHTTPHeaderField: "Authorization")
        redeemRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = createRedemptionPayload(key: key, market: market)
        redeemRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (redeemData, redeemResponse) = try await session.data(for: redeemRequest)
        
        try await handleRedemptionResponse(
            response: redeemResponse,
            data: redeemData,
            key: key,
            token: token,
            region: market
        )
    }

    // MARK: - Handle Redemption Response
    private func handleRedemptionResponse(
        response: URLResponse,
        data: Data,
        key: String,
        token: String,
        region: String
    ) async throws {
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActivationError.networkError
        }
        
        devLog("[API] Redeem response status: \(httpResponse.statusCode)")
        
        switch httpResponse.statusCode {
        case 200, 201:
            // Success
            return
            
        case 412:
            // Conversion consent required
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let innerError = json["innererror"] as? [String: Any],
               let code = innerError["code"] as? String,
               code == "ConversionConsentRequired" {
                
                devLog("[API] Conversion consent required, attempting UI automation flow")
                
                try await handleGamePassConversion(
                    key: key,
                    token: token,
                    region: region
                )
                
                devLog("[API] Game Pass conversion successful via UI automation")
                return
            }
            throw ActivationError.preconditionFailed
            
        case 403:
            // Check specific errors
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let innerError = json["innererror"] as? [String: Any],
                   let code = innerError["code"] as? String,
                   code == "ActiveMarketMismatch" {
                    throw APIError.marketMismatch
                }
                
                if let errorCode = json["errorCode"] as? String,
                   errorCode == "UserAlreadyOwnsContent",
                   let products = json["data"] as? [String] {
                    throw APIError.userAlreadyOwnsContent(products)
                }
            }
            throw ActivationError.forbidden
            
        case 400:
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorCode = json["errorCode"] as? String {
                switch errorCode {
                case "TokenAlreadyRedeemed":
                    throw ActivationError.alreadyRedeemed
                case "InvalidToken":
                    throw ActivationError.invalidKey
                case "UserAlreadyOwnsContent":
                    let products = json["data"] as? [String] ?? []
                    throw APIError.userAlreadyOwnsContent(products)
                default:
                    throw ActivationError.badRequest(errorCode)
                }
            }
            throw ActivationError.badRequest("Unknown")
            
        case 407:
            // Proxy auth failed - refresh and retry
            await credentialsManager.clearCache()
            throw ActivationError.proxyAuthenticationFailed
            
        default:
            throw ActivationError.httpError(httpResponse.statusCode)
        }
    }

    // MARK: - Game Pass Conversion (Matching Chrome Extension)
    private func handleGamePassConversion(
        key: String,
        token: String,
        region: String
    ) async throws {
        
        devLog("[Conversion] Starting Game Pass conversion flow with UI automation")
        
        // Create timeout task
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(Constants.conversionTimeout * 1_000_000_000))
            throw ActivationError.conversionTimeout
        }
        
        defer {
            timeoutTask.cancel()
        }
        
        // Setup conversion webview if needed
        if conversionWebView == nil {
            await setupConversionWebView()
        }
        
        guard let webView = conversionWebView else {
            throw ActivationError.noWebView
        }
        
        // Track conversion state
        var conversionComplete = false
        
        // Inject conversion monitoring script
        await injectConversionMonitor(webView: webView)
        
        // Load redeem page with key
        let redeemUrl = URL(string: "https://account.microsoft.com/billing/redeem")!
        webView.load(URLRequest(url: redeemUrl))
        
        // Wait for page to load
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Execute conversion automation
        let conversionScript = createConversionAutomationScript(key: key)
        
        return try await withCheckedThrowingContinuation { continuation in
            self.conversionContinuation = continuation
            
            webView.evaluateJavaScript(conversionScript) { _, error in
                if let error = error {
                    devError("[Conversion] Script injection error: \(error)")
                }
            }
        }
    }

    // MARK: - Proxy Management (Matching Chrome Extension)
    private func enableProxy(region: String, credentials: ProxyCredentials) async throws {
        let targetRegion = region.uppercased()
        guard let config = ProxyConfiguration.regions[targetRegion] else {
            throw ActivationError.unsupportedRegion
        }
        
        // Skip if already connected to same region
        if activeProxy?.region == targetRegion {
            devLog("[Proxy] Already connected to \(targetRegion)")
            return
        }
        
        devLog("[Proxy] Connecting to \(targetRegion) \(config.host)")
        
        // Clear previous proxy
        if activeProxy != nil {
            await disableProxy()
        }
        
        // Store active configuration
        activeProxy = ActiveProxy(
            region: targetRegion,
            host: config.host,
            port: config.port,
            startTime: Date()
        )
        
        // Setup auth handler
        setupProxyAuthHandler(credentials: credentials)
    }

    private func disableProxy() async {
        guard let proxy = activeProxy else { return }
        
        devLog("[Proxy] Disconnecting")
        
        // Track usage for analytics
        let duration = Date().timeIntervalSince(proxy.startTime)
        trackProxyUsage(region: proxy.region, duration: duration)
        
        activeProxy = nil
        cleanupAuthCache()
    }

    // MARK: - Form Hiding (Matching Chrome Extension)
    private func enableFormHiding() async {
        guard !formHidingEnabled else { return }
        
        devLog("[Form] Activating form hiding")
        
        guard let webView = hiddenWebView else { return }
        
        let script = """
        document.body.setAttribute('data-exon-active', 'true');
        """
        
        await webView.evaluateJavaScript(script) { _, _ in }
        
        formHidingEnabled = true
    }

    private func disableFormHiding() async {
        guard formHidingEnabled else { return }
        
        devLog("[Form] Deactivating form hiding")
        
        guard let webView = hiddenWebView else { return }
        
        let script = """
        document.body.removeAttribute('data-exon-active');
        """
        
        await webView.evaluateJavaScript(script) { _, _ in }
        
        formHidingEnabled = false
    }

    // MARK: - Storage Management (Matching Chrome Extension addProductToStorage)
    private func addProductToStorage(_ product: Product) async {
        do {
            let existingProducts = loadStoredProducts()
            
            // Check if product already exists based on session_token
            if let existingIndex = existingProducts.firstIndex(where: {
                $0.sessionToken == product.sessionToken
            }) {
                // Update existing product
                var updatedProducts = existingProducts
                updatedProducts[existingIndex] = product.withUpdatedTimestamp()
                saveStoredProducts(updatedProducts)
                devLog("[Storage] Updated existing product: \(product.sessionToken ?? "")")
            } else {
                // Add new product
                var newProducts = existingProducts
                newProducts.insert(product.withAddedTimestamp(), at: 0)
                saveStoredProducts(newProducts)
                devLog("[Storage] Added new product: \(product.sessionToken ?? "")")
            }
        } catch {
            devError("[Storage] Failed to add/update product: \(error)")
        }
    }

    private func loadStoredProducts() -> [Product] {
        guard let data = UserDefaults.standard.data(forKey: "products"),
              let products = try? JSONDecoder().decode([Product].self, from: data) else {
            return []
        }
        return products
    }

    private func saveStoredProducts(_ products: [Product]) {
        if let data = try? JSONEncoder().encode(products) {
            UserDefaults.standard.set(data, forKey: "products")
        }
    }

    // MARK: - Helper Methods
    private func isKeyRedeemed(_ status: String?) -> Bool {
        guard let status = status else { return false }
        let redeemedStates = ["Redeemed", "AlreadyRedeemed", "Used", "Invalid", "Consumed", "Duplicate"]
        return redeemedStates.contains { status.lowercased().contains($0.lowercased()) }
    }

    private func isGamePassProduct(_ product: Product) -> Bool {
        if let productId = product.productId {
            return Constants.gamePassProductIds.contains(productId)
        }
        return false
    }

    private func verifyVendorForCurrentPage(_ vendor: String) -> (valid: Bool, expected: String?) {
        // Since this is iOS app, we always accept Microsoft Store/Xbox vendors
        let acceptedVendors = ["Microsoft Store", "Xbox"]
        let valid = acceptedVendors.contains(vendor) || vendor.isEmpty
        return (valid: valid, expected: valid ? nil : "Microsoft Store")
    }

    private func createRedemptionPayload(key: String, market: String) -> [String: Any] {
        return [
            "orderId": UUID().uuidString,
            "orderState": "Purchased",
            "billingInformation": [
                "sessionId": UUID().uuidString,
                "paymentInstrumentType": "Token",
                "paymentInstrumentId": key
            ],
            "friendlyName": nil,
            "clientContext": [
                "client": "AccountMicrosoftCom",
                "deviceId": UIDevice.current.identifierForVendor?.uuidString,
                "deviceType": "iOS",
                "deviceFamily": "mobile",
                "osVersion": UIDevice.current.systemVersion,
                "clientVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            ],
            "language": "en-US",
            "market": market,
            "orderAdditionalMetadata": nil
        ]
    }

    private func createProxySession(config: ProxyConfiguration, credentials: ProxyCredentials) -> URLSession {
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        sessionConfig.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable: true,
            kCFNetworkProxiesHTTPProxy: config.host,
            kCFNetworkProxiesHTTPPort: config.port,
            kCFNetworkProxiesHTTPSEnable: true,
            kCFNetworkProxiesHTTPSProxy: config.host,
            kCFNetworkProxiesHTTPSPort: config.port,
            kCFProxyUsernameKey: credentials.username,
            kCFProxyPasswordKey: credentials.password
        ] as [String: Any]
        
        sessionConfig.timeoutIntervalForRequest = 10
        sessionConfig.timeoutIntervalForResource = 30
        
        return URLSession(configuration: sessionConfig)
    }

    // MARK: - Cache Management
    private func getTokenFromCache() -> String? {
        guard let entry = tokenCache[UIDevice.current.identifierForVendor?.uuidString ?? ""],
              entry.expires > Date() else {
            return nil
        }
        return entry.token
    }

    private func cacheToken(_ token: String) {
        let key = UIDevice.current.identifierForVendor?.uuidString ?? ""
        tokenCache[key] = TokenCacheEntry(
            token: token,
            expires: Date().addingTimeInterval(Constants.tokenCacheDuration)
        )
        
        // Cleanup old entries
        cleanupTokenCache()
    }

    private func cleanupTokenCache() {
        let now = Date()
        tokenCache = tokenCache.filter { $0.value.expires > now }
    }

    private func cleanupAuthCache() {
        let now = Date()
        authCache = authCache.filter { $0.value.expires > now }
    }

    // MARK: - Analytics
    private func trackProxyUsage(region: String, duration: TimeInterval) {
        devLog("[Analytics] Proxy usage: region=\(region), duration=\(duration)s")
    }

    // MARK: - Cleanup
    private func performCleanup() async {
        await disableProxy()
        await disableFormHiding()
        cleanupAuthCache()
        cleanupTokenCache()
        pendingRequests.removeAll()
    }

    // MARK: - State Reset
    private func resetState() async {
        await MainActor.run {
            self.isActivating = false
            self.activationState = .idle
            self.currentProduct = nil
            self.errorMessage = nil
            self.activationProgress = 0.0
            self.bundleProgress = nil
            self.bundleState = nil
            self.formHidingEnabled = false
            
            // Clear retry counts
            self.tokenRetryCount = 0
            self.proxyAuthRetryCount.removeAll()
        }
        
        // Clear continuations
        tokenContinuation?.resume(throwing: ActivationError.cancelled)
        tokenContinuation = nil
        conversionContinuation?.resume(throwing: ActivationError.cancelled)
        conversionContinuation = nil
    }

    // MARK: - Error Handling
    private func handleActivationError(_ error: Error) async {
        devError("[Activation] Error: \(error)")
        
        let errorMessage: String
        
        if let activationError = error as? ActivationError {
            errorMessage = activationError.localizedDescription
        } else if let apiError = error as? APIError {
            errorMessage = apiError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
        
        await MainActor.run {
            self.errorMessage = errorMessage
            self.activationState = .error(errorMessage)
            self.isActivating = false
        }
    }

    // MARK: - Mark As Activated (Matching Chrome Extension)
    private func markAsActivated(sessionToken: String, success: Bool) async throws {
        let url = URL(string: "\(Config.supabase.url)/functions/v1/mark-activated")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.supabase.anonKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "success": success,
            "session_token": sessionToken
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 200 {
            devLog("[Activation] Key successfully marked as activated")
        } else {
            devError("[Activation] Failed to mark key as activated")
        }
    }
    
    // MARK: - WebView Setup Methods
    private func setupWebViews() {
        setupHiddenWebView()
        setupConversionWebView()
    }

    private func setupHiddenWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        
        // Add scripts
        configuration.userContentController.addUserScript(WebViewScripts.createTokenCaptureScript())
        configuration.userContentController.addUserScript(WebViewScripts.createFormHidingScript())
        configuration.userContentController.addUserScript(WebViewScripts.createURLMonitorScript())
        
        // Add message handlers
        configuration.userContentController.add(self, name: "tokenCapture")
        configuration.userContentController.add(self, name: "urlMonitor")
        
        hiddenWebView = WKWebView(frame: .zero, configuration: configuration)
        hiddenWebView?.navigationDelegate = self
        
        // Load Microsoft account page
        let url = URL(string: "https://account.microsoft.com/")!
        hiddenWebView?.load(URLRequest(url: url))
    }

    private func setupConversionWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        
        // Add conversion scripts
        configuration.userContentController.addUserScript(WebViewScripts.createConversionMonitorScript())
        
        // Add message handler
        configuration.userContentController.add(self, name: "conversionHandler")
        
        conversionWebView = WKWebView(frame: .zero, configuration: configuration)
        conversionWebView?.navigationDelegate = self
    }

    private func injectConversionMonitor(webView: WKWebView) async {
        let script = WebViewScripts.createConversionMonitorScript().source
        _ = try? await webView.evaluateJavaScript(script)
    }

    private func setupProxyAuthHandler(credentials: ProxyCredentials) {
        // Implementation handled through URLSession proxy configuration
        // No additional setup needed as proxy auth is handled in createProxySession
    }

    private func setupCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                self.cleanupAuthCache()
                self.cleanupTokenCache()
            }
        }
    }
    
    // MARK: - WKNavigationDelegate
    extension ActivationManager: WKNavigationDelegate {
        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Handle page load completion if needed
        }
        
        nonisolated func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }

    // MARK: - WKScriptMessageHandler
    extension ActivationManager: WKScriptMessageHandler {
        nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            Task { @MainActor in
                switch message.name {
                case "tokenCapture":
                    handleTokenCaptureMessage(message.body)
                    
                case "conversionHandler":
                    handleConversionMessage(message.body)
                    
                case "urlMonitor":
                    handleURLMonitorMessage(message.body)
                    
                default:
                    break
                }
            }
        }
        
        @MainActor
        private func handleTokenCaptureMessage(_ body: Any) {
            guard let dict = body as? [String: Any],
                  let success = dict["success"] as? Bool else {
                return
            }
            
            if success, let token = dict["token"] as? String {
                tokenContinuation?.resume(returning: token)
            } else {
                let error = dict["error"] as? String ?? "Unknown error"
                tokenContinuation?.resume(throwing: ActivationError.tokenCaptureFailed(error))
            }
            tokenContinuation = nil
        }
        
        @MainActor
        private func handleConversionMessage(_ body: Any) {
            guard let dict = body as? [String: Any],
                  let type = dict["type"] as? String else {
                return
            }
            
            switch type {
            case "success":
                conversionContinuation?.resume(returning: true)
                conversionContinuation = nil
                
            case "redeemToken":
                if let success = dict["success"] as? Bool, success {
                    conversionContinuation?.resume(returning: true)
                    conversionContinuation = nil
                }
                
            default:
                break
            }
        }
        
        @MainActor
        private func handleURLMonitorMessage(_ body: Any) {
            guard let dict = body as? [String: Any],
                  let url = dict["url"] as? String,
                  dict["isRedeemPage"] as? Bool == true else {
                return
            }
            
            // Handle URL change if needed
            devLog("[URLMonitor] Redeem page detected: \(url)")
        }
    }
}
