# Hermes API Server 接口文档

> 端口：`http://127.0.0.1:8642`
> 认证：`Authorization: Bearer <api_server_key>`
> 密钥位置：`~/.hermes/config.yaml` → `gateway.platforms.api_server.extra.key`

---

## 目录

1. [健康检查](#1-健康检查免认证)
2. [模型 & 能力](#2-模型--能力)
3. [OpenAI 兼容接口](#3-openai-兼容接口)
4. [运行管理（异步模式）](#4-运行管理异步模式)
5. [会话管理 API](#5-会话管理-api)
6. [Cron 任务管理](#6-cron-任务管理)
7. [认证与安全](#7-认证与安全)
8. [请求头参考](#8-请求头参考)
9. [错误处理](#9-错误处理)
10. [最佳实践](#10-最佳实践)
11. [附录：会话状态字段](#11-附录会话状态字段)

---

## 1. 健康检查（免认证）

### `GET /health`

简单健康检查。

```bash
curl http://127.0.0.1:8642/health
```

**响应：**
```json
{
  "status": "ok",
  "platform": "hermes-agent",
  "version": "0.17.0"
}
```

---

### `GET /health/detailed`

详细状态，包含网关运行信息、连接平台、PID 和运行时间。

```bash
curl http://127.0.0.1:8642/health/detailed
```

**响应：**
```json
{
  "status": "ok",
  "platform": "hermes-agent",
  "version": "0.17.0",
  "gateway_state": "running",
  "platforms": { "telegram": "connected", "api_server": "connected" },
  "active_agents": 0,
  "gateway_busy": false,
  "gateway_drainable": true,
  "pid": 86715
}
```

---

### `GET /v1/health`

同 `/health`。

---

## 2. 模型 & 能力

### `GET /v1/models`

列出可用模型。

```bash
curl -H "Authorization: Bearer <key>" http://127.0.0.1:8642/v1/models
```

**响应：**
```json
{
  "object": "list",
  "data": [
    {
      "id": "hermes-agent",
      "object": "model",
      "created": 1782707841,
      "owned_by": "hermes",
      "permission": [],
      "root": "hermes-agent",
      "parent": null
    }
  ]
}
```

---

### `GET /v1/capabilities`

**✨ 推荐！** 能力发现端点，返回所有支持的端点列表和功能开关。外部 UI 用此端点自动适配，无需硬编码。

```bash
curl -H "Authorization: Bearer <key>" http://127.0.0.1:8642/v1/capabilities
```

**响应：**
```json
{
  "object": "hermes.api_server.capabilities",
  "platform": "hermes-agent",
  "model": "hermes-agent",
  "auth": { "type": "bearer", "required": true },
  "runtime": {
    "mode": "server_agent",
    "tool_execution": "server",
    "split_runtime": false,
    "description": "The API server creates a server-side Hermes AIAgent; tools execute on the API-server host..."
  },
  "features": {
    "chat_completions": true,
    "chat_completions_streaming": true,
    "responses_api": true,
    "responses_streaming": true,
    "run_submission": true,
    "run_status": true,
    "run_events_sse": true,
    "run_stop": true,
    "run_approval_response": true,
    "tool_progress_events": true,
    "approval_events": true,
    "session_resources": true,
    "session_chat": true,
    "session_chat_streaming": true,
    "session_fork": true,
    "admin_config_rw": false,
    "jobs_admin": false,
    "memory_write_api": false,
    "skills_api": true,
    "audio_api": false,
    "realtime_voice": false,
    "session_continuity_header": "X-Hermes-Session-Id",
    "session_key_header": "X-Hermes-Session-Key",
    "cors": false
  },
  "endpoints": {
    "health": { "method": "GET", "path": "/health" },
    "health_detailed": { "method": "GET", "path": "/health/detailed" },
    "models": { "method": "GET", "path": "/v1/models" },
    "chat_completions": { "method": "POST", "path": "/v1/chat/completions" },
    "responses": { "method": "POST", "path": "/v1/responses" },
    "runs": { "method": "POST", "path": "/v1/runs" },
    "run_status": { "method": "GET", "path": "/v1/runs/{run_id}" },
    "run_events": { "method": "GET", "path": "/v1/runs/{run_id}/events" },
    "run_approval": { "method": "POST", "path": "/v1/runs/{run_id}/approval" },
    "run_stop": { "method": "POST", "path": "/v1/runs/{run_id}/stop" },
    "skills": { "method": "GET", "path": "/v1/skills" },
    "toolsets": { "method": "GET", "path": "/v1/toolsets" },
    "sessions": { "method": "GET", "path": "/api/sessions" },
    "session_create": { "method": "POST", "path": "/api/sessions" },
    "session": { "method": "GET", "path": "/api/sessions/{session_id}" },
    "session_update": { "method": "PATCH", "path": "/api/sessions/{session_id}" },
    "session_delete": { "method": "DELETE", "path": "/api/sessions/{session_id}" },
    "session_messages": { "method": "GET", "path": "/api/sessions/{session_id}/messages" },
    "session_fork": { "method": "POST", "path": "/api/sessions/{session_id}/fork" },
    "session_chat": { "method": "POST", "path": "/api/sessions/{session_id}/chat" },
    "session_chat_stream": { "method": "POST", "path": "/api/sessions/{session_id}/chat/stream" }
  }
}
```

---

### `GET /v1/skills`

列出已安装的技能。

```bash
curl -H "Authorization: Bearer <key>" http://127.0.0.1:8642/v1/skills
```

**响应：**
```json
{
  "object": "list",
  "data": [
    { "name": "hermes-agent", "description": "Configure Hermes Agent...", "category": "autonomous-ai-agents" },
    ...
  ]
}
```

---

### `GET /v1/toolsets`

列出所有工具集及其状态、包含的工具。

```bash
curl -H "Authorization: Bearer <key>" http://127.0.0.1:8642/v1/toolsets
```

**响应：**
```json
{
  "object": "list",
  "platform": "api_server",
  "data": [
    {
      "name": "web",
      "label": "Web",
      "description": "Web search and content extraction",
      "enabled": true,
      "configured": true,
      "tools": ["web_search", "web_extract"]
    },
    ...
  ]
}
```

---

## 3. OpenAI 兼容接口

### `POST /v1/chat/completions`

OpenAI Chat Completions 格式，**支持流式和非流式**。

**请求体：**
```json
{
  "model": "hermes",
  "messages": [
    { "role": "system", "content": "你是一个助手" },
    { "role": "user", "content": "你好" }
  ],
  "stream": false,
  "max_tokens": 4096
}
```

**可选请求头：**
| 请求头 | 说明 |
|--------|------|
| `X-Hermes-Session-Id` | 继续已有会话（加载历史消息）。仅当配置了 API key 时可用 |
| `X-Hermes-Session-Key` | 长期记忆作用域标识符（跨会话持久化） |

**系统消息处理：**
- 支持多个 `system` 消息，自动拼接
- 系统消息仅支持纯文本（不支持图片）
- 系统提示词是**临时的**，叠加在核心系统提示之上

**用户消息支持：**
- 纯文本字符串
- 多模态内容数组（支持 `text` 和 `image_url` 类型）

**非流式响应：**
```json
{
  "id": "chatcmpl-a26594da8a4843a8b70ce3bb26634",
  "object": "chat.completion",
  "created": 1782707846,
  "model": "hermes",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "你好，我是 Hermes Agent..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 14897,
    "completion_tokens": 63,
    "total_tokens": 14960
  }
}
```

---

#### 流式 SSE 事件格式

设置 `"stream": true` 后，服务端会发送 SSE 事件流。

**标准文本增量：**
```
data: {"choices": [{"delta": {"content": "你好"}, "index": 0}]}
```

**工具调用增量（发起工具调用时）：**
```
data: {"choices": [{"delta": {"tool_calls": [{"index": 0, "id": "call_xxx", "type": "function", "function": {"name": "web_search", "arguments": "{\"query\":\"...\"}"}}]}, "index": 0}]}
```

**工具进度事件（工具执行状态）：**
```
data: {"tool": "web_search", "emoji": "🔍", "label": "搜索: ...", "toolCallId": "call_xxx", "status": "running"}
data: {"tool": "web_search", "toolCallId": "call_xxx", "status": "completed"}
```

**结束标记：**
```
data: [DONE]
```

> 注意：工具进度事件是 Hermes 扩展事件，标准 OpenAI 客户端会忽略未知字段。如果使用自定义客户端，可以捕获这些事件展示工具执行状态。

---

### `POST /v1/responses`

OpenAI Responses API 格式，**支持流式**。

**请求体：**
```json
{
  "input": "帮我查一下今天的天气",
  "instructions": "用中文回答，简洁一点",
  "previous_response_id": "resp_abc123",
  "conversation": "my-chat-session",
  "store": true,
  "stream": true
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `input` | string 或 array | ✅ | 用户输入。字符串或消息数组 |
| `instructions` | string | 否 | 系统指令 |
| `previous_response_id` | string | 否 | 链式对话，基于上次响应继续 |
| `conversation` | string | 否 | 命名会话，自动关联同一会话的响应 |
| `store` | boolean | 否 | 是否存储响应（默认 true） |
| `stream` | boolean | 否 | 是否流式输出 |
| `conversation_history` | array | 否 | 显式提供历史消息（优先级高于 previous_response_id） |

**注意：** `conversation` 和 `previous_response_id` 互斥，不能同时使用。

**响应（非流式）：**
```json
{
  "id": "resp_xxx",
  "object": "response",
  "created": 1782707846,
  "model": "hermes",
  "output": [
    { "type": "message", "role": "assistant", "content": [{ "type": "output_text", "text": "..." }] }
  ],
  "usage": { ... }
}
```

---

### `GET /v1/responses/{response_id}`

获取已存储的响应。

```bash
curl -H "Authorization: Bearer <key>" http://127.0.0.1:8642/v1/responses/resp_xxx
```

---

### `DELETE /v1/responses/{response_id}`

删除已存储的响应。

```bash
curl -X DELETE -H "Authorization: Bearer <key>" http://127.0.0.1:8642/v1/responses/resp_xxx
```

**响应：**
```json
{ "id": "resp_xxx", "object": "response", "deleted": true }
```

---

## 4. 运行管理（异步模式）

异步运行模式适用于长时间任务。客户端提交运行请求后立即获得 `run_id`，然后通过 SSE 事件流实时接收进度。

### `POST /v1/runs`

**异步启动 agent 运行，立即返回 202。**

```bash
curl -X POST -H "Authorization: Bearer <key>" \
  -H "Content-Type: application/json" \
  -d '{"input": "帮我搜索最新AI新闻"}' \
  http://127.0.0.1:8642/v1/runs
```

**请求体：**
```json
{
  "input": "帮我搜索最新AI新闻",
  "instructions": "用中文回答",
  "previous_response_id": null,
  "conversation_history": [],
  "session_id": "optional-session-id"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `input` | string 或 array | ✅ | 用户输入 |
| `instructions` | string | 否 | 系统指令 |
| `previous_response_id` | string | 否 | 链式对话 |
| `conversation_history` | array | 否 | 显式历史消息 |
| `session_id` | string | 否 | 指定会话 ID |

**响应：**
```json
{
  "run_id": "run_abc123def456",
  "status": "running",
  "created": 1782707846,
  "model": "hermes-agent"
}
```

---

### `GET /v1/runs/{run_id}`

查询运行状态（轮询用）。

```bash
curl -H "Authorization: Bearer <key>" http://127.0.0.1:8642/v1/runs/run_abc123
```

**响应：**
```json
{
  "run_id": "run_abc123",
  "status": "running",
  "created": 1782707846,
  "last_event": "tool.complete",
  "tool_progress": { ... }
}
```

状态值：`running` → `stopping` → `completed` / `error`

---

### `GET /v1/runs/{run_id}/events`

**SSE 事件流** — 实时推送结构化生命周期事件。这是实现异步 UI 的核心端点。

```bash
curl -N -H "Authorization: Bearer <key>" http://127.0.0.1:8642/v1/runs/run_abc123/events
```

**事件格式：** 每行 `data: <json>`，空行分隔。

**事件类型：**

| 事件 | 说明 |
|------|------|
| `run.started` | 运行开始 |
| `tool.start` | 工具开始执行 |
| `tool.complete` | 工具执行完成 |
| `message.delta` | 文本增量 |
| `message.complete` | 最终消息 |
| `approval.request` | 需要用户审批（含操作详情） |
| `approval.responded` | 审批已响应 |
| `run.stopping` | 运行正在停止 |
| `run.complete` | 运行正常结束 |
| `run.error` | 运行出错 |

**工具事件示例：**
```json
data: {"event": "tool.start", "run_id": "run_abc123", "timestamp": ..., "tool": "web_search", "toolCallId": "call_xxx", "args": {"query": "..."}}

data: {"event": "tool.complete", "run_id": "run_abc123", "timestamp": ..., "tool": "web_search", "toolCallId": "call_xxx"}

data: {"event": "message.delta", "run_id": "run_abc123", "timestamp": ..., "delta": "搜索结"}

data: {"event": "message.complete", "run_id": "run_abc123", "timestamp": ..., "content": "搜索结果显示..."}
```

**审批事件示例：**
```json
data: {"event": "approval.request", "run_id": "run_abc123", "timestamp": ..., "approval_session": "...", "command": "rm -rf /tmp/test", "reason": "Destructive command"}
```

**完成事件：**
```json
data: {"event": "run.complete", "run_id": "run_abc123", "timestamp": ..., "status": "completed", "usage": {"prompt_tokens": ..., "completion_tokens": ...}}
```

**Keepalive：** 30 秒无事件时发送注释行 `: keepalive`

**流关闭：** 运行结束时发送 `: stream closed`

---

### `POST /v1/runs/{run_id}/approval`

审批挂起的操作（响应 approval.request 事件）。

```bash
curl -X POST -H "Authorization: Bearer <key>" \
  -H "Content-Type: application/json" \
  -d '{"choice": "once", "all": true}' \
  http://127.0.0.1:8642/v1/runs/run_abc123/approval
```

**请求体：**
```json
{
  "choice": "once",
  "all": true
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `choice` | string | ✅ | `once`（批准本次）、`session`（批准本次会话）、`always`（永久批准）、`deny`（拒绝） |
| `all` | boolean | 否 | 是否一次性解决所有待处理审批 |

**别名：** `approve` / `approved` / `allow` 自动映射为 `once`

**响应：**
```json
{
  "object": "hermes.run.approval_response",
  "run_id": "run_abc123",
  "choice": "once",
  "resolved": 1
}
```

---

### `POST /v1/runs/{run_id}/stop`

中断正在运行的 agent。

```bash
curl -X POST -H "Authorization: Bearer <key>" \
  http://127.0.0.1:8642/v1/runs/run_abc123/stop
```

**响应：**
```json
{ "run_id": "run_abc123", "status": "stopping" }
```

---

## 5. 会话管理 API

会话是 Hermes 的核心概念，存储对话历史、模型配置等。API Server 提供完整的会话 CRUD。

### `GET /api/sessions`

列出所有会话。

```bash
curl -H "Authorization: Bearer <key>" "http://127.0.0.1:8642/api/sessions?limit=50&offset=0"
```

**查询参数：**

| 参数 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `limit` | int | 50 | 每页数量（最大 200） |
| `offset` | int | 0 | 偏移量 |
| `source` | string | null | 按来源过滤（如 `cli`、`api_server`、`telegram`） |
| `include_children` | bool | false | 是否包含子会话（分支） |

**响应：**
```json
{
  "object": "list",
  "data": [
    {
      "id": "20260629_102715_5291dc",
      "source": "cli",
      "model": "deepseek-v4-flash",
      "title": "问候与主动帮助",
      "started_at": 1782700040.39,
      "ended_at": null,
      "end_reason": null,
      "message_count": 91,
      "tool_call_count": 52,
      "input_tokens": 2058918,
      "output_tokens": 14245,
      "estimated_cost_usd": 0.0,
      "last_active": 1782707841.45,
      "preview": "在吗"
    }
  ],
  "limit": 50,
  "offset": 0,
  "has_more": false
}
```

---

### `POST /api/sessions`

创建新会话。

```bash
curl -X POST -H "Authorization: Bearer <key>" \
  -H "Content-Type: application/json" \
  -d '{"title": "我的新会话", "model": "hermes"}' \
  http://127.0.0.1:8642/api/sessions
```

**请求体：**
```json
{
  "id": "my-custom-session-id",
  "title": "我的会话",
  "model": "hermes",
  "system_prompt": "自定义系统提示词"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string | 否 | 自定义会话 ID（自动生成如不提供） |
| `title` | string | 否 | 会话标题 |
| `model` | string | 否 | 模型名称（默认使用 API Server 配置的模型） |
| `system_prompt` | string | 否 | 系统提示词 |

**响应（201）：**
```json
{
  "object": "hermes.session",
  "session": { "id": "api_xxx", "source": "api_server", "model": "hermes", "title": "我的会话", ... }
}
```

---

### `GET /api/sessions/{session_id}`

获取单个会话详情。

```bash
curl -H "Authorization: Bearer <key>" http://127.0.0.1:8642/api/sessions/20260629_102715_5291dc
```

**响应：**
```json
{
  "object": "hermes.session",
  "session": { ... }
}
```

---

### `PATCH /api/sessions/{session_id}`

更新会话元数据。

```bash
curl -X PATCH -H "Authorization: Bearer <key>" \
  -H "Content-Type: application/json" \
  -d '{"title": "新标题"}' \
  http://127.0.0.1:8642/api/sessions/session_id
```

**允许更新的字段：** `title`、`end_reason`

---

### `DELETE /api/sessions/{session_id}`

删除会话。

```bash
curl -X DELETE -H "Authorization: Bearer <key>" \
  http://127.0.0.1:8642/api/sessions/session_id
```

**响应：**
```json
{ "object": "hermes.session.deleted", "id": "session_id", "deleted": true }
```

---

### `GET /api/sessions/{session_id}/messages`

读取会话消息历史。

```bash
curl -H "Authorization: Bearer <key>" \
  http://127.0.0.1:8642/api/sessions/session_id/messages
```

**响应：**
```json
{
  "object": "list",
  "session_id": "session_id",
  "data": [
    { "role": "user", "content": "在吗", "timestamp": 1782700040 },
    { "role": "assistant", "content": "在的！", "timestamp": 1782700041 },
    ...
  ]
}
```

---

### `POST /api/sessions/{session_id}/fork`

分支会话 — 创建子会话，继承原会话的历史消息。

```bash
curl -X POST -H "Authorization: Bearer <key>" \
  -H "Content-Type: application/json" \
  -d '{"id": "fork-session-id"}' \
  http://127.0.0.1:8642/api/sessions/session_id/fork
```

**请求体：**
```json
{
  "id": "my-fork-id",
  "session_id": "my-fork-id"
}
```

**语义：**
- 原会话标记为 `branched`
- 创建子会话，携带原会话的完整对话历史
- 同 CLI 的 `/branch` 命令

---

### `POST /api/sessions/{session_id}/chat`

在已有会话中继续聊天（非流式）。

```bash
curl -X POST -H "Authorization: Bearer <key>" \
  -H "Content-Type: application/json" \
  -d '{"message": "继续刚才的话题"}' \
  http://127.0.0.1:8642/api/sessions/session_id/chat
```

**请求体：**
```json
{
  "message": "继续刚才的话题",
  "input": "继续刚才的话题",
  "system_message": "可选的临时系统指令",
  "instructions": "同 system_message"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `message` 或 `input` | string | ✅ | 用户消息 |
| `system_message` 或 `instructions` | string | 否 | 临时系统指令 |

**响应：**
```json
{
  "object": "hermes.session.chat.completion",
  "session_id": "session_id",
  "message": { "role": "assistant", "content": "好的，继续..." },
  "usage": { "prompt_tokens": 100, "completion_tokens": 50, "total_tokens": 150 }
}
```

**响应头：**
- `X-Hermes-Session-Id` — 实际使用的会话 ID
- `X-Hermes-Session-Key` — 如果请求中提供了

---

### `POST /api/sessions/{session_id}/chat/stream`

在已有会话中继续聊天（流式 SSE）。

```bash
curl -N -X POST -H "Authorization: Bearer <key>" \
  -H "Content-Type: application/json" \
  -d '{"message": "继续刚才的话题"}' \
  http://127.0.0.1:8642/api/sessions/session_id/chat/stream
```

**请求体：** 同 `/chat` 端点。

**SSE 事件：** 同 `POST /v1/chat/completions` 流式格式。

---

## 6. Cron 任务管理

### `GET /api/jobs`

列出所有 cron 任务。

```bash
curl -H "Authorization: Bearer <key>" "http://127.0.0.1:8642/api/jobs?include_disabled=true"
```

---

### `POST /api/jobs`

创建 cron 任务。

```bash
curl -X POST -H "Authorization: Bearer <key>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "每日简报",
    "schedule": "0 9 * * *",
    "prompt": "生成今日AI新闻简报",
    "deliver": "local",
    "skills": ["web"],
    "repeat": 10
  }' \
  http://127.0.0.1:8642/api/jobs
```

**请求体：**
```json
{
  "name": "任务名称",
  "schedule": "0 9 * * *",
  "prompt": "任务提示词",
  "deliver": "local",
  "skills": ["skill-name"],
  "repeat": 10
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `name` | string | ✅ | 任务名称（最长 200 字符） |
| `schedule` | string | ✅ | 调度表达式（`30m`、`every 2h`、`0 9 * * *`、ISO 时间戳） |
| `prompt` | string | 否 | 任务提示词（最长 5000 字符） |
| `deliver` | string | 否 | 投递目标（默认 `local`） |
| `skills` | array | 否 | 预加载的技能列表 |
| `repeat` | int | 否 | 重复次数 |

---

### `GET /api/jobs/{job_id}`

获取单个任务。

### `PATCH /api/jobs/{job_id}`

更新任务。

**允许更新的字段：** `name`、`schedule`、`prompt`、`deliver`、`skills`、`repeat`、`enabled`

### `DELETE /api/jobs/{job_id}`

删除任务。

### `POST /api/jobs/{job_id}/pause`

暂停任务。

### `POST /api/jobs/{job_id}/resume`

恢复任务。

### `POST /api/jobs/{job_id}/run`

立即触发任务运行。

---

## 7. 认证与安全

### 认证方式

所有 `/api/*` 和 `/v1/*` 端点（除 `/health` 外）需要 Bearer Token 认证：

```bash
# 方式一：Authorization 头（推荐）
curl -H "Authorization: Bearer <api_server_key>" http://127.0.0.1:8642/v1/models
```

### API 密钥配置

在 `~/.hermes/config.yaml` 中配置：

```yaml
gateway:
  platforms:
    api_server:
      enabled: true
      extra:
        key: <你的密钥>
        host: 127.0.0.1
        port: 8642
```

### 安全要求

1. **API key 必须配置** — 服务拒绝在没有 key 的情况下启动
2. **非 loopback 绑定需要 ≥16 字符强密钥** — 防止暴力破解
3. **非 loopback + 本地终端后端会发出安全警告** — 建议配合 Docker 沙箱使用
4. **CORS 默认关闭** — 如有需要，可通过 `cors_origins` 配置

---

## 8. 请求头参考

| 请求头 | 适用端点 | 说明 |
|--------|----------|------|
| `Authorization: Bearer <key>` | 所有 | API 认证 |
| `X-Hermes-Session-Id` | `/v1/chat/completions` | 继续已有会话，自动加载历史 |
| `X-Hermes-Session-Key` | `/v1/chat/completions`、`/v1/responses`、`/v1/runs`、会话聊天 | 长期记忆作用域标识符（跨会话持久化） |

---

## 9. 错误处理

所有 API 返回标准错误格式：

```json
{
  "error": {
    "message": "错误描述",
    "type": "invalid_request_error",
    "code": "error_code"
  }
}
```

**常见错误码：**

| 状态码 | code | 说明 |
|--------|------|------|
| 400 | `invalid_request_error` | 请求参数错误 |
| 400 | `missing_message` | 缺少 `message` 字段 |
| 400 | `invalid_session_id` | 会话 ID 格式无效 |
| 400 | `invalid_title` | 标题格式无效 |
| 400 | `unsupported_session_field` | 不支持的会话更新字段 |
| 401 | `invalid_api_key` | API key 无效 |
| 404 | — | 资源不存在 |
| 409 | `session_exists` | 会话已存在 |
| 409 | `approval_not_active` | 没有待处理的审批 |
| 413 | `body_too_large` | 请求体超过 10MB 限制 |
| 500 | `server_error` | 服务器内部错误 |
| 503 | `session_db_unavailable` | 会话数据库不可用 |

---

## 10. 最佳实践

### 1. 能力发现
**推荐先用 `GET /v1/capabilities`** 获取当前版本支持的所有端点和功能。避免硬编码端点列表。

### 2. 简单对话
优先用 `POST /v1/chat/completions` + `stream: true`
- 标准 OpenAI 格式，几乎所有客户端库都支持
- 流式事件包含工具进度信息

### 3. 异步长时间任务
用 `POST /v1/runs` + `GET /v1/runs/{id}/events`
- 立即获得 run_id，不阻塞
- 通过 SSE 实时接收完整生命周期事件
- 支持审批操作

### 4. 会话保持
用 `X-Hermes-Session-Id` 请求头保持对话上下文
- 服务端自动加载历史消息
- 不需要客户端维护消息列表

### 5. 自定义 UI 工具进度显示
捕获流式响应中的工具进度事件（`"tool": "web_search"` 等），在 UI 上展示 agent 正在做什么。

### 6. 并发限制
API Server 有最大并发运行数限制（默认 10），超限返回 429/503。

---

## 11. 附录：会话状态字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 会话唯一 ID |
| `source` | string | 来源平台（`cli`、`api_server`、`telegram` 等） |
| `model` | string | 使用的模型 |
| `title` | string | 会话标题 |
| `started_at` | float | 开始时间（Unix 时间戳） |
| `ended_at` | float 或 null | 结束时间 |
| `end_reason` | string 或 null | 结束原因 |
| `message_count` | int | 消息数量 |
| `tool_call_count` | int | 工具调用次数 |
| `input_tokens` | int | 输入 token 数 |
| `output_tokens` | int | 输出 token 数 |
| `cache_read_tokens` | int | 缓存读取 token 数 |
| `estimated_cost_usd` | float | 估算成本 |
| `last_active` | float | 最后活跃时间 |
| `preview` | string | 会话预览文本 |
| `parent_session_id` | string 或 null | 父会话 ID（分支用） |

---

> 文档版本：基于 Hermes v0.17.0
> 自动生成时间：2025-06-29
