import Foundation

final class ProxyAuthDelegate: NSObject, URLSessionDelegate {
    private let credentials: ProxyCredentials
    private var authAttempts: [String: Int] = [:]
    private let maxAuthAttempts = 3
    
    init(credentials: ProxyCredentials) {
        self.credentials = credentials
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic ||
              challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        let host = challenge.protectionSpace.host
        let attemptKey = "\(host):\(challenge.protectionSpace.port)"
        
        let attempts = authAttempts[attemptKey] ?? 0
        
        if attempts >= maxAuthAttempts {
            print("[ProxyAuth] Max auth attempts reached for \(attemptKey)")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        authAttempts[attemptKey] = attempts + 1
        
        let credential = URLCredential(
            user: credentials.username,
            password: credentials.password,
            persistence: .forSession
        )
        
        print("[ProxyAuth] Providing credentials for \(attemptKey) (attempt \(attempts + 1))")
        completionHandler(.useCredential, credential)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Reset auth attempts on completion
        if let url = task.currentRequest?.url {
            let attemptKey = "\(url.host ?? ""):\(url.port ?? 0)"
            authAttempts.removeValue(forKey: attemptKey)
        }
    }
}
