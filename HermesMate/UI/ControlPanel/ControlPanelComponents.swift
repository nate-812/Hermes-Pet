import SwiftUI

enum ControlPanelDisplayFormatter {
    static func tokens(_ value: Int) -> String {
        abbreviated(Double(value), suffixes: ["", "K", "M", "B"])
    }
    
    static func tokens(_ value: CGFloat) -> String {
        abbreviated(Double(value), suffixes: ["", "K", "M", "B"])
    }
    
    static func cost(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
    
    static func bytes(_ value: UInt64) -> String {
        bytes(Int64(value))
    }
    
    static func bytes(_ value: Int64) -> String {
        let mb = Double(value) / 1_024 / 1_024
        if mb < 1_024 {
            return String(format: "%.0f MB", mb)
        }
        
        return String(format: "%.1f GB", mb / 1_024)
    }
    
    static func uptime(_ value: TimeInterval) -> String {
        let hours = Int(value / 3_600)
        let days = hours / 24
        let remainingHours = hours % 24
        
        if days > 0 {
            return "\(days)d \(remainingHours)h"
        }
        
        return "\(hours)h"
    }
    
    private static func abbreviated(_ value: Double, suffixes: [String]) -> String {
        var amount = value
        var suffixIndex = 0
        
        while amount >= 1_000, suffixIndex < suffixes.count - 1 {
            amount /= 1_000
            suffixIndex += 1
        }
        
        if suffixIndex == 0 {
            return String(format: "%.0f", amount)
        }
        
        if amount >= 100 || amount.rounded(.down) == amount {
            return String(format: "%.0f%@", amount, suffixes[suffixIndex])
        }
        
        return String(format: "%.1f%@", amount, suffixes[suffixIndex])
    }
}

enum ControlPanelTab: String, CaseIterable, Identifiable {
    case home
    case agents
    case sessions
    case system
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .agents: return "Agents"
        case .sessions: return "Sessions"
        case .system: return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "gauge.with.dots.needle.50percent"
        case .agents: return "bolt.horizontal"
        case .sessions: return "message"
        case .system: return "desktopcomputer"
        }
    }
}

private enum ControlPanelStyle {
    static let panelFill = Color(nsColor: .windowBackgroundColor).opacity(0.76)
    static let cardFill = Color.white.opacity(0.64)
    static let insetFill = Color.black.opacity(0.045)
    static let border = Color.black.opacity(0.08)
    static let strongText = Color.black.opacity(0.88)
    static let bodyText = Color.black.opacity(0.68)
    static let mutedText = Color.black.opacity(0.48)
    static let accent = Color(red: 0.11, green: 0.42, blue: 0.95)
}

// MARK: - Reusable Glass Card
struct GlassCard<Content: View>: View {
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var cornerRadius: CGFloat = 16
    let content: () -> Content
    
    init(width: CGFloat? = nil, height: CGFloat? = nil, cornerRadius: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.content = content
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(ControlPanelStyle.cardFill)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(ControlPanelStyle.border, lineWidth: 1)
                )
            
            content()
                .padding(16)
        }
        .frame(width: width, height: height)
        .frame(maxWidth: width == nil ? .infinity : nil)
    }
}

// MARK: - Token Chart Widget
struct TokenChartWidget: View {
    let data: [CGFloat]
    let labels: [String]
    
    private func formatToken(_ val: CGFloat) -> String {
        ControlPanelDisplayFormatter.tokens(val)
    }
    
