import Foundation

// MARK: - Health Detailed
public struct HealthDetailed: Codable {
    public let status: String
    public let version: String?
    public let uptime: TimeInterval?
    // Add other fields as needed based on actual API response
}

// MARK: - Session
public struct Session: Codable, Identifiable {
    public let id: String
    public let title: String?
    public let status: String?
    public let startedAt: Double?
    public let lastActive: Double?
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let estimatedCostUsd: Double?
    public let activeRunId: String?
    public let parentSessionId: String?
    public let messageCount: Int?
    public let toolCallCount: Int?
    public let preview: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case status
        case startedAt = "started_at"
        case lastActive = "last_active"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case estimatedCostUsd = "estimated_cost_usd"
        case activeRunId = "active_run_id"
        case parentSessionId = "parent_session_id"
        case messageCount = "message_count"
        case toolCallCount = "tool_call_count"
        case preview
    }
}

// MARK: - Job
public struct Job: Codable, Identifiable {
    public let id: String
    public let name: String?
    public let state: String?
    public let status: String?
    public let sessionId: String?
    public let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case state
        case status
        case sessionId = "session_id"
        case createdAt = "created_at"
    }
}

// MARK: - Toolset
public struct Toolset: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
}

// MARK: - API Responses
public struct PaginatedResponse<T: Codable>: Codable {
    public let object: String?
    public let data: [T]
}

public struct JobsResponse: Codable {
    public let jobs: [Job]
}
