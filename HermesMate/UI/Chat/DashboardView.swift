import SwiftUI

struct DashboardView: View {
    let agentBridge: AgentBridge
    
    @State private var selectedTab: String = "Chat"
    
    var body: some View {
        ZStack {
            // Global Liquid Background for the entire Dashboard
            LiquidBackgroundView()
            
            HStack(spacing: 0) {
                // Sidebar
                sidebar
                    .frame(width: 220)
                    .background(Material.ultraThinMaterial.opacity(0.8))
                    
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Main Content
                ZStack {
                    if selectedTab == "Chat" {
                        ChatView(agentBridge: agentBridge, showBackground: false)
                    } else {
                        placeholderView(for: selectedTab)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.6),
                                .white.opacity(0.1),
                                .white.opacity(0.1),
                                .white.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.overlay)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .frame(minWidth: 800, minHeight: 500)
        // ESC to close (Accessibility / Light dismiss guidelines)
        .onCommand(#selector(NSResponder.cancelOperation(_:))) {
            NSApp.keyWindow?.close()
        }
    }
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24))
                    .foregroundStyle(.purple)
                Text("HermesMate")
                    .font(.system(size: 18, weight: .bold))
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            
            // Navigation
            VStack(spacing: 4) {
                sidebarButton(title: "Chat", icon: "message", id: "Chat")
                sidebarButton(title: "Knowledge Base", icon: "book.pages", id: "Knowledge")
                sidebarButton(title: "Tools", icon: "wrench.and.screwdriver", id: "Tools")
                sidebarButton(title: "History", icon: "clock.arrow.circlepath", id: "History")
                sidebarButton(title: "Settings", icon: "gearshape", id: "Settings")
            }
            .padding(.horizontal, 10)
            
            Spacer()
            
            // Quick Actions Widgets Placeholder
            VStack(alignment: .leading, spacing: 10) {
                Text("QUICK ACTIONS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                
                HStack {
                    quickActionButton(icon: "terminal", color: .blue)
                    quickActionButton(icon: "doc.text", color: .red)
                    quickActionButton(icon: "sparkles", color: .purple)
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
    }
    
    private func sidebarButton(title: String, icon: String, id: String) -> some View {
        Button(action: { selectedTab = id }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(selectedTab == id ? Color.white.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(selectedTab == id ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }
    
    private func quickActionButton(icon: String, color: Color) -> some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .frame(width: 40, height: 40)
                .background(color.opacity(0.2))
                .foregroundStyle(color)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func placeholderView(for tab: String) -> some View {
        VStack {
            Image(systemName: "hammer.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("\(tab) is under construction")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 10)
        }
    }
}
