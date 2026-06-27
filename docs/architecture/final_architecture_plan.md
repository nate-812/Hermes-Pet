# HermesMate / Hermes Visual Runtime 最终核心架构规划

## 0. 项目一句话定位

本项目不是重新开发一个 AI Agent，也不是重新写一个聊天软件。

本项目的定位是：

**复用本地 Hermes Agent 作为大脑，把 Hermes 原本在终端里的对话、工具调用、记忆、技能、会话、任务状态，封装成一个 macOS 原生可视化身体层。**

最终产品形态：

```text
Hermes 做大脑
macOS App 做身体
刘海 / 灵动岛显示状态
桌宠表达情绪和任务反馈
菜单栏作为常驻入口
聊天窗口作为主交互界面
任务时间线展示 Agent 行为
权限卡片负责危险操作确认
记忆中心展示 Hermes memory
技能中心展示 Hermes skills
```

核心原则：

```text
能复用顶级开源项目的，不手搓。
Agent Core 绝不重写，必须复用 Hermes。
Hermes 原生 memory / skills / sessions 绝不另起炉灶。
UI 可以自研，但必须参考成熟项目的交互和架构。
危险工具调用必须可视化确认，不能静默执行。
```

---

## 1. 最终技术选型

### 1.1 Agent 大脑

最终选择：

```text
Hermes Agent
```

Hermes 是唯一第一版 Agent Core。

原因：

```text
用户本地已经安装 Hermes
用户本地 Hermes 已经有 memory
用户平时已经用 Hermes CLI 前台交互
Hermes 有 sessions
Hermes 有 skills
Hermes 有 hooks
Hermes 有 Desktop / Dashboard 思路
Hermes 支持 CLI、Desktop、Gateway 共用同一个 core
```

禁止：

```text
不重写 Agent Core
不另写 Python Agent 当主脑
不把 OpenClaw 作为第一版主脑
不自己实现 memory 系统替代 Hermes memory
不自己实现 skills 系统替代 Hermes skills
```

允许：

```text
以后可以抽象 AgentProvider
以后可以兼容 OpenClaw / Claude Code / Codex CLI
但第一版只实现 HermesProvider
```

---

### 1.2 产品交互主参考

最终选择：

```text
HermesPet
```

HermesPet 不作为 Agent Core，不作为底层 memory 系统，但作为产品交互主参考。

主要借鉴：

```text
AI 住在 MacBook 刘海下方
刘海呼出聊天窗口
桌宠作为陪伴和入口
拖文件给桌宠
工具权限确认卡片
聊天窗口和刘海状态联动
多引擎 Provider 抽象
快捷键唤醒
语音入口
任务完成后的灵动岛反馈
```

注意：

```text
HermesPet 是产品形态参考，不是我们的底层架构。
不能直接照搬 HermesPet 的 memory / conversation 存储。
不能因为参考 HermesPet，就绕过本地 Hermes Agent。
我们的主脑仍然是本地 Hermes。
```

---

### 1.3 Hermes 事件桥参考

最终选择：

```text
Ping Island
```

主要借鉴：

```text
Hermes plugin hooks 接入方式
Agent session 状态监听
Hook events → service layer → SessionStore → ViewModel → SwiftUI UI
Dynamic Island 风格状态面板
多 Agent session 监控思路
```

硬性要求：

```text
我们的灵动岛和桌宠不能直接解析 Hermes 原始文本。
必须通过事件桥，把 Hermes 运行状态转成标准事件。
```

---

### 1.4 灵动岛视觉参考

最终选择：

```text
Boring Notch
```

主要借鉴：

```text
MacBook notch 区域展开动画
黑色刘海融合视觉
文件架交互
HUD 替代
顶部浮层位置处理
macOS 原生质感
```

注意：

```text
Boring Notch 只作为 Notch UI / UX 参考。
Hermes 事件接入仍然参考 Ping Island。
Agent 逻辑仍然来自 Hermes。
```

---

### 1.5 桌宠实现方式

最终选择：

