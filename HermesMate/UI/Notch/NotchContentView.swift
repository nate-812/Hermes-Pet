import SwiftUI

struct NotchContentView: View {
    @ObservedObject var coordinator: NotchStateCoordinator
    
    // Geometry constants
    private let defaultWidth: CGFloat = 240 // 进一步加宽以确保两侧指示灯不被物理刘海遮挡
    private let defaultHeight: CGFloat = 32 // 保持原高度不扩充
    
    private let hoverWidth: CGFloat = 250
    private let hoverHeight: CGFloat = 34
    
    private let summaryWidth: CGFloat = 360
    private let summaryHeight: CGFloat = 72
    
    private let detailWidth: CGFloat = 400
    private let detailHeight: CGFloat = 200
    
    private var isClosed: Bool {
        coordinator.notchSize == .closed
    }
    
    private var isHovering: Bool {
        coordinator.notchSize == .hovering
    }
    
    private var currentWidth: CGFloat {
        switch coordinator.notchSize {
        case .closed: return defaultWidth
        case .hovering: return hoverWidth
        case .openSummary: return defaultWidth // 只向下延伸，宽度不变
        case .openDetail: return detailWidth
        }
    }
    
    private var cornerRadius: CGFloat {
        isClosed || isHovering ? 8 : 16 // 减小圆角弧度，显得更硬朗
    }
    
    @State private var isBreathing: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Hit Area + Indicator Lights
            ZStack {
                // We use this as the hit testing area for hover/tap
                Color.white.opacity(0.001)
                    .frame(width: defaultWidth, height: defaultHeight)
                    .onHover { hovering in
                        coordinator.handleHover(isHovering: hovering)
                    }
                    .onTapGesture {
                        coordinator.handleTap()
                    }
                
                // Always show indicator lights
                HStack {
                    Spacer()
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: indicatorColor.opacity(0.8), radius: 3)
                        .opacity(coordinator.activityState == .thinking ? (isBreathing ? 0.6 : 1.0) : 1.0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                isBreathing = true
                            }
                        }
                }
                .padding(.trailing, 16) // 减小 padding，让灯泡更加靠右，避开物理刘海
                .frame(width: currentWidth, height: defaultHeight)
            }
            .frame(height: isHovering ? hoverHeight : defaultHeight)
            
            // Actual dynamic content placed BELOW the physical notch
            if coordinator.notchSize == .openSummary {
                summaryView
            } else if coordinator.notchSize == .openDetail {
                detailView
            }
        }
        .frame(width: currentWidth) // 限制宽度，高度由内容撑开
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: cornerRadius,
                bottomTrailingRadius: cornerRadius,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color.black)
            .shadow(color: Color.black.opacity(0.5), radius: 8, y: 4)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, -2) // Slight offset to merge with hardware notch seamlessly
        .animation(.spring(response: 0.42, dampingFraction: 0.75, blendDuration: 0), value: coordinator.notchSize)
        .animation(.spring(response: 0.42, dampingFraction: 0.75, blendDuration: 0), value: coordinator.currentText)
    }
    
    // MARK: - Subviews
    
    private var summaryView: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(displayText)
                .foregroundColor(.white)
                .font(.system(size: 13, weight: .medium))
                .lineSpacing(2)
                .lineLimit(4) // 自动高度，最多不超过 4 行
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 10)
        .transition(
            .scale(scale: 0.95, anchor: .top)
            .combined(with: .opacity)
            .animation(.smooth(duration: 0.35))
        )
    }
    
    private var detailView: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left Side: The Island Pet (Pikachu)
            PikachuPetView(state: coordinator.activityState)
            
            // Right Side: Agent Details
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    stateIcon
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .semibold))
                    Text("HermesMate Agent")
                        .foregroundColor(.white)
                        .font(.headline)
                    Spacer()
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 8, height: 8)
                }
                
                Divider().background(Color.white.opacity(0.3))
                
                Text("当前活动: \(activityText)")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.subheadline)
                
                Text(displayText.isEmpty ? "就绪..." : displayText)
                    .foregroundColor(.white)
                    .font(.body)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
            }
        }
        .padding(20)
        .frame(height: detailHeight - defaultHeight)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .transition(
            .scale(scale: 0.9, anchor: .top)
            .combined(with: .opacity)
            .animation(.smooth(duration: 0.35))
        )
    }
    
    // MARK: - Helpers
    
    private var indicatorColor: Color {
        switch coordinator.activityState {
        case .idle: return .green
        case .thinking: return Color(red: 1.0, green: 0.3, blue: 1.0) // Extremely bright neon purple
        case .speaking: return .blue
        case .toolRunning: return .orange
        case .waitingApproval: return .yellow
        }
    }
    
    @ViewBuilder
    private var stateIcon: some View {
        switch coordinator.activityState {
        case .thinking:
            Image(systemName: "brain")
        case .speaking:
            Image(systemName: "text.bubble.fill")
        case .toolRunning:
            Image(systemName: "hammer.fill")
        case .waitingApproval:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
        case .idle:
            Image(systemName: "bolt.fill")
                .foregroundColor(.gray)
        }
    }
    
    private var activityText: String {
        switch coordinator.activityState {
        case .idle: return "空闲 (Idle)"
        case .thinking: return "思考中 (Thinking)"
        case .speaking: return "生成回复 (Speaking)"
        case .toolRunning: return "执行工具 (Tool)"
        case .waitingApproval: return "等待用户确认 (Waiting)"
        }
    }
    
    private var displayText: String {
        switch coordinator.activityState {
        case .thinking:
            return "思考中..."
        case .speaking:
            return coordinator.currentText.isEmpty ? "..." : coordinator.currentText
        case .toolRunning:
            return "运行工具: \(coordinator.currentToolName)"
        case .waitingApproval:
            return "需要确认: \(coordinator.currentToolName)"
        case .idle:
            // 任务结束后，留存上一条消息，直到 4 秒后刘海收起
            return coordinator.currentText.isEmpty ? "" : coordinator.currentText
        }
    }
}

#Preview {
    // Just a basic preview shell
    VStack {
        // Needs a coordinator with mocked EventBus, skipped here
    }
}