    var body: some View {
        GlassCard(height: 170) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Usage Trend")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ControlPanelStyle.strongText)
                        Text("Last 7 days")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ControlPanelStyle.mutedText)
                    }
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ControlPanelStyle.accent)
                }
                
                Spacer()
                
                HStack(alignment: .bottom, spacing: 14) {
                    let maxData = max(data.max() ?? 1, 100)
                    let scale = 82.0 / maxData
                    
                    ForEach(0..<min(data.count, labels.count), id: \.self) { index in
                        VStack(spacing: 7) {
                            Text(data[index] > 0 ? formatToken(data[index]) : "0")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(data[index] > 0 ? ControlPanelStyle.bodyText : ControlPanelStyle.mutedText)
                                .fixedSize()
                            
                            Capsule()
                                .fill(index == data.count - 1 ? ControlPanelStyle.accent : Color.black.opacity(0.12))
                                .frame(width: 12, height: max(data[index] * scale, 4))
                            
                            Text(labels[index])
                                .font(.system(size: 9))
                                .foregroundColor(ControlPanelStyle.mutedText)
                                .fixedSize()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - Recent Sessions Widget
struct RecentSessionsWidget: View {
    let sessions: [Session]
    
    var body: some View {
        GlassCard(width: 220, height: 200) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Sessions")
                        .font(.subheadline)
                        .foregroundColor(.black.opacity(0.7))
                    Spacer()
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.5))
                }
                
                if sessions.isEmpty {
                    Spacer()
                    Text("No sessions")
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(sessions.prefix(4)) { session in
                            HStack {
                                Circle()
                                    .fill(statusColor(for: session.status ?? ""))
                                    .frame(width: 8, height: 8)
                                
                                Text(session.title ?? "Session \(session.id.prefix(4))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.black.opacity(0.8))
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(session.status ?? "unknown")
                                    .font(.system(size: 9))
                                    .foregroundColor(.black.opacity(0.5))
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(Color.white.opacity(0.4))
                            .cornerRadius(8)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "active", "running": return .green
        case "paused", "waiting": return .yellow
        case "completed", "done": return .blue
        case "error", "failed": return .red
        default: return .gray
        }
    }
}


// MARK: - Session Metric Widget
struct SessionMetricWidget: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var icon: String? = nil
    
    var body: some View {
        GlassCard(height: 72) {
            HStack(alignment: .top, spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ControlPanelStyle.accent)
                        .frame(width: 24, height: 24)
                        .background(ControlPanelStyle.insetFill)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(ControlPanelStyle.mutedText)
                    Text(value)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(ControlPanelStyle.strongText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(ControlPanelStyle.mutedText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Job Status Widget
struct JobStatusWidget: View {
    let jobs: [ControlPanelViewModel.Job]
    
    var body: some View {
        GlassCard(height: 104) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Active Jobs")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ControlPanelStyle.strongText)
                        Text(jobs.isEmpty ? "No background work running" : "\(jobs.count) background tasks")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ControlPanelStyle.mutedText)
                    }
                    Spacer()
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(jobs.isEmpty ? ControlPanelStyle.mutedText : ControlPanelStyle.accent)
                }
                
                if jobs.isEmpty {
                    EmptyJobState()
                } else {
                    HStack(spacing: 10) {
                        ForEach(jobs.prefix(3)) { job in
                            JobStatusChip(job: job)
                        }
                    }
                }
            }
        }
    }
}

private struct EmptyJobState: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green.opacity(0.75))
            Text("System is idle and ready for the next run.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ControlPanelStyle.bodyText)
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(ControlPanelStyle.insetFill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct JobStatusChip: View {
    let job: ControlPanelViewModel.Job
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(job.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ControlPanelStyle.strongText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(job.status.capitalized)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(ControlPanelStyle.mutedText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(ControlPanelStyle.insetFill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    private var statusColor: Color {
        switch job.status.lowercased() {
        case "active", "running", "scheduled": return ControlPanelStyle.accent
        case "waiting", "paused": return .orange
        case "failed", "error": return .red
        case "completed", "done": return .green
        default: return .gray
        }
    }
}

// MARK: - Agent Status Widget (Top Left)
struct AgentStatusWidget: View {
    var version: String = "1.0.0"
    var activeAgents: Int = 1
    var gatewayState: String = "Connected"
    
    var body: some View {
        GlassCard(height: 170) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Gateway")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ControlPanelStyle.strongText)
                        Text("Hermes API")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ControlPanelStyle.mutedText)
                    }
                    Spacer()
                    Image(systemName: "cpu")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ControlPanelStyle.accent)
                        .frame(width: 28, height: 28)
                        .background(ControlPanelStyle.insetFill)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                
                HStack(spacing: 12) {
                    MetricPair(value: version, label: "Version")
                    Divider().frame(height: 34)
                    MetricPair(value: "\(activeAgents)", label: "Active sessions")
                }
                
                HStack(spacing: 10) {
                    StatusBadge(title: "State", value: gatewayState, color: gatewayState.lowercased() == "ok" ? .green : ControlPanelStyle.accent)
                    StatusBadge(title: "Latency", value: "24 ms", color: .green)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ControlPanelStyle.mutedText)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.08))
                            Capsule().fill(ControlPanelStyle.accent).frame(width: proxy.size.width * 0.72)
                        }
                    }
                    .frame(height: 6)
                    Text("Load")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(ControlPanelStyle.mutedText)
                }
            }
        }
    }
}

