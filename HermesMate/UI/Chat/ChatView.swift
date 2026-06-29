import SwiftUI

// MARK: - ChatView
// 主聊天窗口：消息列表 + 输入框 + 状态指示器，使用 Liquid Glass 风格

struct ChatView: View {
    let agentBridge: AgentBridge
    var showBackground: Bool = true

    @State private var inputText = ""
    @State private var isSending = false
    @FocusState private var inputFocused: Bool
    @State private var errorMessage: String?

    private var sessionStore: SessionStore { agentBridge.sessionStore }

    var body: some View {
        ZStack {
            // 流体背景
            if showBackground {
                LiquidBackgroundView()
            }

            VStack(spacing: 0) {
                // 顶部悬浮栏
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .zIndex(1)

                // 消息列表
                messageList

                // 底部悬浮输入区域
                inputArea
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                    .padding(.top, 8)
                    .zIndex(1)
            }
        }
        .frame(minWidth: 500, minHeight: 250)
        .onAppear { inputFocused = true }
    }

    // MARK: - 顶部标题栏（Liquid Glass 胶囊）

    private var headerBar: some View {
        HStack(spacing: 12) {
            // Hermes 状态指示器
            HStack(spacing: 6) {
                Circle()
                    .fill(connectionStateColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: connectionStateColor.opacity(0.6), radius: 4)
                    .animation(.easeInOut(duration: 0.3), value: agentBridge.connectionState)

                Text(agentBridge.connectionState.displayText)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                    
                if case let .connected(_, usedVal, maxVal, _) = agentBridge.connectionState, let usedAmount = usedVal, let maxAmount = maxVal, maxAmount > 0 {
                    Text("|")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .padding(.horizontal, 2)
                    
                    let usedStr = ChatView.formatUsage(usedAmount)
                    let maxStr = ChatView.formatUsage(maxAmount)
                    Text("\(usedStr)/\(maxStr)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    Text("|")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .padding(.horizontal, 2)
                    
                    let ratio = min(Swift.max(Double(usedAmount) / Double(maxAmount), 0), 1)
                    let barColor = ratio > 0.9 ? Color.red : (ratio > 0.75 ? Color.orange : Color.secondary)
                    
                    HStack(spacing: 6) {
                        HStack(spacing: 2) {
                            Text("[")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(barColor)
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.2))
                                    Rectangle()
                                        .fill(barColor)
                                        .frame(width: geo.size.width * CGFloat(ratio))
                                }
                            }
                            .frame(width: 60, height: 8)
                            
                            Text("]")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(barColor)
                        }
                        
                        Text("\(Int(ratio * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(barColor)
                    }
                }
            }

            Spacer()

            // Agent 状态 pill
            agentStatePill

            Spacer()

