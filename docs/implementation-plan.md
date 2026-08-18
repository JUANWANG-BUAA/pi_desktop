# 分阶段实施计划

本计划是 [`TODO.md`](../TODO.md) 的执行摘要；`TODO.md` 是边界合同，若两者冲突，以 `TODO.md` 为准。每个阶段必须完成出口条件、运行验证和第 13 节复核，才允许提交。

## 阶段总览

| 阶段 | 目标 | 主要产物 | 计划 commit |
| --- | --- | --- | --- |
| M0 | 冻结边界并初始化仓库 | Git、架构、Pi 基线、计划 | `chore: initialize repository and freeze architecture` |
| M1.1 | 准备 Flutter Desktop 骨架 | 最小可启动窗口、平台目录、无 Agent 逻辑 | `build: scaffold flutter desktop shell` |
| M1.2 | 接入 Pi 进程传输 | 子进程生命周期、严格 JSONL framing、请求关联 | `feat: add pi rpc transport` |
| M1.3 | 最小可运行客户端 | Session 恢复、Prompt、流式文本、Abort | `feat: deliver minimal pi session client` |
| M2 | 完整 Pi 会话体验 | Tool/Thinking、Tree、Fork/Clone、Compaction/Retry、Model | `feat: complete pi session controls` |
| M3 | Pi 原生扩展兼容 | Commands、资源诊断、Extension UI Protocol、TUI-only 限制 | `feat: support pi extension ui protocol` |
| M4 | 原生桌面完成度 | 键盘、中文输入法、可访问性、主题密度、生命周期、多平台 | `feat: harden native desktop experience` |
| M5 | 发布准备 | 兼容矩阵、打包、升级/卸载/签名验证 | `release: validate pi desktop distribution` |

## M0（已完成）

当前工作进入 M1.1；macOS 骨架和本机验证完成，Windows/Linux 原生构建待对应 CI/主机。

- [x] 初始化 Git，默认分支为 `main`。
- [x] 固定 Flutter Desktop + 官方 `pi --mode rpc` 架构方向。
- [x] 记录 Pi `0.84.2`、Node.js 下限、Session v3 和 RPC framing 基线。
- [x] 明确 Pi 是唯一 Agent、唯一 Session/Model/Tool/Provider 事实来源。
- [x] 明确桌面端只允许纯 UI 状态；不建立第二套 Agent 状态或本地会话库。
- [x] 完成设计层越界复核。
- [x] 安装 Flutter/Dart 工具链（这是 M1.1 前置条件，不阻碍本阶段文档提交）。

## M1.1：Flutter Desktop 骨架（本机部分已完成）

- [x] 安装并固定 Flutter stable 与 Dart 版本（Flutter 3.47.0 / Dart 3.13.0）。
- [x] 用 Flutter Desktop 官方模板生成 macOS、Windows、Linux 平台目录；不引入 WebView、Electron、Tauri WebView。
- [x] 只实现可启动窗口和纯 UI 占位布局：左侧 Archive、中间 Transcript、右侧 Inspector、底部 Prompt。
- [x] 窗口设置边界已冻结为大小、位置、面板宽度、主题模式和密度；本阶段不保存 Agent 数据。
- [x] 通过 `flutter analyze`、`flutter test` 和 macOS Debug 构建检查。
- [ ] Windows/Linux 原生构建检查（当前 macOS 主机不能执行，留给对应 CI/主机）。
- [x] 复核：没有 Agent、Provider、Tool、Session 或 Prompt 逻辑。

## M1.2：Pi RPC Transport（已完成）

- [x] 开发环境启动官方 `pi --mode rpc`；发布环境不依赖全局 Pi 的打包工作留在 M5。
- [x] stdout 使用 UTF-8 解码器，严格按 LF 分割；允许去除 CRLF 的尾部 `\r`。
- [x] stderr 单独收集，绝不进入 stdout JSONL 或 Transcript。
- [x] 支持带 `id` 的 Response 关联与无 `id` 的异步 Event 并发到达。
- [x] 进程退出时拒绝全部未完成请求；支持 abort 和正常关闭。
- [x] 编写 framing、UTF-8、CRLF、交错 Event/Response、并发写入和退出测试，并通过官方 Pi RPC smoke test。
- [x] 复核：Client 是协议转发层，不是 Agent 调度器。

