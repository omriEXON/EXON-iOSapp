// ActivationManager.swift - Production-Ready Implementation
// Matching Chrome Extension background.js functionality
// ==========================================================

import Foundation
import WebKit
import Combine
import UIKit

// MARK: - Activation State Enum
enum ActivationState: Equatable {
    case idle
    case initializing
    case fetchingProduct
    case validatingKey
    case checkingGamePass
    case capturingToken
    case activating
    case activatingBundle
    case handlingConversion
    case success(productName: String, keys: [String])
    case partialSuccess(succeeded: Int, total: Int, failed: [(key: String, error: String)])
    case error(String)
    case alreadyOwned(products: [String])
    case alreadyRedeemed
    case regionMismatch(accountRegion: String, keyRegion: String)
    case activeSubscription(subscription: ActiveSubscription)
    case expiredSession
    case requiresDigitalAccount
}

// MARK: - Error Types
enum ActivationError: LocalizedError {
    case noWebView
    case noToken
    case tokenTimeout
    case tokenCaptureFailed(String)
    case maxRetriesExceeded
    case cancelled
    case invalidSession
    case sessionNotFound
    case sessionExpired
    case networkError
    case authenticationFailed
    case invalidKey
    case alreadyRedeemed
    case keyStateInvalid(String)
    case validationFailed
    case preconditionFailed
    case forbidden
    case badRequest(String)
    case httpError(Int)
    case proxyAuthenticationFailed
    case proxyCredentialsFailed
    case unsupportedRegion
    case conversionTimeout
    case noKeys
    case vendorMismatch(expected: String, actual: String)
    case portalUrlGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .noWebView: return "WebView not initialized"
        case .noToken: return "Failed to capture authentication token"
        case .tokenTimeout: return "Token capture timed out"
        case .tokenCaptureFailed(let msg): return "Token capture failed: \(msg)"
        case .maxRetriesExceeded: return "Maximum retry attempts exceeded"
        case .cancelled: return "Operation cancelled"
        case .invalidSession: return "Invalid session token"
        case .sessionNotFound: return "Session not found"
        case .sessionExpired: return "Session has expired"
        case .networkError: return "Network error occurred"
        case .authenticationFailed: return "Authentication failed"
        case .invalidKey: return "Invalid license key"
        case .alreadyRedeemed: return "Key has already been redeemed"
        case .keyStateInvalid(let state): return "Key is \(state) - cannot redeem"
        case .validationFailed: return "Key validation failed"
        case .preconditionFailed: return "Precondition failed"
        case .forbidden: return "Access forbidden"
        case .badRequest(let code): return "Bad request: \(code)"
        case .httpError(let code): return "HTTP error \(code)"
        case .proxyAuthenticationFailed: return "Proxy authentication failed"
        case .proxyCredentialsFailed: return "Failed to fetch proxy credentials"
        case .unsupportedRegion: return "Unsupported region"
        case .conversionTimeout: return "Game Pass conversion timed out"
        case .noKeys: return "No license keys found"
        case .vendorMismatch(let exp, let act): return "Vendor mismatch: expected \(exp), got \(act)"
        case .portalUrlGenerationFailed: return "Failed to generate portal URL"
        }
    }
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case catalogNotFound
    case marketMismatch
    case userAlreadyOwnsContent([String])
    
    var errorDescription: String? {
        switch self {
        case .catalogNotFound: return "Product not found in catalog"
        case .marketMismatch: return "Market mismatch"
        case .userAlreadyOwnsContent(let products): return "User already owns: \(products.joined(separator: ", "))"
        }
    }
}

// MARK: - Data Models
struct Product: Codable {
    let id: String = UUID().uuidString
    var sessionToken: String?
    let productKey: String?
    let productKeys: [String]?
    let region: String
    let productName: String
    let productImage: String?
    let productId: String?
    let vendor: String?
    let status: String?
    let isBundle: Bool
    let activationMethod: String?
    let orderNumber: String?
    var portalUrl: String?
    let orderId: String?
    let expiresAt: Date?
    let isTestMode: Bool
    var addedAt: Date?
    var updatedAt: Date?
    
    var allKeys: [String] {
        if let keys = productKeys, !keys.isEmpty {
            return keys
        } else if let key = productKey {
            return [key]
        }
        return []
    }
    
    var isGamePass: Bool {
        guard let productId = productId else { return false }
        return ["CFQ7TTC0K5DJ", "CFQ7TTC0KHS0"].contains(productId)
    }
}

struct ActiveSubscription {
    let name: String
    let productId: String
    let endDate: String?
    let daysRemaining: Int?
    let hasPaymentIssue: Bool
    let autorenews: Bool
}

struct BundleProgress {
    let total: Int
    var completed: Int
    var succeeded: Int
    var failed: Int
    var currentKey: String?
    var currentIndex: Int?
}

struct BundleKeyResult {
    let success: Bool
    let key: String
    let result: Any?
    let error: String?
}

struct BundleActivationState {
    var keyStates: [String: KeyState] = [:]  // Make this accessible
    
    struct KeyState {
        var attempts: Int = 0
        var lastError: Error?
        var success: Bool = false
    }
    
    init(keys: [String]) {
        for key in keys {
            keyStates[key] = KeyState()
        }
    }
    
    mutating func recordSuccess(key: String) {
        keyStates[key]?.success = true
    }
    
    mutating func recordFailure(key: String, error: Error) {
        keyStates[key]?.lastError = error
        keyStates[key]?.attempts += 1
    }
    
    func isSuccessful(key: String) -> Bool {
        return keyStates[key]?.success ?? false
    }
}