private struct MetricPair: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ControlPanelStyle.strongText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(ControlPanelStyle.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StatusBadge: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(ControlPanelStyle.mutedText)
                Text(value)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ControlPanelStyle.strongText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(ControlPanelStyle.insetFill)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

// MARK: - Console Home
struct FocusConsoleCard: View {
    let gatewayState: String
    let activeAgents: Int
    let activeJobs: Int
    let latestSession: Session?
    let onOpenChat: () -> Void
    
    var body: some View {
        GlassCard(height: 138) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ControlPanelStyle.accent)
                        Text("Command Focus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ControlPanelStyle.strongText)
                    }
                    
                    Text(statusSummary)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(ControlPanelStyle.strongText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    
                    Text(latestSession?.previewText ?? "Open the chat window to start or continue a Hermes session.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ControlPanelStyle.bodyText)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 10) {
                    StatusCapsule(label: gatewayState.capitalized, color: gatewayState.lowercased() == "disconnected" ? .red : .green)
                    
                    Button(action: onOpenChat) {
                        HStack(spacing: 7) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                            Text("Open Chat")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 12)
                        .background(ControlPanelStyle.accent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var statusSummary: String {
        if gatewayState.lowercased() == "disconnected" {
            return "Hermes is offline"
        }
        
        if activeJobs > 0 {
            return "\(activeJobs) jobs running"
        }
        
        if activeAgents > 0 {
            return "\(activeAgents) active agents"
        }
        
        return "Ready for your next command"
    }
}

private struct StatusCapsule: View {
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ControlPanelStyle.bodyText)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.72))
        .clipShape(Capsule())
    }
}

struct MacVitalsStrip: View {
    let snapshot: ControlPanelViewModel.SystemSnapshot
    
    var body: some View {
        HStack(spacing: 10) {
            CompactInfoTile(title: "CPU", value: "\(snapshot.processorCount)c", subtitle: "Cores", icon: "cpu")
            CompactInfoTile(title: "Memory", value: ControlPanelDisplayFormatter.bytes(snapshot.physicalMemory), subtitle: "Installed", icon: "memorychip")
            CompactInfoTile(title: "Disk", value: diskFreeText, subtitle: "Free", icon: "internaldrive")
            CompactInfoTile(title: "Uptime", value: ControlPanelDisplayFormatter.uptime(snapshot.uptime), subtitle: snapshot.hostName, icon: "clock")
        }
    }
    
    private var diskFreeText: String {
        ControlPanelDisplayFormatter.bytes(snapshot.diskFree)
    }
}

struct HermesVitalsStrip: View {
    let version: String
    let sessions: Int
    let activeAgents: Int
    let tokens: Int
    let cost: Double
    
    var body: some View {
        HStack(spacing: 10) {
            CompactInfoTile(title: "Hermes", value: version, subtitle: "Version", icon: "antenna.radiowaves.left.and.right")
            CompactInfoTile(title: "Agents", value: "\(activeAgents)", subtitle: "Active", icon: "bolt.horizontal")
            CompactInfoTile(title: "Tokens", value: ControlPanelDisplayFormatter.tokens(tokens), subtitle: "This month", icon: "number")
            CompactInfoTile(title: "Spend", value: ControlPanelDisplayFormatter.cost(cost), subtitle: "All sessions", icon: "creditcard")
        }
    }
}

