import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// SDK configuration options
public struct ClientOptions {
    /// Base URL for the API (required)
    public let baseURL: String
    /// API key for authentication (optional)
    public let apiKey: String?
    /// Bearer token for authentication (optional)
    public let bearerToken: String?
    /// Request timeout in seconds (default: 15)
    public let timeoutSeconds: TimeInterval
    /// Maximum number of retry attempts (default: 3)
    public let maxRetries: Int
    /// Custom user agent (optional)
    public let userAgent: String
    /// Additional custom headers (optional)
    public let customHeaders: [String: String]?
    /// Enable debug logging (default: false)
    public let debug: Bool
    
    public init(
        baseURL: String,
        apiKey: String? = nil,
        bearerToken: String? = nil,
        timeoutSeconds: TimeInterval = 15,
        maxRetries: Int = 3,
        userAgent: String = "yourapi-swift-sdk/0.1.0",
        customHeaders: [String: String]? = nil,
        debug: Bool = false
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.bearerToken = bearerToken
        self.timeoutSeconds = timeoutSeconds
        self.maxRetries = maxRetries
        self.userAgent = userAgent
        self.customHeaders = customHeaders
        self.debug = debug
    }
}

/// API error with structured information
public struct APIError: Error, CustomStringConvertible {
    public let message: String
    public let status: Int?
    public let code: String?
    public let details: Any?
    public let requestID: String?
    
    public var description: String {
        var parts = [message]
        if let status = status {
            parts.append("(status=\(status))")
        }
        if let code = code {
            parts.append("(code=\(code))")
        }
        if let requestID = requestID {
            parts.append("(request_id=\(requestID))")
        }
        return parts.joined(separator: " ")
    }
}

/// Cursor-based paginated response
public struct CursorPaginatedResponse<T: Decodable>: Decodable {
    public let items: [T]
    public let nextCursor: String?
    public let hasMore: Bool
}

/// Page-based paginated response
public struct PagePaginatedResponse<T: Decodable>: Decodable {
    public let items: [T]
    public let page: Int
    public let perPage: Int
    public let totalPages: Int
    public let totalItems: Int
}

/// Main SDK client
public class Client {
    private let baseURL: String
    private let session: URLSession
    private let maxRetries: Int
    private let debug: Bool
    private let defaultHeaders: [String: String]
    
    /// Create a new YourAPI client
    public init(options: ClientOptions) {
        self.baseURL = options.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.maxRetries = options.maxRetries
        self.debug = options.debug
        
        // Build default headers
        var headers: [String: String] = [
            "User-Agent": options.userAgent,
            "X-SDK-Language": "swift",
            "X-SDK-Version": "0.1.0",
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        
        // Add auth headers
        if let bearerToken = options.bearerToken {
            headers["Authorization"] = "Bearer \(bearerToken)"
        } else if let apiKey = options.apiKey {
            headers["X-API-Key"] = apiKey
        }
        
        // Add custom headers
        if let customHeaders = options.customHeaders {
            headers.merge(customHeaders) { (_, new) in new }
        }
        
        self.defaultHeaders = headers
        
        // Create URL session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = options.timeoutSeconds
        config.timeoutIntervalForResource = options.timeoutSeconds
        self.session = URLSession(configuration: config)
    }
    
    private func logDebug(_ message: String) {
        if debug {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            print("[\(timestamp)] [YourAPI] \(message)")
        }
    }
    
    private func calculateBackoff(attempt: Int, retryAfter: String?) -> TimeInterval {
        if let retryAfterStr = retryAfter {
            // Try parsing as seconds
            if let seconds = TimeInterval(retryAfterStr) {
                return seconds
            }
            // Try parsing as date
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            if let retryDate = formatter.date(from: retryAfterStr) {
                let interval = retryDate.timeIntervalSinceNow
                if interval > 0 {
                    return interval
                }
            }
        }
        
        // Exponential backoff: 2^attempt, capped at 8 seconds
        return min(pow(2.0, Double(attempt)), 8.0)
    }
    
    private func parseError(from data: Data?, response: HTTPURLResponse) -> APIError {
        let status = response.statusCode
        var message = "Request failed with status \(status)"
        var code: String?
        var details: Any?
        var requestID: String? = response.value(forHTTPHeaderField: "X-Request-Id")
        
        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let msg = json["message"] as? String {
                message = msg
            }
            code = json["code"] as? String
            details = json["details"]
            if let reqID = json["requestId"] as? String {
                requestID = reqID
            }
        }
        
        return APIError(
            message: message,
            status: status,
            code: code,
            details: details,
            requestID: requestID
        )
    }
    
