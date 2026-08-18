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

## 当前阶段：M0（已完成）

- [x] 初始化 Git，默认分支为 `main`。
- [x] 固定 Flutter Desktop + 官方 `pi --mode rpc` 架构方向。
- [x] 记录 Pi `0.84.2`、Node.js 下限、Session v3 和 RPC framing 基线。
- [x] 明确 Pi 是唯一 Agent、唯一 Session/Model/Tool/Provider 事实来源。
- [x] 明确桌面端只允许纯 UI 状态；不建立第二套 Agent 状态或本地会话库。
- [x] 完成设计层越界复核。
- [ ] 安装 Flutter/Dart 工具链（这是 M1.1 前置条件，不阻碍本阶段文档提交）。

## M1.1：Flutter Desktop 骨架

- [ ] 安装并固定 Flutter stable 与 Dart 版本。
- [ ] 用 Flutter Desktop 官方模板生成平台目录；不引入 WebView、Electron、Tauri WebView。
- [ ] 只实现可启动窗口和纯 UI 占位布局：左侧 Archive、中间 Transcript、右侧 Inspector、底部 Prompt。
- [ ] 确认窗口设置只保存大小、位置、面板宽度、主题模式和密度。
- [ ] 通过 `flutter analyze`、`flutter test` 和三平台构建检查。
- [ ] 复核：没有 Agent、Provider、Tool、Session 或 Prompt 逻辑。

## M1.2：Pi RPC Transport

- [ ] 启动官方 `pi --mode rpc`，发布环境不依赖全局 Pi。
- [ ] stdout 使用 UTF-8 解码器，严格按 LF 分割；允许去除 CRLF 的尾部 `\r`。
- [ ] stderr 单独收集，绝不进入 stdout JSONL 或 Transcript。
- [ ] 支持带 `id` 的 Response 关联与无 `id` 的异步 Event 并发到达。
- [ ] 进程退出时拒绝全部未完成请求；支持 abort 和正常关闭。
- [ ] 编写 framing、UTF-8、CRLF、交错 Event/Response、大输出和退出测试。
- [ ] 复核：Client 是协议转发层，不是 Agent 调度器。

## M1.3：最小可运行客户端

- [ ] 启动后调用 `get_state`、`get_messages`、`get_entries`、`get_tree`。
- [ ] 使用 `message_start/update/end` 显示文本；最终内容以 `message_end.message` 为准。
- [ ] 空闲时发送 `prompt`；流式时分别支持 `steer` 与 `follow_up`。
- [ ] 支持 `abort`、进程异常退出和重新启动。
- [ ] 不缓存对话为第二事实来源；重启从 Pi Session 恢复。
- [ ] 完成 M1 行为测试并提交。

## M2：完整 Pi 会话体验

- [ ] 展示 Tool Call/Result、流式 Bash、Diff、Thinking、错误和截断信息。
- [ ] 处理 `queue_update`、Compaction、Retry 和 `agent_settled`。
- [ ] 用 Pi Entry ID/Parent ID/Label 实现 Tree 导航。
- [ ] 通过 RPC 实现 Session 切换、New、Fork、Clone、Stats、Export。
- [ ] 通过 RPC 实现 Model 和 Thinking Level Picker。
- [ ] 完成 M2 对应的 Pi 行为测试。

## M3：Pi 原生扩展兼容

- [ ] Slash Command 建议直接来自 `get_commands`。
- [ ] 展示 Pi 原生 Extension、Skill、Prompt、Theme 的来源、路径和错误。
- [ ] 实现 `select`、`confirm`、`input`、`editor` 的请求/响应。
- [ ] 展示或按约定忽略 `notify`、`setStatus`、`setWidget`、`setTitle`、`set_editor_text`。
- [ ] 对 `custom()` 等 TUI-only 能力遵循 Pi RPC 的 `undefined`、no-op 或错误语义。
- [ ] 不创建桌面专属 Extension API、资源目录、市场、签名或权限系统。

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
