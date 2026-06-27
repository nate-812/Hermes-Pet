# HermesMate — 项目术语与上下文

## 一句话定位

> 复用本地 Hermes Agent 作为大脑，把 Hermes 原本在终端里的对话、工具调用、记忆、技能、会话、任务状态，封装成一个 macOS 原生可视化身体层。

---

## 核心术语

| 术语 | 含义 |
|------|------|
| **Hermes** | 本地已安装的 Hermes Agent，项目唯一 Agent Core |
| **HermesMate** | 本项目：Hermes 的 macOS 可视化身体层 |
| **AgentBridge** | 连接 HermesProvider 和 HookBridge 的统一适配层 |
| **HermesProvider** | 负责连接 Hermes 主交互通道（Dashboard/TUI/CLI）的模块 |
| **HermesHookBridge** | 负责接收 Hermes plugin hooks 事件并转成标准事件的模块 |
| **EventBus** | 内部事件总线，所有 UI 状态的唯一来源 |
| **SessionStore** | 维护当前和历史 Hermes session 的状态管理器 |
| **ToolGuard** | 所有危险工具调用的审批守门员 |
| **NotchRuntime** | 刘海/灵动岛区域的 UI 运行时 |
| **PetRuntime** | 桌宠 UI 运行时（透明 NSPanel + SwiftUI） |
| **PetSurface** | 桌宠窗口实体（NSPanel + SwiftUI 动画 + PetViewModel） |
| **ChatRuntime** | 主聊天窗口运行时 |
| **MenuBarRuntime** | 菜单栏常驻图标和弹出菜单 |
| **TimelineRuntime** | 任务时间线视图运行时 |
| **MemoryCenter** | Hermes memory 可视化管理界面 |
| **SkillCenter** | Hermes skills 可视化管理界面 |
| **LocalUIStore** | 本项目自己的 UI 事件缓存和状态（`~/.hermesmate/`） |
| **标准事件** | EventBus 内部流通的统一事件格式（非 Hermes 原始 payload） |

## 数据目录约定

| 路径 | 归属 | 读写权限 |
|------|------|---------|
| `~/.hermes/memories/` | Hermes 原生 | **只读** |
| `~/.hermes/skills/` | Hermes 原生 | **只读** |
| `~/.hermes/state.db` | Hermes 原生 | **只读** |
| `~/.hermesmate/` | 本项目 | **读写** |
| `~/.hermesmate/events.sqlite` | 本项目 | **读写** |
| `~/.hermesmate/ui_state.json` | 本项目 | **读写** |

## 参考项目与借鉴范围

| 项目 | 借鉴内容 | 不借鉴内容 |
|------|---------|-----------|
| **HermesPet** | 产品交互形态、桌宠作为 AI 入口、工具确认卡片 | memory 系统、conversation 存储 |
| **Ping Island** | Hook 事件桥架构、SessionStore → ViewModel → SwiftUI 数据流 | — |
| **Boring Notch** | 刘海展开动画、macOS 原生视觉语言 | Agent 逻辑 |
| **RunCat** | 轻量状态动画思路 | — |