## M1.3：最小可运行客户端（已完成）

- [x] 启动后调用 `get_state`、`get_messages`、`get_entries`、`get_tree`，并读取 `get_commands`。
- [x] 使用 `message_start/update/end` 显示文本；最终内容以 `message_end.message` 为准。
- [x] 空闲时发送 `prompt`；流式时用独立按钮分别发送 `steer` 与 `follow_up`，不自动选择。
- [x] 支持 `abort`、进程异常退出、显式 Restart 和重复启动。
- [x] 不缓存对话为第二事实来源；重启从 Pi Session 恢复。
- [x] 完成 Flutter Widget、RPC、官方 Pi smoke 和连接恢复测试。

## M2：完整 Pi 会话体验（实现完成，行为矩阵待验证）

- [x] 展示 Tool Call/Result、流式 Tool 更新、Diff、Thinking（默认折叠）、错误和 Pi 提供的截断信息。
- [x] 处理 `queue_update`、Compaction、Retry、Extension Error 和 `agent_settled`。
- [x] 使用 Pi Entry ID、Parent ID 和 Label 展示 Session Tree，并通过官方 `fork` / `clone` 操作；当前 `0.84.2` RPC 文档没有独立的 tree-branch 命令，不自行发明。
- [x] 通过 RPC 实现 Session 切换、New、Fork、Clone、Stats、Export、Compact。
- [x] 通过 RPC 实现 Model 和 Thinking Level Picker。
- [ ] 使用带真实 Tool/Provider 的 Pi Session 完成 M2 行为矩阵；不能在无用户请求时自动消耗模型额度，纳入后续集成回归。

## M3：Pi 原生扩展兼容（Extension UI 已接入）

- [ ] Slash Command 建议直接来自 `get_commands`。
- [ ] 展示 Pi 原生 Extension、Skill、Prompt、Theme 的来源、路径和错误。
- [x] 实现 `select`、`confirm`、`input`、`editor` 的请求/响应。
- [x] 展示 `notify`、`setStatus`、`setWidget`、`setTitle`、`set_editor_text`。
- [x] 对 `custom()` 等 TUI-only 能力不创建替代行为，保持 Pi RPC 的 `undefined`、no-op 或错误语义。
- [x] Extension UI response 使用 Pi 原生 `extension_ui_response`，没有桌面私有协议。
- [x] 不创建桌面专属 Extension API、资源目录、市场、签名或权限系统。

## M4：桌面完成度

- [ ] 键盘操作、焦点、无障碍语义和长文本阅读。
- [ ] 中文输入法；所有文本编辑控件正确处理 composition/IME 状态。
- [ ] 浅色/深色、字体和密度只改变显示，不改变 Pi 语义。
- [ ] 进程树、退出、崩溃、重复启动和跨平台路径处理。
- [ ] macOS、Windows、Linux 构建和手工回归。

## M5：发布

- [ ] 每个平台携带经过验证的 Pi 运行时，不依赖用户全局 Node/Pi。
- [ ] 建立桌面版本、Pi 版本、RPC 基线和 Session 版本兼容矩阵。
- [ ] 验证升级不破坏 Session，卸载不删除 Pi 数据。
- [ ] 完成日志脱敏、代码签名、安装/升级/卸载测试。
- [ ] 完成 TODO.md 第 15 节一票否决清单和最终人工复核。

## 提交规则

- 一个阶段一个 commit；阶段内如需多个 commit，按上表子阶段拆分，不混入后续阶段。
- commit 前必须执行格式化、静态分析、测试、`git diff --check` 和越界扫描。
- 失败或阻塞必须记录在 `.learnings/ERRORS.md`，不得用“临时实现”绕过 Pi 边界。
- 不提交 API Key、认证文件、Session JSONL、构建产物或用户配置。
