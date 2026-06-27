# HermesMate 灵动岛 (Notch) 集成开发指北

这份文档详细记录了 HermesMate 视觉重构第一阶段的核心决策与实施步骤。此文档用于在新会话中指导开发工作。

## 1. 核心设计决策 (已确认)

根据产品定义的交流，我们确立了以下几项不可动摇的开发原则与产品交互形态：

- **职能分离**：刘海（灵动岛）**只负责显示 Agent 的实时状态**（如：“正在思考”、“正在打字”等动画和短文本提示）。
- **聊天主界面独立**：完整的流式聊天气泡（ChatView）不会挂在刘海下方，而是单独放置在类似 `HermesPet` 的**可拖拽式独立悬浮面板**中。
- **暂缓桌宠**：第一阶段全力打磨刘海（Boring Notch）的交互与动画，暂时不引入桌宠（RunCat）系统，保持专注。
- **开源复用红线**：**严禁手搓刘海 UI 和动画**。必须且只能从开源项目 [Boring Notch](https://github.com/TheBoredTeam/boring.notch) 中提取核心悬浮窗机制与动画代码，然后自行编写接口适配器（Adapter）对接我们的 `EventBus`。

---

## 2. 代码复用与改造步骤 (Next Steps)

在新会话中，请严格按照以下步骤操作，不要自己从零写 UI：

### Step 1: 提取核心窗口机制 (NSPanel)
从 Boring Notch 源码中提取 `BoringNotchWindow.swift`。
- **核心价值**：它利用了特定的 `NSWindow.StyleMask` 和 `collectionBehavior`（如 `.fullScreenAuxiliary`, `.canJoinAllSpaces`），能够无视 macOS 的空间限制，完美悬浮在全屏应用（如全屏浏览器）和原生刘海之上。
- **适配任务**：直接复制文件放入 `HermesMate/UI/Notch/`，确保能在我们的项目中编译通过。

### Step 2: 改造状态控制器 (Coordinator)
从 Boring Notch 源码中提取 `BoringViewCoordinator.swift`，并重命名为 `NotchStateCoordinator.swift`。
- **核心价值**：原版它负责监听系统的音量、亮度、网易云音乐播放状态来控制刘海的展开与收起。
- **适配任务**：
  - **剔除**所有系统级监听（Music, Volume, Brightness）。
  - **接入**咱们自己的 `SessionStore` 和 `EventBus`。
  - **状态映射**：将接收到的 Hermes 事件映射到岛的动画触发器上。例如，收到 `message.start` 触发岛的“变宽/呼吸”动画；收到 `message.delta` 触发岛内的文本滚动；收到流式结束事件则将岛缩回隐藏。

### Step 3: 提取并重组视图 (SwiftUI)
提取原版的 `ContentView.swift`（及相关的动画组件），重命名为 `NotchContentView.swift`。
- **核心价值**：原版内含非常丝滑的 SwiftUI 弹性动画（Spring Animations）和各种圆角过渡效果。
- **适配任务**：
  - 删掉里面的专辑封面、音乐进度条等 UI 元素。
  - 替换为 Hermes 的状态元素（例如一个旋转的思考 Icon，或是一行滚动的 `Text(message.content)`）。
  - 对接刚才写好的 `NotchStateCoordinator` 里的状态变量。

### Step 4: 应用挂载入口调整
- 修改 `HermesMateApp.swift` 或 `run.sh`。
- 确保在应用启动时，除了后台静默拉起 `tui_gateway/entry.py`，还要初始化并把 `BoringNotchWindow` 挂载到屏幕主显示器的正上方。
- 此时，原本测试用的 ChatView 可以作为一个独立的 `WindowGroup` 或 `NSPanel` 单独呼出。

---

> **给新会话 Agent 的提示**：
> Boring Notch 的完整克隆代码目前位于 `/tmp/boring.notch/` 目录下（如果该目录被清空，请重新运行 `git clone https://github.com/TheBoredTeam/boring.notch.git`）。请直接从中复制所需文件并进行上述改造，保持对开源成果的敬畏，不要重新发明轮子。