    private func makeRequest(
        method: String,
        path: String,
        body: Data? = nil,
        additionalHeaders: [String: String]? = nil
    ) async throws -> Data? {
        let urlString = "\(baseURL)\(path)"
        guard let url = URL(string: urlString) else {
            throw APIError(message: "Invalid URL: \(urlString)", status: nil, code: "INVALID_URL", details: nil, requestID: nil)
        }
        
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            logDebug("\(method) \(urlString) (attempt \(attempt + 1)/\(maxRetries + 1))")
            
            var request = URLRequest(url: url)
            request.httpMethod = method
            
            // Add headers
            for (key, value) in defaultHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
            if let additionalHeaders = additionalHeaders {
                for (key, value) in additionalHeaders {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            
            // Add body
            if let body = body {
                request.httpBody = body
            }
            
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError(message: "Invalid response type", status: nil, code: "INVALID_RESPONSE", details: nil, requestID: nil)
                }
                
                logDebug("Response: \(httpResponse.statusCode)")
                
                // Success
                if (200..<300).contains(httpResponse.statusCode) {
                    if httpResponse.statusCode == 204 || data.isEmpty {
                        return nil
                    }
                    return data
                }
                
                // Check for retryable errors
                let retryableStatuses = [429, 500, 502, 503, 504]
                if retryableStatuses.contains(httpResponse.statusCode) && attempt < maxRetries {
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    let backoff = calculateBackoff(attempt: attempt, retryAfter: retryAfter)
                    logDebug("Retrying after \(backoff)s")
                    try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                    continue
                }
                
                // Non-retryable error
                throw parseError(from: data, response: httpResponse)
                
            } catch let error as APIError {
                throw error
            } catch {
                lastError = error
                if attempt < maxRetries {
                    let backoff = calculateBackoff(attempt: attempt, retryAfter: nil)
                    logDebug("Request error, retrying after \(backoff)s: \(error)")
                    try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                    continue
                }
            }
        }
        
        if let lastError = lastError {
            throw APIError(message: "Request failed: \(lastError.localizedDescription)", status: nil, code: "REQUEST_ERROR", details: nil, requestID: nil)
        }
        
        throw APIError(message: "Max retries exceeded", status: nil, code: "MAX_RETRIES_EXCEEDED", details: nil, requestID: nil)
    }
    
    /// Make a GET request
    public func get<T: Decodable>(path: String) async throws -> T? {
        let data = try await makeRequest(method: "GET", path: path)
        guard let data = data else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    /// Make a POST request
    public func post<T: Decodable>(path: String, body: Encodable, idempotencyKey: String? = nil) async throws -> T? {
        let bodyData = try JSONEncoder().encode(body)
        var headers: [String: String]? = nil
        if let idempotencyKey = idempotencyKey {
            headers = ["Idempotency-Key": idempotencyKey]
        }
        let data = try await makeRequest(method: "POST", path: path, body: bodyData, additionalHeaders: headers)
        guard let data = data else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    /// Make a PATCH request
    public func patch<T: Decodable>(path: String, body: Encodable) async throws -> T? {
        let bodyData = try JSONEncoder().encode(body)
        let data = try await makeRequest(method: "PATCH", path: path, body: bodyData)
        guard let data = data else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    /// Make a PUT request
    public func put<T: Decodable>(path: String, body: Encodable) async throws -> T? {
        let bodyData = try JSONEncoder().encode(body)
        let data = try await makeRequest(method: "PUT", path: path, body: bodyData)
        guard let data = data else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    /// Make a DELETE request
    public func delete(path: String) async throws {
        _ = try await makeRequest(method: "DELETE", path: path)
    }
    
    /// Paginate through cursor-based API results
    public func paginateCursor<T: Decodable>(path: String) async throws -> [T] {
        var allItems: [T] = []
        var cursor: String? = nil
        var hasMore = true
        
        while hasMore {
            var currentPath = path
            if let cursor = cursor {
                let separator = path.contains("?") ? "&" : "?"
                currentPath = "\(path)\(separator)cursor=\(cursor)"
            }
            
            let response: CursorPaginatedResponse<T> = try await get(path: currentPath) ?? CursorPaginatedResponse(items: [], nextCursor: nil, hasMore: false)
            allItems.append(contentsOf: response.items)
            cursor = response.nextCursor
            hasMore = response.hasMore && cursor != nil
        }
        
        return allItems
    }
}