```text
SwiftUI + AppKit 自研 PetSurface
```

不再强依赖 OpenPets。

原因：

```text
桌宠需要 macOS 原生体验
需要透明置顶窗口
需要可拖拽
需要不抢焦点
需要和刘海、菜单栏统一视觉
需要和 EventBus 深度绑定
SwiftUI + AppKit 更合适
```

参考对象：

```text
HermesPet：桌宠作为 AI 入口和陪伴的产品形态
RunCat：轻量状态动画思路
Boring Notch：统一 macOS 视觉语言
Ping Island：Agent 事件驱动 UI 的数据流
```

桌宠本质：

```text
PetSurface = 一个透明 NSPanel + SwiftUI 动画视图 + PetViewModel 状态机
```

---

### 1.6 macOS App 技术栈

最终选择：

```text
SwiftUI + AppKit
```

必须使用原生 macOS 能力：

```text
NSStatusItem 菜单栏
NSPanel 透明置顶桌宠窗口
自定义 notch floating panel
SwiftUI 状态绑定
AppKit 窗口管理
UserNotifications
Accessibility 权限
Screen Recording 权限
Microphone 权限
AppleScript / Automation 权限
Global HotKey
```

不推荐：

```text
不推荐第一版使用 Electron 做主体
不推荐第一版使用纯 WebView 做桌宠和灵动岛
不推荐第一版用跨平台 UI 强行模拟 Mac 体验
```

---

## 2. 最终总架构

```text
┌──────────────────────────────────────────┐
│              Hermes Agent Core            │
│  memory / skills / sessions / tools / LLM │
└─────────────────────┬────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        │                           │
        ↓                           ↓
┌──────────────────┐       ┌──────────────────────┐
│  主交互通道        │       │  事件监听通道          │
│  Dashboard API    │       │  Hermes Plugin Hooks │
│  TUI Gateway      │       │  Hook Bridge         │
│  CLI fallback     │       │  Event Bridge        │
└────────┬─────────┘       └──────────┬───────────┘
         │                            │
         └──────────────┬─────────────┘
                        ↓
┌──────────────────────────────────────────┐
│             Agent Bridge Layer            │
│  HermesProvider / HookBridge / Adapter    │
└─────────────────────┬────────────────────┘
                      ↓
┌──────────────────────────────────────────┐
│          Core Runtime Services            │
│ EventBus / SessionStore / ToolGuard       │
│ MemoryCenter / SkillCenter / Timeline     │
└─────────────────────┬────────────────────┘
                      ↓
┌──────────────────────────────────────────┐
│             Mac Visual Runtime            │
│ SwiftUI / AppKit / NSPanel / NSStatusItem │
└─────────────────────┬────────────────────┘
                      ↓
┌──────────────────────────────────────────┐
│                 UI Surfaces               │
│ Notch / Pet / MenuBar / Chat / Timeline   │
│ Approval Cards / Memory / Skills          │
└──────────────────────────────────────────┘
```

一句话：

```text
Hermes 是大脑。
Agent Bridge 是神经。
EventBus 是中枢。
ToolGuard 是安全阀。
Notch、Pet、MenuBar、Chat 是身体。
MemoryCenter 和 SkillCenter 是可视化管理层。
```

---

## 3. 两条核心通道

### 3.1 主交互通道

职责：

```text
用户输入
Hermes 回复
聊天 session
历史会话
文件附件
工具结果摘要
模型状态
配置读取
```

优先级：

```text
第一优先级：Hermes Desktop / Dashboard / TUI Gateway API
第二优先级：Hermes OpenAI-compatible API
第三优先级：Hermes CLI subprocess fallback
```

硬性要求：

```text
必须优先研究 Hermes 官方 Desktop / Dashboard 的连接方式。
如果官方 backend 可用，必须走官方 backend。
CLI subprocess 只能作为 fallback，不是主架构。
```

禁止：

```text
不允许长期只靠 stdout 正则解析 Hermes 输出。
不允许 UI 直接和 Hermes 终端文本强耦合。
```

