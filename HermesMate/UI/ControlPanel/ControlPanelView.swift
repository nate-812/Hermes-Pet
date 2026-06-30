import SwiftUI

struct ControlPanelView: View {
    var onOpenChat: () -> Void = {}
    
    @State private var viewModel = ControlPanelViewModel()
    @State private var selectedTab: ControlPanelTab = .home
    
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            SideNavigationBar(selectedTab: $selectedTab)
            
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.76))
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.14), radius: 28, x: 0, y: 18)
                
                content
                    .padding(22)
                    .padding(.bottom, 28)
                
                BottomTabBar(selectedTab: $selectedTab)
                    .offset(y: 16)
            }
            .frame(width: 760, height: 460)
            .overlay(
                Group {
                    if viewModel.showToolGuard {
                        ToolGuardOverlay(
                            onApprove: { viewModel.showToolGuard = false },
                            onDeny: { viewModel.showToolGuard = false }
                        )
                    }
                }
            )
        }
        .padding(40)
        .environment(\.colorScheme, .light)
    }
    
    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .home:
            homeContent
        case .agents:
            AgentsPage(jobs: viewModel.activeJobs, sessions: viewModel.sessions)
        case .sessions:
            SessionsPage(sessions: viewModel.sessions)
        case .system:
            SystemPage(
                snapshot: viewModel.systemSnapshot,
                gatewayState: viewModel.gatewayState,
                version: viewModel.agentVersion,
                jobs: viewModel.jobs
            )
        }
    }
    
    private var homeContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HermesMate")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black.opacity(0.88))
                    Text("Mac status and Hermes command center")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.black.opacity(0.48))
                }
                
                Spacer()
                
                Text(selectedTab.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black.opacity(0.58))
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.68))
                    .clipShape(Capsule())
            }
            
            FocusConsoleCard(
                gatewayState: viewModel.gatewayState,
                activeAgents: viewModel.activeAgents,
                activeJobs: viewModel.activeJobs.count,
                latestSession: viewModel.latestSession,
                onOpenChat: onOpenChat
            )
            
            MacVitalsStrip(snapshot: viewModel.systemSnapshot)
            
            HermesVitalsStrip(
                version: viewModel.agentVersion,
                sessions: viewModel.sessions.count,
                activeAgents: viewModel.activeAgents,
                tokens: viewModel.totalTokens,
                cost: viewModel.totalCost
            )
            
            HStack(spacing: 10) {
                FoldoutSection(title: "Tool Work", subtitle: "\(viewModel.jobs.count) configured jobs", icon: "calendar.badge.clock") {
                    VStack(spacing: 8) {
                        if viewModel.jobs.isEmpty {
                            Text("No scheduled jobs loaded.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.black.opacity(0.58))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(viewModel.jobs.prefix(2)) { job in
                                Text("\(job.name) · \(job.status.capitalized)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.black.opacity(0.68))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                
                FoldoutSection(title: "Usage Trend", subtitle: "Last 7 days", icon: "chart.bar.xaxis") {
                    TokenChartWidget(data: viewModel.chartData, labels: viewModel.chartLabels)
                        .frame(height: 170)
                }
            }
        }
    }
}
