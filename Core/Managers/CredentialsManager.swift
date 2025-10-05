import Foundation

final class CredentialsManager {
    static let shared = CredentialsManager()
    
    private var cachedCredentials: ProxyCredentials?
    private var credentialsExpiry: Date?
    private var fetchingTask: Task<ProxyCredentials, Error>?
    private let cacheDuration: TimeInterval = 3600 // 1 hour
    
    private init() {}
    
    func getCredentials() async throws -> ProxyCredentials {
        // Check if we have valid cached credentials
        if let cached = cachedCredentials,
           let expiry = credentialsExpiry,
           Date() < expiry {
            print("[Credentials] Using cached proxy credentials")
            return cached
        }
        
        // If already fetching, wait for that task
        if let task = fetchingTask {
            print("[Credentials] Waiting for existing fetch...")
            return try await task.value
        }
        
        // Start new fetch
        let task = Task {
            try await fetchProxyCredentials()
        }
        fetchingTask = task
        
        do {
            let credentials = try await task.value
            cachedCredentials = credentials
            credentialsExpiry = Date().addingTimeInterval(cacheDuration)
            fetchingTask = nil
            return credentials
        } catch {
            fetchingTask = nil
            throw error
        }
    }
    
    private func fetchProxyCredentials() async throws -> ProxyCredentials {
        print("[Credentials] Fetching proxy credentials from Edge Function")
        
        let url = URL(string: "\(Config.Supabase.url)/functions/v1/get-proxy-creds")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.Supabase.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["session_token": "ios_request"]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ActivationError.proxyCredentialsFailed
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let user = json["user"] as? String,
              let password = json["password"] as? String else {
            throw ActivationError.proxyCredentialsFailed
        }
        
        let expiresAt: Date
        if let expiresAtString = json["expires_at"] as? String,
           let date = ISO8601DateFormatter().date(from: expiresAtString) {
            expiresAt = date
        } else {
            expiresAt = Date().addingTimeInterval(3600)
        }
        
        return ProxyCredentials(
            username: user,
            password: password,
            expiresAt: expiresAt
        )
    }
    
    func clearCache() {
        cachedCredentials = nil
        credentialsExpiry = nil
        fetchingTask = nil
        print("[Credentials] Cache cleared")
    }
}