private struct CompactInfoTile: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        GlassCard(height: 70) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ControlPanelStyle.accent)
                    .frame(width: 22, height: 22)
                    .background(ControlPanelStyle.insetFill)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(ControlPanelStyle.mutedText)
                    Text(value)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ControlPanelStyle.strongText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text(subtitle)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(ControlPanelStyle.mutedText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct FoldoutSection<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder let content: () -> Content
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ControlPanelStyle.accent)
                        .frame(width: 24, height: 24)
                        .background(ControlPanelStyle.insetFill)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ControlPanelStyle.strongText)
                        Text(subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ControlPanelStyle.mutedText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(ControlPanelStyle.mutedText)
                }
                .padding(12)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                content()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ControlPanelStyle.border, lineWidth: 1))
    }
}

struct AgentsPage: View {
    let jobs: [ControlPanelViewModel.Job]
    let sessions: [Session]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageHeader(title: "Agents", subtitle: "Active work, child sessions, and background jobs")
            
            HStack(spacing: 12) {
                SessionMetricWidget(title: "Active Jobs", value: "\(jobs.count)", subtitle: "Running or scheduled", icon: "bolt.horizontal")
                SessionMetricWidget(title: "Sessions", value: "\(sessions.count)", subtitle: "Known conversations", icon: "message")
                SessionMetricWidget(title: "Branches", value: "\(childSessionCount)", subtitle: "Child sessions", icon: "point.3.connected.trianglepath.dotted")
            }
            
            FoldoutSection(title: "Running Work", subtitle: jobs.isEmpty ? "No active jobs" : "\(jobs.count) jobs visible", icon: "list.bullet.rectangle") {
                VStack(spacing: 8) {
                    if jobs.isEmpty {
                        EmptyInlineMessage(text: "No agent jobs are currently active.")
                    } else {
                        ForEach(jobs.prefix(5)) { job in
                            InlineRow(title: job.name, subtitle: job.status.capitalized, icon: "bolt.horizontal")
                        }
                    }
                }
            }
            
            FoldoutSection(title: "Session Branches", subtitle: "Prepared for forked sub-agent views", icon: "arrow.triangle.branch") {
                VStack(spacing: 8) {
                    if sessions.isEmpty {
                        EmptyInlineMessage(text: "No sessions have been loaded yet.")
                    } else {
                        ForEach(sessions.prefix(4)) { session in
                            InlineRow(title: session.title ?? "Session \(session.id.prefix(6))", subtitle: session.previewText, icon: "message")
                        }
                    }
                }
            }
        }
    }
    
    private var childSessionCount: Int {
        sessions.filter { $0.parentSessionId != nil }.count
    }
}

struct SessionsPage: View {
    let sessions: [Session]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageHeader(title: "Sessions", subtitle: "Recent Hermes conversations and continuity")
            
            VStack(spacing: 8) {
                if sessions.isEmpty {
                    EmptyInlineMessage(text: "No sessions available from Hermes yet.")
                } else {
                    ForEach(sessions.prefix(6)) { session in
                        InlineRow(
                            title: session.title ?? "Session \(session.id.prefix(8))",
                            subtitle: session.previewText,
                            icon: session.parentSessionId == nil ? "message" : "arrow.triangle.branch"
                        )
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(ControlPanelStyle.border, lineWidth: 1))
        }
    }
}

struct SystemPage: View {
    let snapshot: ControlPanelViewModel.SystemSnapshot
    let gatewayState: String
    let version: String
    let jobs: [ControlPanelViewModel.Job]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageHeader(title: "System", subtitle: "Mac health and Hermes runtime details")
            
            MacVitalsStrip(snapshot: snapshot)
            
            FoldoutSection(title: "Mac Details", subtitle: snapshot.systemVersion, icon: "desktopcomputer") {
                VStack(spacing: 8) {
                    InlineRow(title: "Host", subtitle: snapshot.hostName, icon: "display")
                    InlineRow(title: "Physical Memory", subtitle: ControlPanelDisplayFormatter.bytes(snapshot.physicalMemory), icon: "memorychip")
                    InlineRow(title: "Disk Free", subtitle: "\(ControlPanelDisplayFormatter.bytes(snapshot.diskFree)) of \(ControlPanelDisplayFormatter.bytes(snapshot.diskTotal))", icon: "internaldrive")
                }
            }
            
