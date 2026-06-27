import Foundation

// MARK: - HermesProvider
// 负责：探测 Hermes 路径 → 启动 tui_gateway 子进程 → JSON-RPC 2.0 通信
// 协议：每行一个 JSON 对象，stdin 发请求，stdout 收响应 / 事件

actor HermesProvider {

    // MARK: - 连接状态

    enum ConnectionState: Equatable {
        case disconnected
        case detecting
        case connecting
        case ready          // gateway.ready 已收到，可以发 RPC
        case failed(reason: String)
    }

    private(set) var state: ConnectionState = .disconnected

    // MARK: - 内部状态

    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutTask: Task<Void, Never>?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// 待处理的 RPC 请求：id → continuation
    private var pendingRequests: [String: CheckedContinuation<JSONValue, Error>] = [:]

    /// 等待 gateway.ready 的一次性信号
    private var gatewayReadyContinuation: CheckedContinuation<Void, Never>?

    /// 向 AgentBridge 推送原始 RPC 消息（事件 + 错误）
    private var eventContinuation: AsyncStream<RPCMessage>.Continuation?
    nonisolated let eventStream: AsyncStream<RPCMessage>

    // MARK: - Hermes 安装信息

    struct HermesInstallation: Sendable {
        let hermesDir: URL
        let pythonPath: String
        let entryScript: URL
        let hermesHome: URL
    }

    private var installation: HermesInstallation?

    // MARK: - 初始化

    init() {
        var cont: AsyncStream<RPCMessage>.Continuation?
        eventStream = AsyncStream<RPCMessage>(bufferingPolicy: .bufferingNewest(256)) { c in
            cont = c
        }
        eventContinuation = cont
    }

    // MARK: - 公开 API

    func connect() async throws {
        guard case .disconnected = state else { return }

        state = .detecting
        let install = try await detectHermes()
        self.installation = install

        state = .connecting
        try await launchGateway(install: install)
        // launchGateway 会等待 gateway.ready 后才返回
    }

    func disconnect() {
        stdoutTask?.cancel()
        stdoutTask = nil

        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        process = nil
        stdinHandle = nil

        for (_, cont) in pendingRequests {
            cont.resume(throwing: HermesError.disconnected)
        }
        pendingRequests.removeAll()

        gatewayReadyContinuation?.resume()   // 解除可能在等的 connect()
        gatewayReadyContinuation = nil

        state = .disconnected
    }

    /// 发送 JSON-RPC 请求，等待响应（带 30 秒超时）
    func request(method: String, params: JSONValue = .object([:])) async throws -> JSONValue {
        guard let handle = stdinHandle else {
            throw HermesError.notConnected
        }

        let reqId = UUID().uuidString
        let req = RPCRequest(id: reqId, method: method, params: params)
        let data = try encoder.encode(req)
        let line = (String(data: data, encoding: .utf8) ?? "") + "\n"
        handle.write(line.data(using: .utf8)!)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pendingRequests[reqId] = continuation
                // 超时保护
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(30))
                    await self?.timeoutRequest(id: reqId)
                }
            }
        } onCancel: {
            Task { await self.cancelRequest(id: reqId) }
        }
    }

    // MARK: - 高层 RPC 封装

    func createSession() async throws -> String {
        let result = try await request(method: "session.create")
        guard let sid = result["session_id"]?.stringValue else {
            throw HermesError.invalidResponse("session.create 缺少 session_id")
        }
        return sid
    }

    func submitPrompt(_ text: String, sessionId: String) async throws {
        _ = try await request(
            method: "prompt.submit",
            params: .object([
                "session_id": .string(sessionId),
                "text": .string(text)   // Hermes tui_gateway 用 "text" 字段
            ])
        )
    }

    func sessionHistory(sessionId: String) async throws -> JSONValue {
        try await request(
            method: "session.history",
            params: .object(["session_id": .string(sessionId)])
        )
    }

    func listSessions() async throws -> [JSONValue] {
        let result = try await request(method: "session.list")
        return result.arrayValue ?? []
    }

    func respondApproval(approvalId: String, approved: Bool) async throws {
        _ = try await request(
            method: "approval.respond",
            params: .object([
                "approval_id": .string(approvalId),
                "approved": .bool(approved)
            ])
        )
    }

    // MARK: - Private: 探测 Hermes

    private func detectHermes() async throws -> HermesInstallation {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates: [URL] = [
            home.appendingPathComponent("Hermes"),
            home.appendingPathComponent("hermes"),
            URL(fileURLWithPath: "/usr/local/lib/hermes"),
            URL(fileURLWithPath: "/opt/homebrew/lib/hermes"),
        ]

        var hermesDir: URL?
        for candidate in candidates {
            let entry = candidate.appendingPathComponent("tui_gateway/entry.py")
            if FileManager.default.fileExists(atPath: entry.path) {
                hermesDir = candidate
                break
            }
        }
        guard let hermesDir else { throw HermesError.notInstalled }

        let pythonCandidates = [
            hermesDir.appendingPathComponent(".venv/bin/python3").path,
            "/opt/anaconda3/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ]
        let python = pythonCandidates.first {
            FileManager.default.isExecutableFile(atPath: $0)
        } ?? "/usr/bin/python3"

        return HermesInstallation(
            hermesDir: hermesDir,
            pythonPath: python,
            entryScript: hermesDir.appendingPathComponent("tui_gateway/entry.py"),
            hermesHome: home.appendingPathComponent(".hermes")
        )
    }

    // MARK: - Private: 启动子进程

    private func launchGateway(install: HermesInstallation) async throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: install.pythonPath)
        proc.arguments = ["-u", install.entryScript.path]  // -u: unbuffered stdout
        proc.currentDirectoryURL = install.hermesDir        // 保证相对 import 正常

        var env = ProcessInfo.processInfo.environment
        env["PYTHONPATH"]      = install.hermesDir.path
        env["PYTHONUNBUFFERED"] = "1"
        env["HERMES_HOME"]     = install.hermesHome.path
        proc.environment = env

        let stdinPipe  = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardInput  = stdinPipe
        proc.standardOutput = stdoutPipe
        proc.standardError  = stderrPipe

        proc.terminationHandler = { [weak self] _ in
            Task { await self?.handleProcessExit() }
        }

        try proc.run()
        self.process     = proc
        self.stdinHandle = stdinPipe.fileHandleForWriting

        // stderr 日志（仅 DEBUG）
        Task.detached(priority: .background) {
            for await line in pipeLines(stderrPipe.fileHandleForReading) {
                #if DEBUG
                print("[Hermes stderr] \(line)")
                #endif
            }
        }

        // stdout 读取循环
        stdoutTask = Task {
            await self.readLoop(pipe: stdoutPipe)
        }

        // 等待 gateway.ready（最多 15 秒）
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await Task.sleep(for: .seconds(15))
                throw HermesError.gatewayTimeout
            }
            group.addTask { [weak self] in
                guard let self else { return }
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    Task { await self.setGatewayReadyContinuation(cont) }
                }
            }
            _ = try await group.next()
            group.cancelAll()
        }

        state = .ready
    }

    private func setGatewayReadyContinuation(_ cont: CheckedContinuation<Void, Never>) {
        gatewayReadyContinuation = cont
    }

    // MARK: - Private: 读取循环

    private func readLoop(pipe: Pipe) async {
        for await line in pipeLines(pipe.fileHandleForReading) {
            guard !line.isEmpty else { continue }
            await handleLine(line)
            if Task.isCancelled { break }
        }
        await handleProcessExit()
    }

    private func handleLine(_ line: String) async {
        print("[RPC RAW] \(line)") // 临时增加强制打印，用于抓取后台通讯报文
        guard let data = line.data(using: .utf8),
              let rawObj = try? decoder.decode([String: JSONValue].self, from: data),
              let msg = RPCMessage(from: rawObj)
        else {
            #if DEBUG
            print("[HermesProvider] 无法解析：\(line.prefix(200))")
            #endif
            return
        }

        switch msg {
        case .response(let id, let result):
            if let cont = pendingRequests.removeValue(forKey: id) {
                cont.resume(returning: result)
            }

        case .error(let id, let code, let message):
            if let id, let cont = pendingRequests.removeValue(forKey: id) {
                cont.resume(throwing: HermesError.rpcError(code: code, message: message))
            }
            eventContinuation?.yield(msg)

        case .event(let type, _, _):
            // gateway.ready：唤醒 connect() 的等待
            if type == "gateway.ready" {
                gatewayReadyContinuation?.resume()
                gatewayReadyContinuation = nil
            }
            eventContinuation?.yield(msg)
        }
    }

    private func handleProcessExit() async {
        guard state != .disconnected && state != .failed(reason: "") else { return }
        // 幂等：避免 terminationHandler + readLoop 双重触发
        guard process != nil else { return }
        process = nil
        state = .failed(reason: "Hermes 进程已退出")
        eventContinuation?.yield(.event(type: "gateway.disconnected", sessionId: nil, payload: .null))

        for (_, cont) in pendingRequests {
            cont.resume(throwing: HermesError.disconnected)
        }
        pendingRequests.removeAll()
    }

    private func timeoutRequest(id: String) {
        if let cont = pendingRequests.removeValue(forKey: id) {
            cont.resume(throwing: HermesError.timeout)
        }
    }

    private func cancelRequest(id: String) {
        if let cont = pendingRequests.removeValue(forKey: id) {
            cont.resume(throwing: CancellationError())
        }
    }
}

