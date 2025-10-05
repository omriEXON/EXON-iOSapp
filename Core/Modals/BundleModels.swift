import Foundation

struct BundleKeyResult {
    let success: Bool
    let key: String
    let result: Any?
    let error: String?
}

struct BundleActivationState {
    private var keyStates: [String: KeyState] = [:]
    
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

struct BundleProgress {
    let total: Int
    var completed: Int
    var succeeded: Int
    var failed: Int
    var currentKey: String?
    var currentIndex: Int?
}