            FoldoutSection(title: "Hermes Runtime", subtitle: "\(gatewayState.capitalized) · \(version)", icon: "antenna.radiowaves.left.and.right") {
                VStack(spacing: 8) {
                    InlineRow(title: "Gateway", subtitle: gatewayState.capitalized, icon: "point.3.filled.connected.trianglepath.dotted")
                    InlineRow(title: "Version", subtitle: version, icon: "number")
                    InlineRow(title: "Cron Jobs", subtitle: "\(jobs.count) configured", icon: "calendar.badge.clock")
                }
            }
        }
    }
}

private struct PageHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ControlPanelStyle.strongText)
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ControlPanelStyle.mutedText)
        }
    }
}

private struct InlineRow: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ControlPanelStyle.accent)
                .frame(width: 24, height: 24)
                .background(ControlPanelStyle.insetFill)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ControlPanelStyle.strongText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(ControlPanelStyle.mutedText)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(10)
        .background(ControlPanelStyle.insetFill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct EmptyInlineMessage: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .foregroundColor(.green.opacity(0.75))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ControlPanelStyle.bodyText)
            Spacer()
        }
        .padding(10)
        .background(ControlPanelStyle.insetFill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private extension Session {
    var previewText: String {
        preview ?? status ?? "No preview available"
    }
}

// MARK: - Legacy Job Toggle Widget
struct JobToggleWidget: View {
    let title: String
    let subtitle: String
    @State var isOn: Bool
    
    var body: some View {
        GlassCard(height: 90) {
            VStack(alignment: .leading) {
                HStack {
                    Circle()
                        .fill(ControlPanelStyle.insetFill)
                        .frame(width: 28, height: 28)
                        .overlay(Image(systemName: "circle.grid.2x2.fill").foregroundColor(isOn ? ControlPanelStyle.accent : ControlPanelStyle.mutedText).font(.system(size: 10)))
                    Spacer()
                    Toggle("", isOn: $isOn)
                        .toggleStyle(SwitchToggleStyle(tint: ControlPanelStyle.accent))
                        .labelsHidden()
                        .scaleEffect(0.6)
                }
                Spacer()
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(ControlPanelStyle.mutedText)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ControlPanelStyle.strongText)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Bottom Tab Bar
struct BottomTabBar: View {
    @Binding var selectedTab: ControlPanelTab
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(ControlPanelTab.allCases) { tab in
                tabButton(tab)
            }
            
            Button(action: {
                // Add action here
            }) {
                Image(systemName: "plus")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(ControlPanelStyle.accent)
                    .clipShape(Circle())
                    .shadow(color: ControlPanelStyle.accent.opacity(0.24), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, 4)
        }
        .padding(6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.72))
                .background(.regularMaterial, in: Capsule())
        )
        .overlay(
            Capsule().stroke(ControlPanelStyle.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
    }
    
    private func tabButton(_ tab: ControlPanelTab) -> some View {
        let isSelected = selectedTab == tab
        
        return Button(action: {
            withAnimation { selectedTab = tab }
        }) {
            Text(tab.title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? ControlPanelStyle.strongText : ControlPanelStyle.mutedText)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.white.opacity(0.84) : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Side Navigation Bar
struct SideNavigationBar: View {
    @Binding var selectedTab: ControlPanelTab
    
    var body: some View {
        VStack(spacing: 14) {
            ForEach(ControlPanelTab.allCases) { tab in
                Button(action: {
                    withAnimation { selectedTab = tab }
                }) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(selectedTab == tab ? ControlPanelStyle.accent : ControlPanelStyle.mutedText)
                        .frame(width: 34, height: 34)
                        .background(selectedTab == tab ? Color.white.opacity(0.86) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer()
            Button(action: {
                
            }) {
                Circle()
                    .fill(Color.white.opacity(0.82))
                    .frame(width: 34, height: 34)
                    .overlay(Image(systemName: "person.fill").foregroundColor(ControlPanelStyle.bodyText).font(.system(size: 14)))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.64))
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(ControlPanelStyle.border, lineWidth: 1)
        )
        .frame(height: 318)
    }
}
