# Pi Desktop 架构冻结（M0）

## 目标

提供一个围绕 Pi 核心的原生桌面 UI。桌面端是 Pi 官方 RPC 的薄客户端和状态展示层，不拥有独立的 Agent 运行语义。

## 组件边界

```text
┌──────────────────────────────┐
│ Flutter Desktop UI           │
│ - Transcript                 │
│ - Session Archive / Tree     │
│ - Tool / Usage Inspector     │
│ - Prompt Editor              │
│ - 纯 UI 偏好                 │
└──────────────┬───────────────┘
               │ stdin/stdout，LF-delimited JSONL
               │ stderr 独立收集
┌──────────────▼───────────────┐
│ 官方 Pi 进程                 │
│ pi --mode rpc                │
│ - Agent 状态与消息           │
│ - Tool 执行                  │
│ - Model / Thinking Level     │
│ - Session / Branch / Tree    │
│ - Extension / Skill / Prompt │
│ - Provider / Credential      │
└──────────────────────────────┘
```

架构中只有一个 Agent：Pi。第一阶段不引入 Rust Agent 层；如未来需要 Rust，只能承载窗口、进程树、PTY、文件监听或 Pi CredentialStore 的 OS 实现。

## 数据流规则

| 数据 | 权威来源 | 桌面端处理 |
| --- | --- | --- |
| Agent 状态 | `get_state` 与 RPC Events | 临时投影到 UI |
| Transcript | `message_start/update/end` | 流式组装；以 `message_end.message` 为最终值 |
| Tool 状态 | `tool_execution_*` Events | 按 `toolCallId` 展示真实调用与结果 |
| Session Tree | `get_tree` / `get_entries(since)` | 使用 Pi 的 Entry ID、Parent ID 和 Label |
| Model / Thinking | Pi RPC | 直接展示并转发变更命令 |
| Extension UI | `extension_ui_request` | 按 Pi 原协议响应，不创建第二套 API |
| Session JSONL | Pi SessionManager/RPC | 不直接读写，不复制到 SQLite |
| 窗口与显示偏好 | 桌面端 | 仅保存纯 UI 配置，不进入 Pi Context |

应用重启时从 Pi Session 和 RPC 状态恢复。删除桌面端本地 UI 配置不能影响 Pi Session、Branch、Prompt 或 Tool Result。

## 允许的交互

UI 操作只能直接映射到 Pi RPC 或 Pi 已有概念，包括 `prompt`、`steer`、`follow_up`、`abort`、Session 切换、Fork、Clone、Tree、Model、Thinking Level、Compaction、Stats 和 Export。

禁止在 UI 层添加自动继续、自动重试编排、隐藏 Prompt、Provider 直连、桌面 Tool 执行、私有插件协议或第二份对话历史。

## 生命周期

1. Flutter 启动官方 Pi RPC 子进程。
2. 先订阅 stdout JSONL，并独立收集 stderr。
3. 使用 `get_state`、`get_messages`、`get_tree` 初始化 UI。
4. 持续处理异步 Event 与带 `id` 的 Response；不得假设两者按请求顺序到达。
5. 关闭时发送 Pi 官方关闭语义并等待进程结束；异常退出时拒绝未完成请求。

## 复核结论

- Pi Desktop 没有独立 Agent。
- 所有 Agent 事件来自 Pi RPC。
- Session、Model、Tool、Prompt 和 Extension 的语义不在桌面端重新定义。
- TUI ANSI 输出不参与 GUI 渲染；GUI 只消费 Pi JSONL 协议。