---

### 3.2 事件监听通道

职责：

```text
Agent 开始思考
Agent 结束思考
用户提交 prompt
Assistant 开始回复
Assistant 回复流式输出
工具调用开始
工具调用结束
工具调用失败
工具等待审批
记忆更新
技能更新
任务完成
任务失败
Session 结束
```

优先级：

```text
第一优先级：Hermes Plugin Hooks
第二优先级：Ping Island-style Hook Bridge
第三优先级：Hermes structured logs
第四优先级：CLI stdout parsing fallback
```

硬性要求：

```text
事件监听通道必须输出统一标准事件。
UI 不允许直接消费 Hermes 原始 hook payload。
所有 UI 只能消费 EventBus 的标准事件。
```

---

## 4. 标准事件模型

所有 Hermes 原始事件都必须转换成内部标准事件。

标准事件结构：

```json
{
  "id": "event_uuid",
  "sessionId": "session_id",
  "timestamp": "2026-xx-xxTxx:xx:xx",
  "source": "hermes",
  "type": "tool.call.started",
  "status": "running",
  "title": "正在执行终端命令",
  "summary": "Hermes 正在运行 shell 工具",
  "riskLevel": "medium",
  "payload": {}
}
```

必须支持的事件类型：

```text
agent.session.started
agent.session.ended

user.prompt.submitted

agent.thinking.started
agent.thinking.ended

assistant.message.started
assistant.message.delta
assistant.message.completed

tool.call.started
tool.call.streaming
tool.call.needs_approval
tool.call.approved
tool.call.rejected
tool.call.succeeded
tool.call.failed

memory.update.proposed
memory.update.approved
memory.update.rejected
memory.updated

skill.update.proposed
skill.update.approved
skill.update.rejected
skill.updated

task.started
task.completed
task.failed
task.needs_user_input

file.dragged_to_pet
file.attached_to_session

notch.expanded
notch.collapsed

pet.clicked
pet.dragged
pet.state.changed
```

UI 消费规则：

```text
NotchView      只消费 EventBus 标准事件
PetView        只消费 EventBus 标准事件
TimelineView   只消费 EventBus 标准事件
ChatView       通过 ChatRuntime + EventBus 同步
ApprovalView   只消费 tool.call.needs_approval
MemoryView     只消费 memory 事件和只读 memory 文件
SkillView      只消费 skill 事件和只读 skills 文件
```

---

## 5. 核心模块划分

### 5.1 HermesProvider

职责：

```text
检测 Hermes 是否安装
检测 Hermes 路径
检测 Hermes 版本
启动本地 Hermes backend
连接 Hermes dashboard / tui_gateway / API
发送用户消息
接收 Hermes 回复
列出 sessions
读取 session
获取 Hermes runtime 状态
fallback 到 CLI subprocess
```

禁止：

```text
HermesProvider 不允许直接操作 UI
HermesProvider 不允许直接写 memory
HermesProvider 不允许直接写 skills
HermesProvider 不允许绕过 ToolGuard 执行危险动作
```

---

### 5.2 HermesHookBridge

职责：

```text
检查 Hermes plugin hook 是否安装
安装本项目 Hermes plugin hook
接收 Hermes hook 事件
把 Hermes hook payload 转成标准事件
推送到 EventBus
维护 sessionId 映射
维护 toolCallId 映射
```

参考：

```text
Ping Island 的 hook event → service layer → SessionStore → ViewModel → SwiftUI UI 架构
```

---

### 5.3 AgentBridge

职责：

```text
统一 HermesProvider 和 HermesHookBridge
把主交互通道和事件监听通道合并
处理 session 对齐
处理 message 对齐
处理 tool call 对齐
处理状态去重
把所有状态送入 EventBus
```

注意：

```text
AgentBridge 是项目核心。
UI 不直接碰 HermesProvider。
UI 不直接碰 HermesHookBridge。
```

---

### 5.4 EventBus

职责：

