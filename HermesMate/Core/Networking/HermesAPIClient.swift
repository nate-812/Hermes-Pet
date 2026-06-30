import Foundation

public enum HermesAPIError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
}

public final class HermesAPIClient: Sendable {
    public static let shared = HermesAPIClient()
    
    private let baseURLString = "http://127.0.0.1:8642"
    private let session: URLSession
    public let apiKey: String
    
    private init() {
        self.session = URLSession.shared
        self.apiKey = HermesAPIClient.loadAPIKey()
    }
    
    private static func loadAPIKey() -> String {
        return "hermes-api-key-2024"
    }
    
    private func defaultDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            let backupFormatter = ISO8601DateFormatter()
            if let date = backupFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \(dateString)"
            )
        }
        
        return decoder
    }
    
    private func performRequest<T: Decodable>(endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T {
        guard let url = URL(string: baseURLString + endpoint) else {
            throw HermesAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HermesAPIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw HermesAPIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        do {
            let decoder = defaultDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HermesAPIError.decodingError(error)
        }
    }
    
    private func performEmptyRequest(endpoint: String, method: String = "POST") async throws {
        guard let url = URL(string: baseURLString + endpoint) else {
            throw HermesAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HermesAPIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw HermesAPIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - API Methods
    
    public func getHealthDetailed() async throws -> HealthDetailed {
        return try await performRequest(endpoint: "/health/detailed")
    }
    
    public func getSessions(limit: Int = 10) async throws -> [Session] {
        let response: PaginatedResponse<Session> = try await performRequest(endpoint: "/api/sessions?limit=\(limit)")
        return response.data
    }
    
    public func getJobs() async throws -> [Job] {
        let response: JobsResponse = try await performRequest(endpoint: "/api/jobs")
        return response.jobs
    }
    
    public func pauseJob(id: String) async throws {
        try await performEmptyRequest(endpoint: "/api/jobs/\(id)/pause", method: "POST")
    }
    
    public func resumeJob(id: String) async throws {
        try await performEmptyRequest(endpoint: "/api/jobs/\(id)/resume", method: "POST")
    }
    
    public func getToolsets() async throws -> [Toolset] {
        return try await performRequest(endpoint: "/api/toolsets")
    }
}
