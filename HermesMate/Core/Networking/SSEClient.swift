import Foundation

public struct SSEEvent: Sendable {
    public var id: String?
    public var event: String?
    public var data: String?
}

public actor SSEClient {
    private let session: URLSession
    private let url: URL
    private let apiKey: String
    
    public init(runId: String, apiKey: String = HermesAPIClient.shared.apiKey) {
        self.url = URL(string: "http://127.0.0.1:8642/v1/runs/\(runId)/events")!
        self.apiKey = apiKey
        self.session = URLSession(configuration: .default)
    }
    
    public func connect() -> AsyncThrowingStream<SSEEvent, Error> {
        let localURL = self.url
        let localAPIKey = self.apiKey
        let localSession = self.session
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: localURL)
                    request.setValue("Bearer \(localAPIKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    
                    let (stream, response) = try await localSession.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: NSError(domain: "SSEError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                        return
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        continuation.finish(throwing: NSError(domain: "SSEError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode)"]))
                        return
                    }
                    
                    var currentEvent = SSEEvent()
                    
                    for try await line in stream.lines {
                        if Task.isCancelled {
                            break
                        }
                        
                        if line.isEmpty {
                            // Dispatch event if we have data or event type
                            if currentEvent.data != nil || currentEvent.event != nil {
                                continuation.yield(currentEvent)
                                currentEvent = SSEEvent() // Reset for next event
                            }
                            continue
                        }
                        
                        let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                        guard let field = parts.first?.trimmingCharacters(in: .whitespaces) else { continue }
                        
                        let value = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
                        
                        switch field {
                        case "id":
                            currentEvent.id = value
                        case "event":
                            currentEvent.event = value
                        case "data":
                            if let existing = currentEvent.data {
                                currentEvent.data = existing + "\n" + value
                            } else {
                                currentEvent.data = value
                            }
                            // Try to parse JSON to find event
                            if let dataObj = currentEvent.data?.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: dataObj) as? [String: Any],
                               let eventType = json["event"] as? String {
                                currentEvent.event = eventType
                            }
                        default:
                            break // Ignore other fields like retry
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