```text
接收所有标准事件
广播给各 ViewModel
缓存最近事件
按 session 保存事件流
支持 Timeline 查询
支持 Notch 当前状态推导
支持 Pet 当前状态推导
```

硬性要求：

```text
所有 UI 状态必须从 EventBus 派生。
不允许 UI 内部自己猜 Hermes 状态。
```

---

### 5.5 SessionStore

职责：

```text
维护当前 active session
维护历史 session 摘要
关联 Hermes 原生 session
关联当前事件流
支持搜索
支持恢复上一次对话
```

数据原则：

```text
Hermes 原生 state.db 只能只读。
本项目可以维护自己的 UI event cache。
不允许直接写 Hermes state.db。
```

---

### 5.6 NotchRuntime

职责：

```text
渲染 MacBook 刘海 / 灵动岛
展示 Hermes 当前状态
展示工具调用状态
展示等待审批状态
展示任务完成状态
展示任务失败状态
点击展开任务卡片
拖文件到刘海后附加到当前 session
```

视觉参考：

```text
Boring Notch
HermesPet
```

状态机：

```text
idle
listening
thinking
tool_running
waiting_approval
success
failed
needs_input
file_hover
file_attached
```

状态映射：

```text
agent.thinking.started       → thinking
tool.call.started            → tool_running
tool.call.needs_approval     → waiting_approval
task.completed               → success
task.failed                  → failed
task.needs_user_input        → needs_input
file.dragged_to_pet/notch    → file_hover
```

硬性要求：

```text
Notch 不是装饰。
Notch 是 Agent 当前状态中心。
```

---

### 5.7 PetRuntime

职责：

```text
渲染桌宠
响应 Hermes 事件
表达 Agent 状态
支持点击唤起聊天窗口
支持拖文件给桌宠
支持文件被嗅探 / 附加到会话
支持等待审批时提醒用户
支持任务完成后的反馈动画
```

实现方式：

```text
SwiftUI + AppKit
透明 NSPanel
置顶窗口
可拖拽
不抢焦点
可配置是否穿透点击
```

产品参考：

```text
HermesPet 的桌宠交互
RunCat 的轻量状态动画
```

Pet 状态：

```text
idle
thinking
working
waiting
happy
sad
warning
sleeping
file_sniffing
attention
```

事件映射：

```text
agent.thinking.started      → thinking
tool.call.started           → working
tool.call.needs_approval    → attention / waiting
task.completed              → happy
task.failed                 → sad
memory.updated              → happy / bubble: 我记住了
file.dragged_to_pet         → file_sniffing
```

硬性要求：

```text
桌宠不是聊天窗口贴皮。
桌宠是 Agent 状态反馈 + 文件入口 + 轻交互入口。
```

---

### 5.8 MenuBarRuntime

职责：

```text
菜单栏常驻入口
显示 Hermes 连接状态
快速打开聊天窗口
快速打开记忆中心
快速打开技能中心
快速打开任务时间线
启用 / 禁用桌宠
启用 / 禁用灵动岛
暂停 / 恢复 HermesMate
```

实现：

```text
NSStatusItem
SwiftUI menu popover
```

---

### 5.9 ChatRuntime

职责：

```text
提供主聊天窗口
发送消息给 Hermes
接收 Hermes 回复
支持 streaming
支持当前 session
支持历史 session
支持文件拖入
支持截图附件
支持工具调用摘要
支持跳转任务时间线
```

要求：

```text
ChatRuntime 只负责主对话体验。
不要把所有状态都塞进 ChatRuntime。
Notch / Pet / Timeline 都要独立运行。
```

---

### 5.10 ToolGuard

职责：

所有危险工具调用必须经过 ToolGuard。

危险操作包括：

```text
执行 shell 命令
写文件
删除文件
移动大量文件
修改系统设置
浏览器自动化
访问隐私目录
读取敏感文件
发送邮件
发送消息
安装软件
修改配置
```

ToolGuard 必须展示：

```text
工具名称
关键参数
操作摘要
风险等级
影响范围
是否可撤销
Hermes 为什么要做这件事
```

用户操作：