// MARK: - Session & Proxy Models
struct SessionData: Codable {
    let sessionToken: String
    let orderId: String
    let lineItemId: String
    let licenseKey: String?
    let licenseKeys: [String]?
    let region: String?
    let productName: String?
    let productId: String?
    let productImage: String?
    let vendor: String?
    let status: String?
    let expiresAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case sessionToken = "session_token"
        case orderId = "order_id"
        case lineItemId = "line_item_id"
        case licenseKey = "license_key"
        case licenseKeys = "license_keys"
        case region, vendor, status
        case productName = "product_name"
        case productId = "product_id"
        case productImage = "product_image"
        case expiresAt = "expires_at"
    }
}

struct ReadinessData: Codable {
    let activationMethod: String?
    let orderNumber: String?
    
    enum CodingKeys: String, CodingKey {
        case activationMethod = "activation_method"
        case orderNumber = "order_number"
    }
}

struct ProxyCredentials {
    let username: String
    let password: String
    let expiresAt: Date
}

// MARK: - Credentials Manager (Matching Chrome Extension CredentialsManager)
final class CredentialsManager {
    static let shared = CredentialsManager()
    
    private var credentials: ProxyCredentials?
    private var credentialsExpiry: Date?
    private var cacheDuration: TimeInterval = 3600 // 1 hour cache
    private var fetchingPromise: Task<ProxyCredentials, Error>?
    
    private init() {}
    
    func getCredentials() async throws -> ProxyCredentials {
        // Check if we have valid cached credentials
        if let creds = credentials,
           let expiry = credentialsExpiry,
           Date() < expiry {
            devLog("[Credentials] Using cached proxy credentials")
            return creds
        }
        
        // If already fetching, wait for that promise
        if let promise = fetchingPromise {
            devLog("[Credentials] Waiting for existing fetch...")
            return try await promise.value
        }
        
        // Start new fetch
        fetchingPromise = Task {
            try await fetchProxyCredentials()
        }
        
        do {
            let creds = try await fetchingPromise!.value
            return creds
        } finally {
            fetchingPromise = nil
        }
    }
    
    private func fetchProxyCredentials() async throws -> ProxyCredentials {
        devLog("[Credentials] Fetching proxy credentials from Edge Function")
        
        let url = URL(string: "\(Config.supabase.url)/functions/v1/get-proxy-creds")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.supabase.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["session_token": "ios_request"]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            devError("[Credentials] Edge Function returned: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw ActivationError.proxyCredentialsFailed
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let user = json["user"] as? String,
              let password = json["password"] as? String else {
            throw ActivationError.proxyCredentialsFailed
        }
        
        // Use the expires_at from Edge Function if available
        let expiresAt: Date
        if let expiresAtString = json["expires_at"] as? String,
           let date = ISO8601DateFormatter().date(from: expiresAtString) {
            expiresAt = date
            devLog("[Credentials] Credentials expire at: \(expiresAtString)")
        } else {
            expiresAt = Date().addingTimeInterval(cacheDuration)
        }
        
        // Cache the credentials
        let credentials = ProxyCredentials(
            username: user,
            password: password,
            expiresAt: expiresAt
        )
        
        self.credentials = credentials
        self.credentialsExpiry = expiresAt
        
        devLog("[Credentials] Proxy credentials fetched from Edge Function and cached")
        return credentials
    }
    
    func clearCache() {
        credentials = nil
        credentialsExpiry = nil
        fetchingPromise = nil
        devLog("[Credentials] Cache cleared")
    }
}

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
    @Published var bundleProgress: BundleProgress?
    
    // MARK: - WebView Management
    private var hiddenWebView: WKWebView?
    private var conversionWebView: WKWebView?
    private var formHidingEnabled = false
    
    // MARK: - State Management (Matching Chrome Extension)
    private var microsoftToken: String?
    private var tokenContinuation: CheckedContinuation<String, Error>?
    private var conversionContinuation: CheckedContinuation<Bool, Error>?
    private var pendingActivation: [String: Any]?
    
    // MARK: - Auth & Proxy Management (Matching Chrome Extension)
    private var activeProxy: ActiveProxy?
    private var authCache: [String: AuthCacheEntry] = [:]
    private var pendingRequests: [String: Int] = [:]
    private var tokenCache: [String: TokenCacheEntry] = [:]
    
    // MARK: - Bundle State
    private var bundleState: BundleActivationState?
    
    // MARK: - Retry Management
    private var tokenRetryCount = 0
    private var proxyAuthRetryCount: [String: Int] = [:]
    
