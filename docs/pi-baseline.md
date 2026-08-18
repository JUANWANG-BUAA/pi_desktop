# Pi 公共 API 基线

本文件记录 M0 使用的 Pi 版本与公开文档依据。依赖升级必须先更新本文件并重新执行 RPC 兼容测试。

## 版本与运行时

| 项目 | 基线 |
| --- | --- |
| Pi 包 | `@earendil-works/pi-coding-agent` `0.84.2` |
| Pi CLI | `pi 0.84.2` |
| Node.js 要求 | `>=22.19.0`（Pi `package.json` 的 `engines`） |
| 当前检测到的 Node.js | `v24.19.0` |
| Session JSONL | 当前版本 `v3`；Pi 可自动迁移旧 v1/v2 |
| RPC wire baseline | Pi `0.84.2` 的 `docs/rpc.md`；文档未定义独立数字协议版本，暂以 Pi 包版本锁定 |
| 初始支持范围 | 仅验证并支持 `0.84.2`；扩大范围前必须有兼容性矩阵 |

Flutter/Dart 在当前开发环境尚未安装，因此 Flutter Desktop 骨架和跨平台构建验证是 M1 的前置阻塞项，而不是由 Node/Pi 版本替代完成。

## 已阅读的官方依据

与 Pi `0.84.2` 一起分发的公开文档：

- `docs/rpc.md`：RPC 命令、响应、异步 Event、严格 LF JSONL framing、Extension UI 子协议。
- `docs/json.md`：JSON Event Stream 与 message delta 规则。
- `docs/session-format.md`：Session JSONL v3、Entry Tree、Message 类型和 SessionManager。
- `docs/sdk.md`：公开 SDK、Runtime、ResourceLoader、ModelRuntime 和 Session API。
- `docs/extensions.md`：Extension 生命周期、事件、UI 和 TUI-only 限制。
- `docs/packages.md`：Pi Package 资源发现与安装语义。
- `docs/models.md`：Pi 原生 Model / Provider / Credential 配置，不在桌面端复制。
- `docs/skills.md`、`docs/prompt-templates.md`、`docs/themes.md`：原生资源发现规则。
- `docs/environment-variables.md`：Pi 进程与 Session 环境变量。
- `docs/tui.md`：TUI 组件和 IME 注意事项；桌面端不解析 TUI ANSI 或模拟 TUI Component。
- `examples/rpc-extension-ui.ts`、`examples/extensions/rpc-demo.ts`：RPC Extension UI 请求/响应示例。
- `examples/sdk/README.md`：公开 SDK 集成示例索引。

## M1 必须验证的公开 RPC

启动 `pi --mode rpc` 后，按官方协议验证：

- 初始化：`get_state`、`get_messages`、`get_entries`、`get_tree`、`get_commands`。
- 模型：`get_available_models`、`set_model`、`get_available_thinking_levels`、`set_thinking_level`。
- 会话：`prompt`、`abort`、`new_session`、`switch_session`、`fork`、`clone`。
- 展示：`message_start/update/end`、`tool_execution_*`、`queue_update`、Compaction/Retry Events。
- 扩展：`extension_ui_request` 与对应的 `extension_ui_response`。

客户端只实现上述官方命令的直接转发，不新增 `runTask`、`startAgent`、`autoContinue`、`smartRetry` 等 API。