```text
拒绝
允许一次
总是允许
修改后允许
查看详情
```

审批事件：

```text
tool.call.needs_approval
tool.call.approved
tool.call.rejected
```

参考：

```text
HermesPet 的工具权限确认卡片
```

硬性要求：

```text
第一版宁可少做工具，也不能绕过 ToolGuard。
任何危险操作都不能静默执行。
```

---

### 5.11 MemoryCenter

职责：

可视化 Hermes memory。

必须读取：

```text
~/.hermes/memories/MEMORY.md
~/.hermes/memories/USER.md
```

功能：

```text
展示长期记忆
展示用户画像
展示容量占用
展示最近更新时间
展示待审批 memory
支持 approve / reject / edit pending memory
```

硬性要求：

```text
默认只读展示 memory 文件。
不允许 UI 直接乱写 MEMORY.md / USER.md。
写入、审批、拒绝必须优先走 Hermes 官方 memory 命令或官方机制。
如果当前 session 使用 frozen snapshot，UI 必须提示：新记忆将在下一次新会话完整生效。
```

---

### 5.12 SkillCenter

职责：

可视化 Hermes skills。

必须读取：

```text
~/.hermes/skills/
```

功能：

```text
展示 skill 列表
展示 skill 内容
展示 skill 来源
展示 skill 更新时间
展示 pending skill diff
支持 approve / reject skill 更新
```

硬性要求：

```text
默认只读展示 skills。
不允许 UI 直接随意写入 skill。
写入必须走 Hermes 官方机制或审批流程。
```

---

### 5.13 TimelineRuntime

职责：

把 Hermes 原本终端里的过程变成可视化时间线。

时间线事件包括：

```text
用户输入
Agent 思考
Assistant 回复
工具调用
工具输出
等待确认
用户批准 / 拒绝
记忆更新
技能更新
任务完成
任务失败
```

用途：

```text
让用户知道 Agent 做了什么
方便审计
方便 debug
方便复盘
方便后续做任务回放
```

---

### 5.14 LocalUIStore

职责：

保存本项目自己的 UI 状态和事件缓存。

建议路径：

```text
~/.hermesmate/
```

建议文件：

```text
~/.hermesmate/events.sqlite
~/.hermesmate/ui_state.json
~/.hermesmate/pins.json
~/.hermesmate/attachments/
~/.hermesmate/tool_approvals.json
~/.hermesmate/logs/
```

注意：

```text
~/.hermes/ 是 Hermes 原生数据。
~/.hermesmate/ 是本项目 UI 数据。
两者必须分开。
```

禁止：

```text
不允许把 Hermes memory 复制一份自己管理。
不允许把 Hermes session 复制后当主数据源。
不允许写 Hermes state.db。
```

---

## 6. 数据读写规范

### 6.1 允许只读

允许只读访问：

```text
~/.hermes/memories/MEMORY.md
~/.hermes/memories/USER.md
~/.hermes/skills/
~/.hermes/state.db
Hermes config
Hermes logs
```

### 6.2 允许写入

只允许写入：

```text
~/.hermesmate/events.sqlite
~/.hermesmate/ui_state.json
~/.hermesmate/pins.json
~/.hermesmate/attachments/
~/.hermesmate/tool_approvals.json
```

### 6.3 禁止直接写入

禁止 UI 直接写：

```text
~/.hermes/memories/MEMORY.md
~/.hermes/memories/USER.md
~/.hermes/skills/
~/.hermes/state.db
Hermes 核心配置
Hermes API keys
```

除非满足：

```text
Hermes 官方 API 明确支持
或用户明确确认
或该写入通过 Hermes 官方命令完成
或该写入经过 ToolGuard 审批
```

---

## 7. 本地运行方式

默认运行本地 Hermes。

启动流程：

