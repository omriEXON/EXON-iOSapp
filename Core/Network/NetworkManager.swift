import Foundation
import Network

final class NetworkManager {
    static let shared = NetworkManager()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.exon.networkmonitor")
    @Published var isNetworkAvailable = true
    
    private init() {
        setupMonitoring()
    }
    
    private func setupMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    // Exponential backoff retry
    func executeWithRetry<T>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 32.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var delay = initialDelay
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if error is retryable
                if !isRetryableError(error) {
                    throw error
                }
                
                if attempt < maxAttempts {
                    // Exponential backoff with jitter
                    let jitter = Double.random(in: 0.8...1.2)
                    let sleepTime = min(delay * jitter, maxDelay)
                    
                    print("[Network] Attempt \(attempt)/\(maxAttempts) failed, retrying in \(sleepTime)s")
                    
                    try await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
                    delay *= 2 // Exponential increase
                }
            }
        }
        
        throw lastError ?? ActivationError.networkError
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        // Network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost,
                 .networkConnectionLost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
        
        // HTTP status codes
        if let apiError = error as? APIError {
            switch apiError {
            case .serverError, .gatewayTimeout:
                return true
            default:
                return false
            }
        }
        
        return false
    }
}
