import Foundation
import WebKit
import Combine
import SwiftUI

// MARK: - Main Activation Manager
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
    @Published var diagnosticResults: DiagnosticResults?
    @Published var bundleProgress: BundleProgress?
    
    // MARK: - WebView Components
    private var webView: WKWebView?
    private var hiddenWebView: WKWebView? // For token capture
    private var conversionWebView: WKWebView? // For conversion handling
    
    // MARK: - State Management
    private var microsoftToken: String?
    private var tokenContinuation: CheckedContinuation<String, Error>?
    private var conversionContinuation: CheckedContinuation<Bool, Error>?
    private var pendingActivation: PendingActivation?
    private var bundleState: BundleActivationState?
    private var formHidingEnabled = false
    private var lastProcessedURL: String?
    
    // MARK: - Retry Management
    private var tokenRetryCount = 0
    private var proxyAuthRetryCount: [String: Int] = [:]
    private var keyValidationRetryCount: [String: Int] = [:]
    private var keyRedemptionRetryCount: [String: Int] = [:]
    
    // MARK: - Managers
    private let credentialsManager = CredentialsManager()
    private let apiManager = ApiManager.shared
    private let storageManager = StorageManager.shared
    private let networkManager = NetworkManager.shared
    private let diagnosticsManager = DiagnosticsManager()
    private let urlMonitor = URLMonitor()
    private let externalMessageHandler = ExternalMessageHandler()
    
    // MARK: - Timers and Observers
    private var urlCheckTimer: Timer?
    private var cleanupTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    private struct Constants {
        static let tokenTimeout: TimeInterval = 30
        static let conversionTimeout: TimeInterval = 30
        static let bundleKeyDelay: TimeInterval = 3
        static let maxTokenRetries = 3
        static let maxProxyAuthRetries = 3
        static let maxKeyValidationRetries = 3
        static let maxKeyRedemptionRetries = 2
        static let gamePassProductIds = ["6001208656029", "6001240703133"]
        static let supportWhatsApp = "972557207138"
        static let supportEmail = "help@exongames.co.il"
        static let allowedShopifyDomains = ["exongames.co.il", "exon-israel.myshopify.com"]
        static let microsoftDomains = [
            "account.microsoft.com",
            "login.microsoftonline.com",
            "login.live.com",
            "purchase.mp.microsoft.com"
        ]
        static let authCacheDuration: TimeInterval = 300 // 5 minutes
        static let cleanupInterval: TimeInterval = 60 // 1 minute
    }
    
    // MARK: - Initialization
    override private init() {
        super.init()
        Task { @MainActor in
            setupWebViews()
            setupObservers()
            setupTimers()
            setupExternalMessageHandling()
        }
    }
    
    // MARK: - Main Activation Entry Point
    func startActivation(from source: ActivationSource) async {
        // Reset state
        await resetState()
        
        await MainActor.run {
            self.isActivating = true
            self.activationState = .initializing
            self.errorMessage = nil
            self.activationProgress = 0.0
        }
        
        do {
            // Step 1: Extract activation data based on source
            let activation = try await extractActivationData(from: source)
            self.pendingActivation = activation
            
            // Step 2: Run diagnostics
            await MainActor.run {
                self.activationState = .runningDiagnostics
                self.activationProgress = 0.05
            }
            
            let diagnostics = await runCompleteDiagnostics()
            self.diagnosticResults = diagnostics
            
            // Check diagnostic results
            if !diagnostics.cookiesEnabled {
                throw DiagnosticError.cookiesDisabled
            }
            
            if !diagnostics.loggedIn {
                throw DiagnosticError.notLoggedIn
            }
            
            if !diagnostics.networkAvailable {
                throw DiagnosticError.noNetwork
            }
            
            // Step 3: Process activation
            await processActivationFlow(activation)
            
        } catch {
            await handleActivationError(error)
        }
    }
    
    // MARK: - Activation Flow Processing
    private func processActivationFlow(_ activation: PendingActivation) async throws {
        // Step 1: Fetch/Enrich Product Data
        await MainActor.run {
            self.activationState = .fetchingProduct
            self.activationProgress = 0.1
        }
        
        let product = try await fetchAndEnrichProduct(activation)
        
        await MainActor.run {
            self.currentProduct = product
            self.activationProgress = 0.15
        }
        
        // Store product with deduplication
        await storageManager.saveProduct(product, deduplicate: true)
        
        // Step 2: Check activation method
        if product.activationMethod == "digital_account" {
            await MainActor.run {
                self.activationState = .requiresDigitalAccount
                self.isActivating = false
            }
            return
        }
        
        // Step 3: Vendor Verification
        try verifyVendorCompatibility(product.vendor)
        
        // Step 4: Validate keys
        await MainActor.run {
            self.activationState = .validatingKey
            self.activationProgress = 0.2
        }
        
        guard !product.allKeys.isEmpty else {
            throw ActivationError.noKeys
        }
        
        // Check if keys are already redeemed
        if let status = product.status, isKeyRedeemed(status) {
            await MainActor.run {
                self.activationState = .alreadyRedeemed
                self.isActivating = false
            }
            return
        }
        
        // Step 5: Game Pass specific checks
        if isGamePassProduct(product) {
            try await performGamePassValidation(product)
        }
        
        // Step 6: Capture Microsoft Token
        await MainActor.run {
            self.activationState = .capturingToken
            self.activationProgress = 0.5
        }
        
        let token = try await captureMicrosoftTokenWithRetry()
        self.microsoftToken = token
        
        // Step 7: Enable form hiding
        if !activation.isTestMode {
            await enableFormHiding()
        }
        
        // Step 8: Process keys (single or bundle)
        if product.isBundle {
            try await processBundleActivation(product: product, token: token)
        } else {
            try await processSingleKeyActivation(product: product, token: token)
        }
        
        // Step 9: Mark as activated in database
        if let sessionToken = activation.sessionToken {
            try await markAsActivated(sessionToken: sessionToken)
        }
        
        // Step 10: Cleanup
        await performCleanup()
    }
    
    // MARK: - Bundle Activation with State Tracking
    private func processBundleActivation(product: Product, token: String) async throws {
        await MainActor.run {
            self.activationState = .activatingBundle
            self.activationProgress = 0.6
        }
        
        // Initialize bundle state
        let bundleState = BundleActivationState(keys: product.allKeys)
        self.bundleState = bundleState
        
        // Update UI with bundle progress
        await MainActor.run {
            self.bundleProgress = BundleProgress(
                total: product.allKeys.count,
                completed: 0,
                succeeded: 0,
                failed: 0
            )
        }
        
        // Process each key with state tracking
        for (index, key) in product.allKeys.enumerated() {
            // Check if key was already processed successfully
            if bundleState.isKeySuccessful(key) {
                continue
            }
            
            // Update progress
            await MainActor.run {
                self.bundleProgress?.currentKey = key
                self.bundleProgress?.currentIndex = index
            }
            
            // Update key state
            bundleState.updateKeyState(key, state: .validating)
            
            do {
                // Validate key first
                let validationResult = try await validateKeyWithRetry(
                    key: key,
                    token: token,
                    region: product.region
                )
                
                if !validationResult.isValid {
                    throw ActivationError.invalidKey
                }
                
                if validationResult.isAlreadyRedeemed {
                    bundleState.updateKeyState(key, state: .alreadyRedeemed)
                    bundleState.recordFailure(
                        key: key,
                        error: ActivationError.alreadyRedeemed,
                        isRecoverable: false
                    )
                    continue
                }
                
                // Update state to redeeming
                bundleState.updateKeyState(key, state: .redeeming)
                
                // Attempt redemption
                try await redeemKeyWithRetry(
                    key: key,
                    token: token,
                    region: product.region,
                    product: product
                )
                
                // Mark as successful
                bundleState.updateKeyState(key, state: .succeeded)
                bundleState.recordSuccess(key: key)
                
                // Update progress
                await MainActor.run {
                    self.bundleProgress?.succeeded += 1
                    self.bundleProgress?.completed += 1
                    self.activationProgress = 0.6 + (0.3 * Double(index + 1) / Double(product.allKeys.count))
                }
                
            } catch {
                // Handle specific errors
                let errorInfo = analyzeActivationError(error, key: key)
                
                // Update state based on error
                if errorInfo.isAlreadyOwned {
                    bundleState.updateKeyState(
                        key,
                        state: .alreadyOwned(products: errorInfo.ownedProducts)
                    )
                } else if errorInfo.isAlreadyRedeemed {
                    bundleState.updateKeyState(key, state: .alreadyRedeemed)
                } else if errorInfo.requiresConversion {
                    bundleState.updateKeyState(key, state: .conversionRequired)
                    
                    // Handle conversion
                    do {
                        try await handleGamePassConversion(
                            key: key,
                            token: token,
                            region: product.region
                        )
                        bundleState.updateKeyState(key, state: .succeeded)
                        bundleState.recordSuccess(key: key)
                    } catch {
                        bundleState.updateKeyState(key, state: .failed(reason: error.localizedDescription))
                        bundleState.recordFailure(key: key, error: error, isRecoverable: false)
                    }
                } else {
                    bundleState.updateKeyState(
                        key,
                        state: .failed(reason: errorInfo.message)
                    )
                    bundleState.recordFailure(
                        key: key,
                        error: error,
                        isRecoverable: errorInfo.isRecoverable
                    )
                }
                
                // Update progress
                await MainActor.run {
                    self.bundleProgress?.failed += 1
                    self.bundleProgress?.completed += 1
                }
            }
            
            // Add delay between keys (except for last one)
            if index < product.allKeys.count - 1 {
                let delay = calculateBundleKeyDelay(
                    index: index,
                    hasFailures: bundleState.hasFailures()
                )
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // Process final bundle results
        await processBundleResults(bundleState: bundleState, product: product)
    }
    
    // MARK: - Single Key Activation
    private func processSingleKeyActivation(product: Product, token: String) async throws {
        await MainActor.run {
            self.activationState = .activating
            self.activationProgress = 0.7
        }
        
        guard let key = product.productKey ?? product.productKeys?.first else {
            throw ActivationError.noKeys
        }
        
        // Validate key
        let validationResult = try await validateKeyWithRetry(
            key: key,
            token: token,
            region: product.region
        )
        
        if !validationResult.isValid {
            throw ActivationError.invalidKey
        }
        
        if validationResult.isAlreadyRedeemed {
            await MainActor.run {
                self.activationState = .alreadyRedeemed
                self.isActivating = false
            }
            return
        }
        
        // Attempt redemption
        do {
            try await redeemKeyWithRetry(
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
            
        } catch APIError.conversionConsentRequired {
            // Handle conversion
            await MainActor.run {
                self.activationState = .handlingConversion
            }
            
            try await handleGamePassConversion(
                key: key,
                token: token,
                region: product.region
            )
            
            await MainActor.run {
                self.activationState = .success(
                    productName: product.productName,
                    keys: [key]
                )
                self.activationProgress = 1.0
                self.isActivating = false
            }
            
        } catch APIError.userAlreadyOwnsContent(let products) {
            await MainActor.run {
                self.activationState = .alreadyOwned(products: products)
                self.isActivating = false
            }
        }
    }
    
    // MARK: - Key Validation with Retry
    private func validateKeyWithRetry(
        key: String,
        token: String,
        region: String
    ) async throws -> KeyValidationResult {
        
        let retryCount = keyValidationRetryCount[key] ?? 0
        
        if retryCount >= Constants.maxKeyValidationRetries {
            throw ActivationError.maxRetriesExceeded
        }
        
        keyValidationRetryCount[key] = retryCount + 1
        
        return try await networkManager.executeWithExponentialBackoff(
            maxAttempts: Constants.maxKeyValidationRetries - retryCount,
            initialDelay: 1.0,
            maxDelay: 8.0,
            jitter: true
        ) {
            if region == "GLOBAL" || region == "WW" || region == "WORLDWIDE" {
                return try await self.validateGlobalKey(key: key, token: token)
            } else {
                return try await self.validateRegionalKey(
                    key: key,
                    token: token,
                    region: region
                )
            }
        }
    }
    
    // MARK: - Key Redemption with Retry
    private func redeemKeyWithRetry(
        key: String,
        token: String,
        region: String,
        product: Product
    ) async throws {
        
        let retryCount = keyRedemptionRetryCount[key] ?? 0
        
        if retryCount >= Constants.maxKeyRedemptionRetries {
            throw ActivationError.maxRetriesExceeded
        }
        
        keyRedemptionRetryCount[key] = retryCount + 1
        
        try await networkManager.executeWithExponentialBackoff(
            maxAttempts: Constants.maxKeyRedemptionRetries - retryCount,
            initialDelay: 1.0,
            maxDelay: 4.0,
            jitter: true
        ) {
            if region == "GLOBAL" || region == "WW" || region == "WORLDWIDE" {
                try await self.redeemGlobalKey(
                    key: key,
                    token: token,
                    productId: product.productId
                )
            } else {
                try await self.redeemRegionalKey(
                    key: key,
                    token: token,
                    region: region,
                    productId: product.productId
                )
            }
        }
    }
    
    // MARK: - Regional Key Validation
    private func validateRegionalKey(
        key: String,
        token: String,
        region: String
    ) async throws -> KeyValidationResult {
        
        // Get proxy configuration
        guard let proxyConfig = ProxyConfiguration.getConfig(for: region) else {
            throw ActivationError.unsupportedRegion
        }
        
        // Get fresh credentials
        let credentials = try await credentialsManager.getCredentials()
        
        // Create proxy session
        let session = try await createProxySession(
            config: proxyConfig,
            credentials: credentials
        )
        
        defer { session.finishTasksAndInvalidate() }
        
        // Try primary market first
        var result = try? await validateKeyInMarket(
            key: key,
            token: token,
            market: proxyConfig.market,
            session: session
        )
        
        // If catalog not found, try US market
        if result == nil || result?.catalogError == true {
            result = try await validateKeyInMarket(
                key: key,
                token: token,
                market: "US",
                session: session
            )
        }
        
        guard let validationResult = result else {
            throw ActivationError.validationFailed
        }
        
        return validationResult
    }
    
    // MARK: - Global Key Validation
    private func validateGlobalKey(
        key: String,
        token: String
    ) async throws -> KeyValidationResult {
        
        return try await validateKeyInMarket(
            key: key,
            token: token,
            market: "US",
            session: URLSession.shared
        )
    }
    
    // MARK: - Market-specific Validation
    private func validateKeyInMarket(
        key: String,
        token: String,
        market: String,
        session: URLSession
    ) async throws -> KeyValidationResult {
        
        let url = URL(string: "https://purchase.mp.microsoft.com/v7.0/tokenDescriptions/\(key)?market=\(market)&language=en-US&supportMultiAvailabilities=true")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("WLID1.0=\"\(token)\"", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActivationError.networkError
        }
        
        switch httpResponse.statusCode {
        case 200:
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let tokenState = json?["tokenState"] as? String ?? "Unknown"
            
            return KeyValidationResult(
                isValid: tokenState == "Active",
                isAlreadyRedeemed: tokenState == "Redeemed" || tokenState == "AlreadyRedeemed",
                tokenState: tokenState,
                productInfo: json,
                catalogError: false
            )
            
        case 400:
            // Check for catalog error
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let innerError = json["innererror"] as? [String: Any],
               let code = innerError["code"] as? String,
               code == "CatalogSkuDataNotFound" {
                return KeyValidationResult(
                    isValid: false,
                    isAlreadyRedeemed: false,
                    tokenState: "CatalogError",
                    productInfo: nil,
                    catalogError: true
                )
            }
            throw ActivationError.validationFailed
            
        case 401:
            throw ActivationError.authenticationFailed
            
        case 404:
            throw ActivationError.invalidKey
            
        case 407:
            // Proxy auth required - refresh credentials
            throw ActivationError.proxyAuthenticationFailed
            
        default:
            throw ActivationError.validationFailed
        }
    }
    
    // MARK: - Regional Key Redemption
    private func redeemRegionalKey(
        key: String,
        token: String,
        region: String,
        productId: String?
    ) async throws {
        
        // Get proxy configuration
        guard let proxyConfig = ProxyConfiguration.getConfig(for: region) else {
            throw ActivationError.unsupportedRegion
        }
        
        // Get fresh credentials
        let credentials = try await credentialsManager.getCredentials()
        
        // Create proxy session
        let session = try await createProxySession(
            config: proxyConfig,
            credentials: credentials
        )
        
        defer { session.finishTasksAndInvalidate() }
        
        // Try primary market first
        do {
            try await redeemKeyInMarket(
                key: key,
                token: token,
                market: proxyConfig.market,
                session: session,
                productId: productId
            )
        } catch APIError.marketMismatch {
            // Retry with US market
            try await redeemKeyInMarket(
                key: key,
                token: token,
                market: "US",
                session: session,
                productId: productId
            )
        }
    }
    
    // MARK: - Global Key Redemption
    private func redeemGlobalKey(
        key: String,
        token: String,
        productId: String?
    ) async throws {
        
        try await redeemKeyInMarket(
            key: key,
            token: token,
            market: "US",
            session: URLSession.shared,
            productId: productId
        )
    }
    
    // MARK: - Market-specific Redemption
    private func redeemKeyInMarket(
        key: String,
        token: String,
        market: String,
        session: URLSession,
        productId: String?
    ) async throws {
        
        let url = URL(string: "https://purchase.mp.microsoft.com/v7.0/users/me/orders")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("WLID1.0=\"\(token)\"", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        
        let payload: [String: Any] = [
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
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActivationError.networkError
        }
        
        try handleRedemptionResponse(
            statusCode: httpResponse.statusCode,
            data: data
        )
    }
    
    // MARK: - Handle Redemption Response
    private func handleRedemptionResponse(
        statusCode: Int,
        data: Data
    ) throws {
        
        switch statusCode {
        case 200, 201:
            // Success
            return
            
        case 412:
            // Precondition Failed - Check for conversion
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let innerError = json["innererror"] as? [String: Any],
               let code = innerError["code"] as? String,
               code == "ConversionConsentRequired" {
                throw APIError.conversionConsentRequired
            }
            throw ActivationError.activationFailed
            
        case 403:
            // Forbidden - Check specific errors
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Check for market mismatch
                if let innerError = json["innererror"] as? [String: Any],
                   let code = innerError["code"] as? String,
                   code == "ActiveMarketMismatch" {
                    throw APIError.marketMismatch
                }
                
                // Check for already owned
                if let errorCode = json["errorCode"] as? String,
                   errorCode == "UserAlreadyOwnsContent" {
                    var ownedProducts: [String] = []
                    if let products = json["data"] as? [String] {
                        ownedProducts = products
                    }
                    throw APIError.userAlreadyOwnsContent(ownedProducts)
                }
                
                // Region restriction
                if let errorCode = json["errorCode"] as? String,
                   errorCode == "RegionRestricted" {
                    throw ActivationError.regionRestricted
                }
            }
            throw ActivationError.forbidden
            
        case 409:
            // Conflict - Already redeemed
            throw ActivationError.alreadyRedeemed
            
        case 400:
            // Bad Request
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let errorCode = json["errorCode"] as? String {
                    switch errorCode {
                    case "TokenAlreadyRedeemed":
                        throw ActivationError.alreadyRedeemed
                    case "InvalidToken":
                        throw ActivationError.invalidKey
                    case "InvalidMarket":
                        throw APIError.marketMismatch
                    default:
                        throw ActivationError.badRequest(errorCode)
                    }
                }
            }
            throw ActivationError.badRequest("Unknown")
            
        case 401:
            // Unauthorized
            throw ActivationError.authenticationFailed
            
        case 407:
            // Proxy Authentication Required
            throw ActivationError.proxyAuthenticationFailed
            
        case 500, 502, 503, 504:
            // Server errors
            throw APIError.serverError(statusCode)
            
        default:
            throw ActivationError.httpError(statusCode)
        }
    }
    
    // MARK: - Game Pass Conversion Handler
    private func handleGamePassConversion(
        key: String,
        token: String,
        region: String
    ) async throws {
        
        await MainActor.run {
            self.activationState = .handlingConversion
        }
        
        // Create conversion webview if needed
        if conversionWebView == nil {
            await setupConversionWebView()
        }
        
        guard let webView = conversionWebView else {
            throw ActivationError.conversionFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.conversionContinuation = continuation
            
            // Inject conversion automation script
            let script = createConversionAutomationScript(key: key)
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("[Conversion] Script injection error: \(error)")
                }
            }
            
            // Load redemption page
            let url = URL(string: "https://account.microsoft.com/billing/redeem")!
            webView.load(URLRequest(url: url))
            
            // Set timeout
            Task {
                try await Task.sleep(nanoseconds: UInt64(Constants.conversionTimeout * 1_000_000_000))
                if self.conversionContinuation != nil {
                    self.conversionContinuation?.resume(throwing: ActivationError.conversionTimeout)
                    self.conversionContinuation = nil
                }
            }
        }
    }
    
    // MARK: - Token Capture with Retry
    private func captureMicrosoftTokenWithRetry() async throws -> String {
        tokenRetryCount = 0
        
        return try await networkManager.executeWithExponentialBackoff(
            maxAttempts: Constants.maxTokenRetries,
            initialDelay: 1.0,
            maxDelay: 4.0,
            jitter: false
        ) {
            self.tokenRetryCount += 1
            return try await self.captureMicrosoftToken()
        }
    }
    
    // MARK: - Token Capture Implementation
    private func captureMicrosoftToken() async throws -> String {
        guard let webView = hiddenWebView else {
            throw ActivationError.noWebView
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.tokenContinuation = continuation
            
            // Check if already on Microsoft account page
            if let currentURL = webView.url,
               Constants.microsoftDomains.contains(where: { currentURL.host?.contains($0) ?? false }) {
                // Try immediate capture
                webView.evaluateJavaScript("window.ExonTokenCapture.captureToken()") { _, error in
                    if let error = error {
                        print("[Token] Immediate capture error: \(error)")
                        // Load page if capture fails
                        let url = URL(string: "https://account.microsoft.com/")!
                        webView.load(URLRequest(url: url))
                    }
                }
            } else {
                // Load Microsoft account page
                let url = URL(string: "https://account.microsoft.com/")!
                webView.load(URLRequest(url: url))
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
    
    // MARK: - Proxy Session Creation
    private func createProxySession(
        config: ProxyConfiguration,
        credentials: ProxyCredentials
    ) async throws -> URLSession {
        
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        // Set proxy
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
        
        // Set timeouts
        sessionConfig.timeoutIntervalForRequest = 10
        sessionConfig.timeoutIntervalForResource = 30
        
        // Create delegate for auth challenges
        let delegate = ProxyAuthenticationDelegate(
            credentials: credentials,
            maxRetries: Constants.maxProxyAuthRetries
        )
        
        return URLSession(
            configuration: sessionConfig,
            delegate: delegate,
            delegateQueue: nil
        )
    }
    
    // MARK: - Helper Methods
    private func isKeyRedeemed(_ status: String) -> Bool {
        let redeemedStates = ["Redeemed", "AlreadyRedeemed", "Used", "Invalid", "Consumed", "Duplicate"]
        return redeemedStates.contains(where: { status.lowercased().contains($0.lowercased()) })
    }
    
    private func isGamePassProduct(_ product: Product) -> Bool {
        if let productId = product.productId {
            return Constants.gamePassProductIds.contains(productId)
        }
        return product.isGamePass == true
    }
    
    private func calculateBundleKeyDelay(index: Int, hasFailures: Bool) -> TimeInterval {
        // Base delay
        var delay = Constants.bundleKeyDelay
        
        // Increase delay if there are failures
        if hasFailures {
            delay += 2.0
        }
        
        // Add jitter
        let jitter = Double.random(in: -0.5...0.5)
        delay += jitter
        
        return max(delay, 1.0)
    }
    
    // MARK: - Reset State
    private func resetState() async {
        await MainActor.run {
            self.isActivating = false
            self.activationState = .idle
            self.currentProduct = nil
            self.errorMessage = nil
            self.activationProgress = 0.0
            self.bundleProgress = nil
            self.bundleState = nil
            self.pendingActivation = nil
            self.formHidingEnabled = false
            
            // Clear retry counts
            self.tokenRetryCount = 0
            self.proxyAuthRetryCount.removeAll()
            self.keyValidationRetryCount.removeAll()
            self.keyRedemptionRetryCount.removeAll()
        }
        
        // Clear continuations
        tokenContinuation?.resume(throwing: ActivationError.cancelled)
        tokenContinuation = nil
        conversionContinuation?.resume(throwing: ActivationError.cancelled)
        conversionContinuation = nil
    }
}

// MARK: - Bundle State Management
final class BundleActivationState {
    
    struct KeyState {
        let key: String
        var status: KeyStatus
        var attempts: Int = 0
        var lastError: Error?
        var lastAttemptTime: Date?
        var marketsAttempted: [String] = []
        
        enum KeyStatus: Equatable {
            case pending
            case validating
            case redeeming
            case conversionRequired
            case succeeded
            case failed(reason: String)
            case alreadyOwned(products: [String])
            case alreadyRedeemed
        }
    }
    
    private var keyStates: [String: KeyState] = [:]
    private var successfulKeys: Set<String> = []
    private var failedKeys: Set<String> = []
    private var recoverableFailures: Set<String> = []
    
    init(keys: [String]) {
        for key in keys {
            keyStates[key] = KeyState(key: key, status: .pending)
        }
    }
    
    func updateKeyState(_ key: String, state: KeyState.KeyStatus) {
        keyStates[key]?.status = state
        keyStates[key]?.lastAttemptTime = Date()
    }
    
    func recordSuccess(key: String) {
        successfulKeys.insert(key)
        failedKeys.remove(key)
        recoverableFailures.remove(key)
    }
    
    func recordFailure(key: String, error: Error, isRecoverable: Bool) {
        failedKeys.insert(key)
        if isRecoverable {
            recoverableFailures.insert(key)
        }
        keyStates[key]?.lastError = error
        keyStates[key]?.attempts += 1
    }
    
    func isKeySuccessful(_ key: String) -> Bool {
        return successfulKeys.contains(key)
    }
    
    func hasFailures() -> Bool {
        return !failedKeys.isEmpty
    }
    
    func getRecoverableFailures() -> [String] {
        return Array(recoverableFailures)
    }
    
    func getAllResults() -> BundleResults {
        var succeeded: [String] = []
        var failed: [(key: String, status: KeyState.KeyStatus, error: Error?)] = []
        
        for (key, state) in keyStates {
            switch state.status {
            case .succeeded:
                succeeded.append(key)
            case .failed, .alreadyOwned, .alreadyRedeemed:
                failed.append((key, state.status, state.lastError))
            default:
                break
            }
        }
        
        return BundleResults(succeeded: succeeded, failed: failed)
    }
    
    struct BundleResults {
        let succeeded: [String]
        let failed: [(key: String, status: KeyState.KeyStatus, error: Error?)]
    }
}
