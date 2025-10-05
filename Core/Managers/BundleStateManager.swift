import Foundation

final class BundleStateManager {
    private var bundleState: BundleActivationState?
    
    func createBundleState(for keys: [String]) -> BundleActivationState {
        let state = BundleActivationState(keys: keys)
        self.bundleState = state
        return state
    }
    
    func getCurrentState() -> BundleActivationState? {
        return bundleState
    }
    
    func reset() {
        bundleState = nil
    }
}

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
    
    func recordMarketAttempt(key: String, market: String) {
        keyStates[key]?.marketsAttempted.append(market)
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
    
    func canRetryKey(_ key: String, maxAttempts: Int = 3) -> Bool {
        guard let state = keyStates[key] else { return false }
        return state.attempts < maxAttempts && recoverableFailures.contains(key)
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
        
        var hasPartialSuccess: Bool {
            return !succeeded.isEmpty && !failed.isEmpty
        }
        
        var isCompleteFailure: Bool {
            return succeeded.isEmpty && !failed.isEmpty
        }
        
        var isCompleteSuccess: Bool {
            return !succeeded.isEmpty && failed.isEmpty
        }
    }
}
