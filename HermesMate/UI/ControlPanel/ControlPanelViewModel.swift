import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
class ControlPanelViewModel {
    var agentVersion: String = "..."
    var activeAgents: Int = 0
    var gatewayState: String = "Connecting..."
    var totalTokens: Int = 0
    var totalCost: Double = 0.0
    var jobs: [Job] = []
    var sessions: [Session] = []
    var systemSnapshot: SystemSnapshot = .current()
    var showToolGuard: Bool = false
    
    // For TokenChartWidget
    var chartData: [CGFloat] = []
    var chartLabels: [String] = []
    
    struct Job: Identifiable {
        let id: String
        var name: String
        var status: String
    }
    
    struct SystemSnapshot {
        var hostName: String
        var systemVersion: String
        var processorCount: Int
        var physicalMemory: UInt64
        var uptime: TimeInterval
        var diskFree: UInt64
        var diskTotal: UInt64
        
        static func current() -> SystemSnapshot {
            let processInfo = ProcessInfo.processInfo
            let diskValues = diskCapacity()
            
            return SystemSnapshot(
                hostName: Host.current().localizedName ?? processInfo.hostName,
                systemVersion: processInfo.operatingSystemVersionString,
                processorCount: processInfo.processorCount,
                physicalMemory: processInfo.physicalMemory,
                uptime: processInfo.systemUptime,
                diskFree: diskValues.free,
                diskTotal: diskValues.total
            )
        }
        
        private static func diskCapacity() -> (free: UInt64, total: UInt64) {
            do {
                let values = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
                let free = values[.systemFreeSize] as? NSNumber
                let total = values[.systemSize] as? NSNumber
                return (free?.uint64Value ?? 0, total?.uint64Value ?? 0)
            } catch {
                return (0, 0)
            }
        }
    }
    
    var latestSession: Session? {
        sessions.sorted { ($0.lastActive ?? $0.startedAt ?? 0) > ($1.lastActive ?? $1.startedAt ?? 0) }.first
    }
    
    var activeJobs: [Job] {
        jobs.filter { ["active", "running", "scheduled"].contains($0.status.lowercased()) }
    }
    
    private var timerTask: Task<Void, Never>?
    
    init() {
        startPolling()
    }
    
    private func startPolling() {
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                await fetchData()
                try? await Task.sleep(nanoseconds: 2_000_000_000) // Poll every 2 seconds
            }
        }
    }
    
    func fetchData() async {
        self.systemSnapshot = .current()
        
        do {
            let health = try await HermesAPIClient.shared.getHealthDetailed()
            self.agentVersion = health.version ?? "Unknown"
            self.gatewayState = health.status
            
            let sessions = try await HermesAPIClient.shared.getSessions(limit: 500)
            self.sessions = sessions
            let activeSessions = sessions.filter { $0.status == "active" || $0.status == "running" }
            self.activeAgents = activeSessions.count
            
            // Calculate daily tokens for the past 7 days and total for the month
            var dailyTokens: [CGFloat] = Array(repeating: 0, count: 7)
            var dailyLabels: [String] = Array(repeating: "", count: 7)
            var monthTokens: Int = 0
            
            let calendar = Calendar.current
            let today = Date()
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM-dd"
            
            for session in sessions {
                guard let timestamp = session.startedAt else { continue }
                let sessionDate = Date(timeIntervalSince1970: timestamp)
                let tokens = (session.inputTokens ?? 0) + (session.outputTokens ?? 0)
                
                // Month total
                if calendar.isDate(sessionDate, equalTo: today, toGranularity: .month) {
                    monthTokens += tokens
                }
                
                // Daily total for past 7 days
                let startOfDaySession = calendar.startOfDay(for: sessionDate)
                let startOfDayToday = calendar.startOfDay(for: today)
                let components = calendar.dateComponents([.day], from: startOfDaySession, to: startOfDayToday)
                
                if let dayDiff = components.day, dayDiff >= 0 && dayDiff < 7 {
                    let index = 6 - dayDiff // 6 is today, 0 is 6 days ago
                    dailyTokens[index] += CGFloat(tokens)
                }
            }
            
            // Generate labels for the past 7 days
            for i in 0..<7 {
                let dayDiff = 6 - i
                if let date = calendar.date(byAdding: .day, value: -dayDiff, to: today) {
                    dailyLabels[i] = dateFormatter.string(from: date)
                }
            }
            
            self.totalTokens = monthTokens
            self.totalCost = sessions.reduce(0.0) { $0 + ($1.estimatedCostUsd ?? 0.0) } // Keep total cost for now, or maybe month cost? User didn't ask.
            
            self.chartData = dailyTokens
            self.chartLabels = dailyLabels
            
            let apiJobs = try await HermesAPIClient.shared.getJobs()
            self.jobs = apiJobs.map { Job(id: $0.id, name: $0.name ?? "Job \($0.id.prefix(6))", status: $0.state ?? $0.status ?? "running") }
            
            // Start SSE listening for tool guard
            if let activeRunSession = sessions.first(where: { $0.activeRunId != nil }), let runId = activeRunSession.activeRunId {
                startSSE(runId: runId)
            }
        } catch {
            self.gatewayState = "Disconnected"
            print("Fetch data error: \(error)")
        }
    }
    
    private func startSSE(runId: String) {
        let client = SSEClient(runId: runId)
        Task {
            do {
                for try await event in await client.connect() {
                    if event.event == "approval.request" {
                        await MainActor.run {
                            self.showToolGuard = true
                        }
                    }
                }
            } catch {
                print("SSE Error: \(error)")
            }
        }
    }
}