// MARK: - 错误类型

enum HermesError: LocalizedError {
    case notInstalled
    case notConnected
    case disconnected
    case encodingFailed
    case invalidResponse(String)
    case rpcError(code: Int, message: String)
    case timeout
    case gatewayTimeout

    var errorDescription: String? {
        switch self {
        case .notInstalled:           return "未找到 Hermes（需要 ~/Hermes/tui_gateway/entry.py）"
        case .notConnected:           return "Hermes 未连接"
        case .disconnected:           return "Hermes 连接已断开"
        case .encodingFailed:         return "请求编码失败"
        case .invalidResponse(let m): return "无效响应：\(m)"
        case .rpcError(let c, let m): return "RPC 错误 \(c)：\(m)"
        case .timeout:                return "请求超时（30s）"
        case .gatewayTimeout:         return "Gateway 启动超时（15s）"
        }
    }
}

// MARK: - Pipe 行读取（readabilityHandler 版本）
// readabilityHandler 在 Obj-C 线程调用，不属于 Swift 并发上下文
// 用 class 包装 buffer 以满足 Swift 6 严格并发检查

private final class LineBuffer: @unchecked Sendable {
    var data = Data()
}

private func pipeLines(_ fileHandle: FileHandle) -> AsyncStream<String> {
    AsyncStream<String>(bufferingPolicy: .bufferingNewest(1024)) { continuation in
        let buf = LineBuffer()

        fileHandle.readabilityHandler = { fh in
            let chunk = fh.availableData

            if chunk.isEmpty {
                // 真正的 EOF
                if !buf.data.isEmpty, let last = String(data: buf.data, encoding: .utf8) {
                    continuation.yield(last)
                    buf.data = Data()
                }
                fh.readabilityHandler = nil
                continuation.finish()
                return
            }

            buf.data.append(chunk)

            // 切割换行，逐行 yield
            while let nl = buf.data.range(of: Data([0x0a])) {
                let lineData = buf.data[buf.data.startIndex..<nl.lowerBound]
                if let line = String(data: lineData, encoding: .utf8) {
                    continuation.yield(line)
                }
                buf.data.removeSubrange(buf.data.startIndex...nl.lowerBound)
            }
        }

        continuation.onTermination = { _ in
            fileHandle.readabilityHandler = nil
        }
    }
}