            // 标题
            Text("HermesMate")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .liquidGlass(cornerRadius: 20, material: .ultraThinMaterial)
    }

    private var connectionStateColor: Color {
        switch agentBridge.connectionState {
        case .connected:    return .green
        case .connecting:   return .orange
        case .disconnected: return .gray
        case .failed:       return .red
        }
    }

    private var agentStatePill: some View {
        Group {
            switch sessionStore.agentState {
            case .thinking:
                StatePill(label: "思考中", icon: "brain.head.profile", color: .purple, animated: true)
            case .working(let tool):
                StatePill(label: "执行 \(tool)", icon: "gearshape.fill", color: .blue, animated: true)
            case .waitingApproval(let tool, _):
                StatePill(label: "等待授权：\(tool)", icon: "lock.shield", color: .orange, animated: false)
            case .success:
                StatePill(label: "完成", icon: "checkmark.circle.fill", color: .green, animated: false)
            case .failed:
                StatePill(label: "出错", icon: "exclamationmark.triangle.fill", color: .red, animated: false)
            case .needsInput:
                StatePill(label: "需要输入", icon: "hand.raised", color: .yellow, animated: false)
            case .idle:
                EmptyView()
            }
        }
        .animation(.spring(duration: 0.3), value: sessionStore.agentState == .idle)
    }

    // MARK: - 消息列表

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if sessionStore.activeMessages.isEmpty {
                        emptyState
                    } else {
                        Spacer().frame(height: 10)
                        ForEach(sessionStore.activeMessages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        Spacer().frame(height: 10)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onChange(of: sessionStore.activeMessages.count) { _, _ in
                if let last = sessionStore.activeMessages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: sessionStore.activeMessages.last?.content) { _, _ in
                if let last = sessionStore.activeMessages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 80)

            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse, isActive: agentBridge.connectionState == .connecting)

            Text("Hermes 已就绪")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)

            Text("发送消息开始对话")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 悬浮输入区域

    private var inputArea: some View {
        VStack(spacing: 8) {
            // 错误提示
            if let err = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        withAnimation { errorMessage = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .liquidGlass(cornerRadius: 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .center, spacing: 12) {
                // 文本输入框
                TextField("与 Hermes 交谈…", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .lineLimit(1...8)
                    .focused($inputFocused)
                    .onSubmit {
                        if !NSEvent.modifierFlags.contains(.shift) {
                            sendMessage()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                // 发送按钮
                Button(action: sendMessage) {
                    Group {
                        if isSending {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(canSend
                                ? LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                            )
                            .shadow(color: canSend ? .purple.opacity(0.4) : .clear, radius: 4, y: 2)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .animation(.spring(duration: 0.2), value: canSend)
                .padding(.trailing, 10)
            }
            .liquidGlass(cornerRadius: 24)
        }
    }

    // MARK: - 逻辑

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSending
            && agentBridge.connectionState.isConnected
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        inputText = ""
        isSending = true
        errorMessage = nil

        Task {
            do {
                try await agentBridge.sendMessage(text)
            } catch {
                withAnimation {
                    errorMessage = error.localizedDescription
                }
            }
            isSending = false
        }
    }
}

// MARK: - 消息气泡

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // 角色标签
                if message.role == .assistant {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 11))
                            .foregroundStyle(.purple)
                        Text("Hermes")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.8))
                    }
                    .padding(.leading, 4)
                }

                // 消息内容
                VStack(alignment: .leading, spacing: 0) {
                    let contentStr = message.content.isEmpty && message.isStreaming ? " " : message.content
                    let attrStr = (try? AttributedString(
                        markdown: contentStr,
                        options: .init(allowsExtendedAttributes: true, interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible)
                    )) ?? AttributedString(contentStr)
                    
                    Text(attrStr)
                        .font(.system(size: 15))
                        .foregroundStyle(message.role == .user ? .white : .primary)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)

                    // 流式光标
                    if message.isStreaming {
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                Circle()
                                    .fill(Color.primary.opacity(0.5))
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(message.isStreaming ? 1.0 : 0.5)
                                    .animation(
                                        .easeInOut(duration: 0.5)
                                            .repeatForever()
                                            .delay(Double(i) * 0.15),
                                        value: message.isStreaming
                                    )
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .modifier(BubbleStyleModifier(isUser: message.role == .user))
            }

            if message.role != .user { Spacer(minLength: 40) }
        }
        .transition(.asymmetric(
            insertion: .move(edge: message.role == .user ? .trailing : .leading).combined(with: .opacity),
            removal: .opacity
        ))
    }
}



struct BubbleStyleModifier: ViewModifier {
    let isUser: Bool
    
    func body(content: Content) -> some View {
        if isUser {
            content
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .indigo.opacity(0.3), radius: 8, y: 4)
        } else {
            content
                .liquidGlass(cornerRadius: 18)
        }
    }
}

// MARK: - StatePill（Agent 状态指示器）

struct StatePill: View {
    let label: String
    let icon: String
    let color: Color
    let animated: Bool

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .scaleEffect(pulse ? 1.15 : 1.0)

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
                .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
                .shadow(color: color.opacity(0.2), radius: 4, y: 2)
        )
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
}

extension ChatView {
    static func formatUsage(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000.0).replacingOccurrences(of: ".0M", with: "M")
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000.0).replacingOccurrences(of: ".0K", with: "K")
        } else {
            return "\(value)"
        }
    }
}