```text
用户启动 HermesMate
        ↓
检测 Hermes 是否安装
        ↓
检测 Hermes 当前 profile / config
        ↓
检测 Hermes backend / dashboard 是否运行
        ↓
如果已运行，直接连接
        ↓
如果未运行，尝试启动本地 Hermes backend
        ↓
如果 backend 不可用，fallback 到 CLI subprocess
        ↓
安装 / 检查 Hermes plugin hook
        ↓
启动 EventBus
        ↓
启动 MenuBar / Notch / Pet
```

必须支持：

```text
查看 Hermes 路径
查看 Hermes 版本
查看 Hermes 运行状态
查看当前 profile
查看 memory 路径
查看 skills 路径
查看 hook 安装状态
```

---

## 8. 权限设计

macOS 权限必须显式管理。

需要的权限：

```text
Accessibility：未来做系统自动化、快捷键、部分窗口控制
Screen Recording：截图问 AI
Microphone：语音输入
Speech Recognition：语音转文字
Automation / AppleScript：控制部分 App
Files and Folders：文件拖拽、附件处理
Notifications：任务完成提醒
```

硬性要求：

```text
权限必须按需申请。
不能启动时一次性全要。
每个权限要解释用途。
危险操作必须经过 ToolGuard。
```

---

## 9. 第一版 MVP 范围

第一版只做核心闭环，不做大而全。

### 9.1 Hermes 连接

```text
检测本地 Hermes
启动 / 连接 Hermes
发送消息
接收回复
显示当前 session
```

### 9.2 Hermes Hook 事件

```text
安装 / 检查 hook
接收基础事件
转换标准事件
推送 EventBus
```

### 9.3 灵动岛

```text
idle
thinking
tool_running
waiting_approval
success
failed
点击展开任务卡片
```

### 9.4 桌宠

```text
idle 动画
thinking 动画
working 动画
waiting 动画
success 动画
failed 动画
点击打开聊天窗口
拖文件给桌宠作为附件
```

### 9.5 工具确认卡片

```text
shell 命令确认
文件写入确认
文件删除确认
用户可以允许 / 拒绝 / 总是允许
```

### 9.6 记忆中心

```text
读取 USER.md
读取 MEMORY.md
展示容量占用
展示最近更新
只读展示为主
```

### 9.7 任务时间线

```text
展示用户输入
展示 Agent 回复
展示工具调用
展示审批过程
展示任务完成 / 失败
```

---

## 10. 第二阶段扩展

第二阶段再做：

```text
截图问 AI
剪贴板处理
语音输入
语音播报
PDF 拖入分析
文件拖入 Notch
Pin 卡片
Spotlight 风格快问
MCP 工具扩展
多 Agent Provider
OpenClaw Gateway 接入
Claude Code Provider
Codex CLI Provider
移动端远程控制
```

---

## 11. 明确不做的事情

第一版禁止做：

```text
不重写 Agent Core
不魔改 Hermes 内核
不替换 Hermes memory
不替换 Hermes skills
不直接写 Hermes state.db
不一开始做全平台
不一开始做移动端
不一开始接入所有 Agent
不一开始实现所有 MCP 工具
不让 Agent 静默接管整个 Mac
不绕过用户确认执行危险操作
不把 HermesPet 的自有 memory 系统当作主存储
```

---

## 12. 最终硬性架构结论

本项目最终架构必须是：

```text
Hermes Agent Core
        ↓
Hermes 官方主交互通道 + Hermes Plugin Hooks 事件通道
        ↓
AgentBridge
        ↓
EventBus / SessionStore / ToolGuard
        ↓
SwiftUI + AppKit Mac Visual Runtime
        ↓
HermesPet 风格产品交互
Boring Notch 风格灵动岛
Ping Island 风格事件桥
SwiftUI/AppKit 原生桌宠 PetSurface
菜单栏
聊天窗口
任务时间线
记忆中心
技能中心
```

一句话：

```text
Hermes 做大脑。
HermesPet 做产品交互参考。
Ping Island 做 Hermes 事件桥参考。
Boring Notch 做灵动岛视觉参考。
SwiftUI/AppKit 自研 PetSurface 做原生桌宠。
ToolGuard 做权限守门员。
MCP 做未来工具生态。
```
