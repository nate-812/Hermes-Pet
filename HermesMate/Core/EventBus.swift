import Foundation

// MARK: - EventBus
// 所有 UI 状态的唯一来源，广播 HermesEvent 给所有订阅者
// 使用 AsyncStream + actor 保证线程安全

actor EventBus {

    // MARK: - 订阅者管理

    private struct Subscriber {
        let id: UUID
        let continuation: AsyncStream<HermesEvent>.Continuation
    }

    private var subscribers: [Subscriber] = []

    // MARK: - 事件历史缓存（最近 500 条）

    private(set) var recentEvents: [HermesEvent] = []
    private let maxCachedEvents = 500

    // MARK: - 订阅 API

    /// 返回一个 AsyncStream，调用方通过 for await 消费事件
    func subscribe() -> AsyncStream<HermesEvent> {
        AsyncStream<HermesEvent> { [weak self] continuation in
            let id = UUID()
            let sub = Subscriber(id: id, continuation: continuation)
            Task { [weak self] in
                await self?.addSubscriber(sub)
            }
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.removeSubscriber(id: id)
                }
            }
        }
    }

    /// 发布事件（由 AgentBridge 调用）
    func publish(_ event: HermesEvent) {
        // 加入缓存
        recentEvents.append(event)
        if recentEvents.count > maxCachedEvents {
            recentEvents.removeFirst(recentEvents.count - maxCachedEvents)
        }

        // 广播给所有订阅者
        for sub in subscribers {
            sub.continuation.yield(event)
        }
    }

    /// 按 session 查询历史事件
    func events(for sessionId: String) -> [HermesEvent] {
        recentEvents.filter { $0.sessionId == sessionId }
    }

    // MARK: - Private

    private func addSubscriber(_ sub: Subscriber) {
        subscribers.append(sub)
    }

    private func removeSubscriber(id: UUID) {
        subscribers.removeAll { $0.id == id }
    }
}