    // MARK: - Managers
    private let credentialsManager = CredentialsManager.shared
    private var cleanupTimer: Timer?
    private var lastCleanup = Date()
    
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
        }
    }
    
    // MARK: - Main Activation Entry Point (Matching Chrome Extension EXECUTE_AUTO_REDEEM)
    func startActivation(sessionToken: String) async {
        await resetState()
        
        isActivating = true
        activationState = .initializing
        errorMessage = nil
        activationProgress = 0.0
        
        do {
            // Step 1: Get product from session (matching Chrome getProductBySessionToken)
            let product = try await getProductBySessionToken(sessionToken)
            
            currentProduct = product
            activationProgress = 0.05
            
            // Check for digital account activation method
            if product.activationMethod == "digital_account" ||
               product.activationMethod == "Digital Account" {
                
                // Generate portal URL if needed
                if product.portalUrl == nil {
                    let portalUrl = try await generatePortalURL(
                        orderId: product.orderId ?? "",
                        orderNumber: product.orderNumber
                    )
                    currentProduct?.portalUrl = portalUrl
                }
                
                activationState = .requiresDigitalAccount
                isActivating = false
                return
            }
            
            // Store product without duplicates
            await addProductToStorage(product)
            
            // Check if session expired
            if let expiresAt = product.expiresAt, expiresAt < Date() {
                activationState = .expiredSession
                isActivating = false
                throw ActivationError.sessionExpired
            }
            
            // Check vendor
            let vendorCheck = verifyVendorForCurrentPage(product.vendor ?? "Microsoft Store")
            if !vendorCheck.valid {
                throw ActivationError.vendorMismatch(
                    expected: vendorCheck.expected ?? "Microsoft Store",
                    actual: product.vendor ?? "Unknown"
                )
            }
            
            // Check if already redeemed
            if isKeyRedeemed(product.status) {
                activationState = .alreadyRedeemed
                isActivating = false
                return
            }
            
            // Check for Game Pass products
            if isGamePassProduct(product) {
                try await performGamePassChecks(product)
            }
            
            // Capture Microsoft Token
            activationState = .capturingToken
            activationProgress = 0.3
            
            let token = try await captureTokenWithRetry()
            microsoftToken = token
            
            // Enable form hiding
            if !product.isTestMode {
                await enableFormHiding()
            }
            
            // Process activation (bundle or single)
            if product.isBundle {
                try await processBundleActivation(product: product, token: token)
            } else {
                try await processSingleKeyActivation(product: product, token: token)
            }
            
            // Mark as activated
            try await markAsActivated(sessionToken: sessionToken, success: true)
            
            // Cleanup
            await performCleanup()
            
        } catch {
            await handleActivationError(error)
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
            sessionToken: sessionToken,
            productKey: session.licenseKey,
            productKeys: session.licenseKeys ?? (session.licenseKey.map { [$0] }),
            region: session.region ?? ProxyConfig.defaultRegion,
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
        
        devLog("[Product] Found session with activation method: \(activationMethod ?? "standard")")
        
        return product
    }
    
    // MARK: - Generate Portal URL
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
    
    // MARK: - Bundle Processing (State-Based - Matching Chrome Extension)
    private func processBundleActivation(product: Product, token: String) async throws {
        devLog("[API] Bundle detected with \(product.allKeys.count) keys")
        
        activationState = .activatingBundle
        activationProgress = 0.6
        bundleProgress = BundleProgress(
            total: product.allKeys.count,
            completed: 0,
            succeeded: 0,
            failed: 0
        )
        
        // Initialize bundle state tracking
        bundleState = BundleActivationState(keys: product.allKeys)
        
        var results: [BundleKeyResult] = []
        
        for (index, key) in product.allKeys.enumerated() {
            devLog("[API] Redeeming bundle key \(index + 1)/\(product.allKeys.count)")
            
            // Update progress state
            bundleProgress?.currentKey = key
            bundleProgress?.currentIndex = index
            
            // Check if key was already successfully processed (state-based)
            if bundleState?.isSuccessful(key: key) ?? false {
                devLog("[API] Key already successfully redeemed, skipping: \(key)")
                continue
            }
            
            do {
                // Attempt to redeem the key
                try await redeemKey(
                    keys: key,
                    region: product.region,
                    token: token
                )
                
                // SUCCESS STATE - Record success
                results.append(BundleKeyResult(success: true, key: key, result: nil, error: nil))
                bundleState?.recordSuccess(key: key)
                
                // Update progress based on state
                bundleProgress?.succeeded += 1
                bundleProgress?.completed += 1
                activationProgress = 0.6 + (0.3 * Double(bundleProgress?.completed ?? 0) / Double(product.allKeys.count))
                
                devLog("[API] Bundle key \(index + 1) SUCCESS")
                
                // DELAY ONLY AFTER SUCCESSFUL REDEMPTION
                // This matches Chrome extension - delay is between successful redemptions
                if index < product.allKeys.count - 1 {
                    devLog("[API] Waiting 3 seconds before next redemption...")
                    try await Task.sleep(nanoseconds: UInt64(Constants.bundleKeyDelay * 1_000_000_000))
                }
                
            } catch {
                // FAILURE STATE - Analyze error and decide action
                devError("[API] Failed to redeem bundle key \(index + 1): \(error)")
                
                // Record failure state
                bundleState?.recordFailure(key: key, error: error)
                
                // Check error type for special handling
                let errorMessage = error.localizedDescription
                
                // State-based decision: Should we retry with conversion?
                if errorMessage.contains("ConversionConsentRequired") ||
                   errorMessage.contains("Game Pass conversion") {
                    
                    devLog("[API] Bundle key \(index + 1) requires Game Pass conversion - STATE: NEEDS_CONVERSION")
                    
                    // Attempt conversion based on state
                    do {
                        try await handleGamePassConversion(
                            key: key,
                            token: token,
                            region: product.region
                        )
                        
                        // Conversion SUCCESS - Update state
                        results.append(BundleKeyResult(success: true, key: key, result: nil, error: nil))
                        bundleState?.recordSuccess(key: key)
                        bundleProgress?.succeeded += 1
                        
                        devLog("[API] Bundle key \(index + 1) CONVERSION SUCCESS")
                        
                    } catch conversionError {
                        // Conversion FAILED - Final failure state
                        devError("[API] Conversion failed for bundle key \(index + 1): \(conversionError)")
                        
                        results.append(BundleKeyResult(
                            success: false,
                            key: key,
                            result: nil,
                            error: conversionError.localizedDescription
                        ))
                        
                        bundleProgress?.failed += 1
                    }
                    
                } else if errorMessage.contains("TokenAlreadyRedeemed") ||
                          errorMessage.contains("already been redeemed") {
                    
                    // STATE: ALREADY_REDEEMED - Don't retry
                    devLog("[API] Bundle key \(index + 1) STATE: ALREADY_REDEEMED")
                    
                    results.append(BundleKeyResult(
                        success: false,
                        key: key,
                        result: nil,
                        error: "Key already redeemed"
                    ))
                    
                    bundleProgress?.failed += 1
                    
                } else if errorMessage.contains("UserAlreadyOwnsContent") {
                    
                    // STATE: ALREADY_OWNED - Don't retry
                    devLog("[API] Bundle key \(index + 1) STATE: ALREADY_OWNED")
                    
                    results.append(BundleKeyResult(
                        success: false,
                        key: key,
                        result: nil,
                        error: "User already owns this content"
                    ))
                    
                    bundleProgress?.failed += 1
                    
                } else if errorMessage.contains("network") ||
                          errorMessage.contains("timeout") ||
                          errorMessage.contains("407") {
                    
                    // STATE: NETWORK_ERROR - Could retry based on attempts
                    let attempts = bundleState?.keyStates[key]?.attempts ?? 0
                    
                    if attempts < Constants.maxProxyRetries {
                        devLog("[API] Bundle key \(index + 1) STATE: NETWORK_ERROR - Will retry on next pass")
                        
                        // Don't mark as final failure yet - could retry
                        results.append(BundleKeyResult(
                            success: false,
                            key: key,
                            result: nil,
                            error: "Network error - may retry"
                        ))
                    } else {
                        devLog("[API] Bundle key \(index + 1) STATE: MAX_RETRIES_EXCEEDED")
                        
                        results.append(BundleKeyResult(
                            success: false,
                            key: key,
                            result: nil,
                            error: "Max retries exceeded"
                        ))
                        
                        bundleProgress?.failed += 1
                    }
                    
                } else {
                    // STATE: UNKNOWN_ERROR - Record as failure
                    devLog("[API] Bundle key \(index + 1) STATE: UNKNOWN_ERROR")
                    
                    results.append(BundleKeyResult(
                        success: false,
                        key: key,
                        result: nil,
                        error: errorMessage
                    ))
                    
                    bundleProgress?.failed += 1
                }
                
                // Update completed count
                bundleProgress?.completed += 1
                activationProgress = 0.6 + (0.3 * Double(bundleProgress?.completed ?? 0) / Double(product.allKeys.count))
                
                // NO DELAY AFTER FAILURE - Only delay after success
                // This matches Chrome extension behavior
            }
        }
        
        // Process final bundle state
        await processBundleResults(results: results)
    }
    
    // MARK: - Single Key Processing
    private func processSingleKeyActivation(product: Product, token: String) async throws {
        guard let key = product.productKey ?? product.productKeys?.first else {
            throw ActivationError.noKeys
        }
        
        activationState = .activating
        activationProgress = 0.7
        
        try await redeemKey(
            keys: key,
            region: product.region,
            token: token
        )
        
        activationState = .success(
            productName: product.productName,
            keys: [key]
        )
        activationProgress = 1.0
        isActivating = false
    }
    
    // MARK: - Key Redemption (Matching Chrome Extension redeemKey)
    private func redeemKey(keys: String, region: String, token: String) async throws {
        let isGlobalKey = ["GLOBAL", "WW", "WORLDWIDE"].contains(region.uppercased())
        
        if isGlobalKey {
            devLog("[API] Redeeming GLOBAL key (no proxy needed)")
            try await redeemGlobalKey(key: keys, token: token)
        } else {
            devLog("[API] Redeeming key in \(region)")
            try await redeemRegionalKey(key: keys, token: token, region: region)
        }
    }
    
    // MARK: - Global Key Redemption (No Proxy)
    private func redeemGlobalKey(key: String, token: String) async throws {
        devLog("[API] Token captured for GLOBAL key")
        
        let authHeader = "WLID1.0=\"\(token)\""
        let validateUrl = URL(string: "https://purchase.mp.microsoft.com/v7.0/tokenDescriptions/\(key)?market=US&language=en-US&supportMultiAvailabilities=true")!
        
        var validateRequest = URLRequest(url: validateUrl)
        validateRequest.setValue(authHeader, forHTTPHeaderField: "Authorization")
        validateRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (validateData, validateResponse) = try await fetchWithRetry(request: validateRequest)
        
        guard let httpValidateResponse = validateResponse as? HTTPURLResponse else {
            throw ActivationError.networkError
        }
        
        if !httpValidateResponse.statusCode.isSuccess {
            try handleValidationError(status: httpValidateResponse.statusCode, data: validateData)
        }
        
        let validationData = try JSONSerialization.jsonObject(with: validateData) as? [String: Any]
        
        if let tokenState = validationData?["tokenState"] as? String,
           tokenState != "Active" {
            throw ActivationError.keyStateInvalid(tokenState)
        }
        
        // Redeem the key
        let redeemUrl = URL(string: "https://purchase.mp.microsoft.com/v7.0/users/me/orders")!
        
        var redeemRequest = URLRequest(url: redeemUrl)
        redeemRequest.httpMethod = "POST"
        redeemRequest.setValue(authHeader, forHTTPHeaderField: "Authorization")
        redeemRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        redeemRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let payload = createRedemptionPayload(key: key, market: "US")
        redeemRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (redeemData, redeemResponse) = try await fetchWithRetry(request: redeemRequest, method: "POST")
        
        try await handleRedemptionResponse(
            response: redeemResponse,
            data: redeemData,
            key: key,
            token: token,
            region: "US"
        )
        
        devLog("[API] GLOBAL key redemption successful")
    }
    
    // MARK: - Regional Key Redemption (With Proxy)
    private func redeemRegionalKey(key: String, token: String, region: String) async throws {
        let targetRegion = region.uppercased()
        guard let config = ProxyConfig.regions[targetRegion] else {
            throw ActivationError.unsupportedRegion
        }
        
        devLog("[API] Redeeming key in \(targetRegion)")
        
        // Get proxy credentials
        let credentials = try await credentialsManager.getCredentials()
        
        // Enable proxy
        try await enableProxy(region: targetRegion)
        defer {
            Task {
                await disableProxy()
            }
        }
        
        // Create proxy session
        let proxySession = createProxySession(config: config, credentials: credentials)
        
        // Try regional market first, then fall back to US
        do {
            try await redeemWithMarket(
                key: key,
                token: token,
                market: config.market,
                session: proxySession
            )
            devLog("[API] Redemption successful with \(config.market) market")
        } catch {
            if let apiError = error as? APIError {
                switch apiError {
                case .catalogNotFound:
                    devLog("[API] Product not in catalog for \(config.market) region, trying US market catalog")
                    try await redeemWithMarket(
                        key: key,
                        token: token,
                        market: "US",
                        session: proxySession
                    )
                    devLog("[API] US market fetch successful for product details")
                    
                case .marketMismatch:
                    devLog("[API] ActiveMarketMismatch detected, retrying with US market while keeping proxy")
                    try await redeemWithMarket(
                        key: key,
                        token: token,
                        market: "US",
                        session: proxySession
                    )
                    devLog("[API] Redemption successful with US market through regional proxy")
                    
                default:
                    throw error
                }
            } else {
                throw error
            }
        }
    }
    
    // MARK: - Market-Specific Redemption
    private func redeemWithMarket(
        key: String,
        token: String,
        market: String,
        session: URLSession
    ) async throws {
        
        devLog("[API] Validating key at market: \(market)")
        
        // Step 1: Validate
        let validateUrl = URL(string: "https://purchase.mp.microsoft.com/v7.0/tokenDescriptions/\(key)?market=\(market)&language=en-US&supportMultiAvailabilities=true")!
        
        var validateRequest = URLRequest(url: validateUrl)
        validateRequest.setValue("WLID1.0=\"\(token)\"", forHTTPHeaderField: "Authorization")
        validateRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (validateData, validateResponse) = try await session.data(for: validateRequest)
        
        guard let httpValidateResponse = validateResponse as? HTTPURLResponse else {
            throw ActivationError.networkError
        }
        
        devLog("[API] Validation response status: \(httpValidateResponse.statusCode)")
        
        // Check validation response
        if httpValidateResponse.statusCode == 400 {
            if let json = try? JSONSerialization.jsonObject(with: validateData) as? [String: Any],
               let innerError = json["innererror"] as? [String: Any],
               let code = innerError["code"] as? String,
               code == "CatalogSkuDataNotFound" {
                throw APIError.catalogNotFound
            }
            throw ActivationError.validationFailed
        } else if httpValidateResponse.statusCode == 407 {
            devError("[API] Proxy authentication failed - refreshing credentials")
            await credentialsManager.clearCache()
            throw ActivationError.proxyAuthenticationFailed
        } else if !httpValidateResponse.statusCode.isSuccess {
            try handleValidationError(status: httpValidateResponse.statusCode, data: validateData)
        }
        
        let validationData = try JSONSerialization.jsonObject(with: validateData) as? [String: Any]
        
        if let tokenState = validationData?["tokenState"] as? String,
           tokenState != "Active" {
            throw ActivationError.keyStateInvalid(tokenState)
        }
        
        devLog("[API] Validation successful, token state: Active")
        
        // Step 2: Redeem
        let redeemUrl = URL(string: "https://purchase.mp.microsoft.com/v7.0/users/me/orders")!
        
        var redeemRequest = URLRequest(url: redeemUrl)
        redeemRequest.httpMethod = "POST"
        redeemRequest.setValue("WLID1.0=\"\(token)\"", forHTTPHeaderField: "Authorization")
        redeemRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = createRedemptionPayload(key: key, market: market)
        redeemRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        devLog("[API] Attempting redemption with market: \(market)")
        
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
        
        if httpResponse.statusCode.isSuccess {
            devLog("[API] Redemption successful")
            return
        }
        
        // Parse error response
        var errorJson: [String: Any]?
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            errorJson = json
            devError("[API] Parsed error: \(json)")
        }
        
        // Check for conversion required (412)
        if httpResponse.statusCode == 412 {
            if let innerError = errorJson?["innererror"] as? [String: Any],
               let code = innerError["code"] as? String,
               code == "ConversionConsentRequired" {
                
                devLog("[API] Conversion consent required, attempting UI automation flow")
                try await handleGamePassConversion(key: key, token: token, region: region)
                devLog("[API] Game Pass conversion successful via UI automation")
                return
            }
            throw ActivationError.preconditionFailed
        }
        
        // Check for market mismatch (403)
        if httpResponse.statusCode == 403 {
            if let innerError = errorJson?["innererror"] as? [String: Any],
               let code = innerError["code"] as? String,
               code == "ActiveMarketMismatch" {
                throw APIError.marketMismatch
            }
            
            if let errorCode = errorJson?["errorCode"] as? String,
               errorCode == "UserAlreadyOwnsContent" {
                let products = errorJson?["data"] as? [String] ?? []
                throw APIError.userAlreadyOwnsContent(products)
            }
            
            throw ActivationError.forbidden
        }
        
        // Check for specific error codes (400)
        if httpResponse.statusCode == 400 {
            if let errorCode = errorJson?["errorCode"] as? String {
                switch errorCode {
                case "TokenAlreadyRedeemed":
                    throw ActivationError.alreadyRedeemed
                case "InvalidToken":
                    throw ActivationError.invalidKey
                case "UserAlreadyOwnsContent":
                    let products = errorJson?["data"] as? [String] ?? []
                    throw APIError.userAlreadyOwnsContent(products)
                default:
                    throw ActivationError.badRequest(errorCode)
                }
            }
            
            // Check for catalog not found
            if let innerError = errorJson?["innererror"] as? [String: Any],
               let code = innerError["code"] as? String,
               code == "CatalogSkuDataNotFound" {
                throw APIError.catalogNotFound
            }
            
            throw ActivationError.badRequest("Unknown")
        }
        
        // Proxy auth failed
        if httpResponse.statusCode == 407 {
            devError("[API] Proxy authentication failed - refreshing credentials")
            await credentialsManager.clearCache()
            throw ActivationError.proxyAuthenticationFailed
        }
        
        throw ActivationError.httpError(httpResponse.statusCode)
    }
    
    // MARK: - Game Pass Conversion (Matching Chrome Extension)
    private func handleGamePassConversion(
        key: String,
        token: String,
        region: String
    ) async throws {
        
        devLog("[Conversion] Starting Game Pass conversion flow with UI automation")
        
        // 30-second timeout wrapper
        let conversionTask = Task {
            try await executeConversion(key: key, token: token, region: region)
        }
        
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(Constants.conversionTimeout * 1_000_000_000))
            conversionTask.cancel()
            throw ActivationError.conversionTimeout
        }
        
        do {
            let result = try await conversionTask.value
            timeoutTask.cancel()
            return result
        } catch {
            timeoutTask.cancel()
            await cleanupConversion()
            throw error
        }
    }
    
    private func executeConversion(key: String, token: String, region: String) async throws {
        // Setup conversion webview if needed
        if conversionWebView == nil {
            await setupConversionWebView()
        }
        
        guard let webView = conversionWebView else {
            throw ActivationError.noWebView
        }
        
        // Check if already attempted
        let alreadyComplete = try await webView.evaluateJavaScript(
            "window.__EXON_CONVERSION_COMPLETE__"
        ) as? Bool ?? false
        
        if alreadyComplete {
            throw ActivationError.badRequest("Conversion already attempted - refresh to retry")
        }
        
        // Load redeem page
        let redeemUrl = URL(string: "https://account.microsoft.com/billing/redeem")!
        webView.load(URLRequest(url: redeemUrl))
        
        // Wait for page to load
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Execute conversion automation
        return try await withCheckedThrowingContinuation { continuation in
            self.conversionContinuation = continuation
            
            let script = createConversionAutomationScript(key: key)
            
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    devError("[Conversion] Script injection error: \(error)")
                }
            }
            
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
    
    private func cleanupConversion() async {
        conversionWebView?.evaluateJavaScript("""
            window.__EXON_CONVERSION_COMPLETE__ = true;
            delete window.__EXON_CONVERSION_MONITOR__;
            delete window.conversionResults;
        """) { _, _ in }
    }
    
    // MARK: - Token Management (Matching Chrome Extension)
    private func captureTokenWithRetry() async throws -> String {
        tokenRetryCount = 0
        
        for attempt in 1...Constants.maxTokenRetries {
            do {
                tokenRetryCount = attempt
                
                // Check cache first
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
    
    // MARK: - Game Pass Checking
    private func performGamePassChecks(_ product: Product) async throws {
        activationState = .checkingGamePass
        activationProgress = 0.2
        
        guard isGamePassProduct(product) else { return }
        
        let subscriptions = try await fetchActiveSubscriptions()
        
        if let activeGamePass = subscriptions.activeSubscription {
            activationState = .activeSubscription(subscription: activeGamePass)
            isActivating = false
            throw ActivationError.forbidden
        }
    }
    
    private func fetchActiveSubscriptions() async throws -> (hasActiveGamePass: Bool, activeSubscription: ActiveSubscription?) {
        guard let webView = hiddenWebView else {
            throw ActivationError.noWebView
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let script = """
            (async function() {
                try {
                    const response = await fetch(
                        'https://account.microsoft.com/services/api/subscriptions-and-alerts?excludeWindowsStoreInstallOptions=false&excludeLegacySubscriptions=false',
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
                        throw new Error(`Subscriptions request failed: ${response.status}`);
                    }
                    
                    const data = await response.json();
                    
                    // Check for active Game Pass subscriptions
                    let hasActiveGamePass = false;
                    let activeSubscription = null;
                    
                    if (data.active && Array.isArray(data.active)) {
                        for (const sub of data.active) {
                            // Check for Game Pass Core or Ultimate
                            if (sub.productId === 'CFQ7TTC0K5DJ' || sub.productId === 'CFQ7TTC0KHS0') {
                                hasActiveGamePass = true;
                                
                                const hasPaymentIssue = sub.billingState === 3 ||
                                    !sub.autorenews ||
                                    (sub.payment && !sub.payment.valid);
                                
                                activeSubscription = {
                                    name: sub.name,
                                    productId: sub.productId,
                                    endDate: sub.endDate,
                                    daysRemaining: sub.daysRemaining,
                                    hasPaymentIssue: hasPaymentIssue,
                                    autorenews: sub.autorenews
                                };
                                break;
                            }
                        }
                    }
                    
                    return {
                        hasActiveGamePass: hasActiveGamePass,
                        activeSubscription: activeSubscription
                    };
                } catch (error) {
                    throw new Error(`Failed to fetch subscriptions: ${error.message}`);
                }
            })();
            """
            
            webView.evaluateJavaScript(script) { result, error in
                if let dict = result as? [String: Any] {
                    let hasActiveGamePass = dict["hasActiveGamePass"] as? Bool ?? false
                    var activeSubscription: ActiveSubscription?
                    
                    if let subData = dict["activeSubscription"] as? [String: Any] {
                        activeSubscription = ActiveSubscription(
                            name: subData["name"] as? String ?? "",
                            productId: subData["productId"] as? String ?? "",
                            endDate: subData["endDate"] as? String,
                            daysRemaining: subData["daysRemaining"] as? Int,
                            hasPaymentIssue: subData["hasPaymentIssue"] as? Bool ?? false,
                            autorenews: subData["autorenews"] as? Bool ?? false
                        )
                    }
                    
                    continuation.resume(returning: (hasActiveGamePass, activeSubscription))
                } else {
                    continuation.resume(throwing: error ?? ActivationError.networkError)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func createRedemptionPayload(key: String, market: String) -> [String: Any] {
        return [
            "orderId": UUID().uuidString,
            "orderState": "Purchased",
            "billingInformation": [
                "sessionId": UUID().uuidString,
                "paymentInstrumentType": "Token",
                "paymentInstrumentId": key
            ],
            "friendlyName": nil as Any?,
            "clientContext": [
                "client": "AccountMicrosoftCom",
                "deviceId": UIDevice.current.identifierForVendor?.uuidString as Any?,
                "deviceType": "iOS",
                "deviceFamily": "mobile",
                "osVersion": UIDevice.current.systemVersion,
                "clientVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            ],
            "language": "en-US",
            "market": market,
            "orderAdditionalMetadata": nil as Any?
        ]
    }
    
    private func createProxySession(config: ProxyConfig.ProxyRegion, credentials: ProxyCredentials) -> URLSession {
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
        
        sessionConfig.timeoutIntervalForRequest = ProxyConfig.connectionTimeout
        sessionConfig.timeoutIntervalForResource = 30
        
        return URLSession(configuration: sessionConfig)
    }
    
    private func fetchWithRetry(
        request: URLRequest,
        method: String = "GET",
        retries: Int = ProxyConfig.maxRetries
    ) async throws -> (Data, URLResponse) {
        
        for i in 0...retries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                return (data, response)
            } catch {
                if i == retries {
                    throw error
                }
                devLog("[API] Retry \(i + 1)/\(retries) for \(request.url?.absoluteString ?? "")")
                // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64((i + 1) * 1_000_000_000))
            }
        }
        
        throw ActivationError.networkError
    }
    
    private func handleValidationError(status: Int, data: Data) throws {
        switch status {
        case 401: throw ActivationError.authenticationFailed
        case 404: throw ActivationError.invalidKey
        case 400:
            // Try to parse error for more details
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorCode = json["errorCode"] as? String {
                if errorCode == "TokenAlreadyRedeemed" {
                    throw ActivationError.alreadyRedeemed
                }
            }
            throw ActivationError.validationFailed
        case 403: throw ActivationError.forbidden
        case 407: throw ActivationError.proxyAuthenticationFailed
        default: throw ActivationError.httpError(status)
        }
    }
    
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
        // In iOS app, we validate vendors based on allowed list
        // Chrome extension checks against current page URL
        // For iOS, we accept Microsoft Store, Xbox, and vendors from our allowed list
        
        let microsoftVendors = ["Microsoft Store", "Xbox", "Microsoft", "Xbox Game Pass"]
        let allowedThirdPartyVendors = ["Steam", "Epic Games", "Origin", "Ubisoft"]
        
        // Normalize vendor string
        let normalizedVendor = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it's a Microsoft vendor
        if microsoftVendors.contains(where: { normalizedVendor.contains($0) }) {
            return (valid: true, expected: nil)
        }
        
        // Check if it's an allowed third-party vendor
        if allowedThirdPartyVendors.contains(where: { normalizedVendor.contains($0) }) {
            // For third-party vendors, we might need different handling
            devLog("[Vendor] Third-party vendor detected: \(vendor)")
            return (valid: true, expected: nil)
        }
        
        // Empty vendor is allowed (defaults to Microsoft Store)
        if normalizedVendor.isEmpty {
            return (valid: true, expected: nil)
        }
        
        // Unknown vendor
        devWarn("[Vendor] Unknown vendor: \(vendor)")
        return (valid: false, expected: "Microsoft Store")
    }
    
    // MARK: - Cache Management
    private func getTokenFromCache() -> String? {
        let key = UIDevice.current.identifierForVendor?.uuidString ?? ""
        guard let entry = tokenCache[key],
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
        
        // Cleanup old tokens
        cleanupCache()
    }
    
    private func cleanupCache() {
        let now = Date()
        tokenCache = tokenCache.filter { $0.value.expires > now }
        authCache = authCache.filter { $0.value.expires > now }
    }
    
    // MARK: - Proxy Management
    private func enableProxy(region: String) async throws {
        let targetRegion = region.uppercased()
        guard let config = ProxyConfig.regions[targetRegion] else {
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
    }
    
    private func disableProxy() async {
        guard let proxy = activeProxy else { return }
        
        devLog("[Proxy] Disconnecting")
        
        // Track usage for analytics
        let duration = Date().timeIntervalSince(proxy.startTime)
        trackProxyUsage(region: proxy.region, duration: duration)
        
        activeProxy = nil
        cleanupCache()
    }
    
    private func trackProxyUsage(region: String, duration: TimeInterval) {
        devLog("[Analytics] Proxy usage: region=\(region), duration=\(duration)s")
    }
    
    // MARK: - Form Hiding
    private func enableFormHiding() async {
        guard !formHidingEnabled else { return }
        
        devLog("[Form] Activating form hiding")
        
        guard let webView = hiddenWebView else { return }
        
        webView.evaluateJavaScript("document.body.setAttribute('data-exon-active', 'true')") { _, _ in }
        
        formHidingEnabled = true
    }
    
    private func disableFormHiding() async {
        guard formHidingEnabled else { return }
        
        devLog("[Form] Deactivating form hiding")
        
        guard let webView = hiddenWebView else { return }
        
        webView.evaluateJavaScript("document.body.removeAttribute('data-exon-active')") { _, _ in }
        
        formHidingEnabled = false
    }
    
    // MARK: - Storage Management
    private func addProductToStorage(_ product: Product) async {
        // Using UserDefaults for simplicity, can use Core Data for production
        var products = getStoredProducts()
        
        // Check if product already exists based on session_token
        if let existingIndex = products.firstIndex(where: {
            $0.sessionToken == product.sessionToken
        }) {
            // Update existing product
            products[existingIndex] = product
            devLog("[Storage] Updated existing product: \(product.sessionToken ?? "")")
        } else {
            // Add new product
            products.insert(product, at: 0)
            devLog("[Storage] Added new product: \(product.sessionToken ?? "")")
        }
        
        saveStoredProducts(products)
    }
    
    private func getStoredProducts() -> [Product] {
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
    
    // MARK: - Mark As Activated
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
    
    // MARK: - Bundle Results Processing
    private func processBundleResults(results: [BundleKeyResult]) async {
        let succeeded = results.filter { $0.success }.count
        let total = results.count
        let failed = results.compactMap { result -> (key: String, error: String)? in
            guard !result.success else { return nil }
            return (key: result.key, error: result.error ?? "Unknown error")
        }
        
        if succeeded == total {
            activationState = .success(
                productName: currentProduct?.productName ?? "Bundle",
                keys: results.map { $0.key }
            )
        } else if succeeded > 0 {
            activationState = .partialSuccess(
                succeeded: succeeded,
                total: total,
                failed: failed
            )
        } else {
            activationState = .error("All keys failed to activate")
        }
        
        activationProgress = 1.0
        isActivating = false
    }
    
    // MARK: - Cleanup & Reset
    private func performCleanup() async {
        await disableProxy()
        await disableFormHiding()
        cleanupCache()
    }
    
    private func resetState() async {
        isActivating = false
        activationState = .idle
        currentProduct = nil
        errorMessage = nil
        activationProgress = 0.0
        bundleProgress = nil
        bundleState = nil
        formHidingEnabled = false
        tokenRetryCount = 0
        proxyAuthRetryCount.removeAll()
        
        // Clear continuations
        tokenContinuation?.resume(throwing: ActivationError.cancelled)
        tokenContinuation = nil
        conversionContinuation?.resume(throwing: ActivationError.cancelled)
        conversionContinuation = nil
    }
    
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
        
        self.errorMessage = errorMessage
        activationState = .error(errorMessage)
        isActivating = false
    }
    
    // MARK: - WebView Setup
    private func setupWebViews() {
        setupHiddenWebView()
        setupConversionWebView()
    }
    
    private func setupHiddenWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        
        // Add token capture script
        configuration.userContentController.addUserScript(createTokenCaptureScript())
        configuration.userContentController.addUserScript(createFormHidingScript())
        configuration.userContentController.add(self, name: "tokenCapture")
        
        hiddenWebView = WKWebView(frame: .zero, configuration: configuration)
        hiddenWebView?.navigationDelegate = self
        
        // Load Microsoft account page
        let url = URL(string: "https://account.microsoft.com/")!
        hiddenWebView?.load(URLRequest(url: url))
    }
    
    private func setupConversionWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        
        configuration.userContentController.addUserScript(createConversionMonitorScript())
        configuration.userContentController.add(self, name: "conversionHandler")
        
        conversionWebView = WKWebView(frame: .zero, configuration: configuration)
        conversionWebView?.navigationDelegate = self
    }
    
    private func setupCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                self.cleanupCache()
            }
        }
    }
    
    // MARK: - WebView Scripts
    private func createTokenCaptureScript() -> WKUserScript {
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
        })();
        """
        
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }
    
    private func createFormHidingScript() -> WKUserScript {
        let source = """
        (function() {
            const style = document.createElement('style');
            style.textContent = `
                body[data-exon-active="true"] #redeem-container,
                body[data-exon-active="true"] #store-cart-root,
                body[data-exon-active="true"] .store-cart-root,
                body[data-exon-active="true"] [id="store-cart-root"],
                body[data-exon-active="true"] .redeemEnterCodePageContainer,
                body[data-exon-active="true"] [class*="redeemEnterCodePageContainer"] {
                    position: absolute !important;
                    left: -9999px !important;
                    top: -9999px !important;
                }
            `;
            document.head.appendChild(style);
        })();
        """
        
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
    }
    
    private func createConversionMonitorScript() -> WKUserScript {
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
    
    private func createConversionAutomationScript(key: String) -> String {
        return """
        (function() {
            console.log('[EXON] Starting conversion automation for key');
            
            if (window.__EXON_CONVERSION_COMPLETE__) {
                return;
            }
            
            function fillKey() {
                const input = document.querySelector('input[placeholder*="25-character"]') ||
                              document.querySelector('input[placeholder="Enter 25-character code"]');
                
                if (!input) {
                    setTimeout(fillKey, 500);
                    return;
                }
                
                input.value = '\(key)';
                
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
                
                input.dispatchEvent(new Event('input', { bubbles: true }));
                input.dispatchEvent(new Event('change', { bubbles: true }));
                
                setTimeout(clickNext, 2000);
            }
            
            function clickNext() {
                const nextBtn = document.querySelector('button[data-bi-dnt="true"].primary--DMe8vsrv') ||
                               document.querySelector('button.primary--DMe8vsrv');
                
                if (!nextBtn || nextBtn.disabled) {
                    setTimeout(clickNext, 500);
                    return;
                }
                
                nextBtn.click();
                setTimeout(clickContinue, 2500);
            }
            
            function clickContinue() {
                const continueBtn = Array.from(document.querySelectorAll('button')).find(b =>
                    b.textContent.trim() === 'Continue'
                );
                
                if (!continueBtn) {
                    setTimeout(clickContinue, 500);
                    return;
                }
                
                continueBtn.click();
                setTimeout(handleBilling, 2000);
            }
            
            function handleBilling() {
                const toggle = document.querySelector('input[type="checkbox"]');
                if (toggle && toggle.checked) {
                    toggle.click();
                }
                
                setTimeout(() => {
                    const confirmBtn = Array.from(document.querySelectorAll('button')).find(btn =>
                        btn.textContent.trim() === 'Confirm'
                    );
                    
                    if (confirmBtn) {
                        confirmBtn.click();
                        window.__EXON_CONVERSION_COMPLETE__ = true;
                        setTimeout(checkSuccess, 3000);
                    } else {
                        setTimeout(handleBilling, 500);
                    }
                }, 1500);
            }
            
            function checkSuccess() {
                if (window.location.href.includes('redeem-success')) {
                    window.webkit.messageHandlers.conversionHandler.postMessage({
                        type: 'success',
                        source: 'success-page'
                    });
                } else {
                    setTimeout(checkSuccess, 1000);
                }
            }
            
            fillKey();
        })();
        """
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
        
        if type == "success" || (type == "redeemToken" && dict["success"] as? Bool == true) {
            conversionContinuation?.resume(returning: true)
            conversionContinuation = nil
        }
    }
}

// MARK: - HTTP Status Code Extension
extension Int {
    var isSuccess: Bool {
        return self >= 200 && self < 300
    }
}
