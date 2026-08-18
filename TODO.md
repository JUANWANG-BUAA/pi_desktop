# Pi Desktop TODO

> 目标：创建一个只围绕 Pi 核心的原生桌面客户端。
>
> 本文不是产品功能愿望清单，而是**边界合同、实施顺序和逐步复核清单**。
> 任意步骤如果违反边界，必须停止，不得继续下一步。

## 0. 总原则（不可修改）

### 0.1 产品定位

Pi Desktop 是：

- Pi 核心的原生桌面 UI 客户端；
- Pi Session、Model、Tool、Extension、Skill、Prompt、Theme 和 Package 的可视化入口；
- Pi 官方 RPC/SDK 的薄客户端；
- Pi 状态与事件的展示层。

Pi Desktop 不是：

- 新的 Agent Framework；
- 新的 Harness；
- 新的工作流、任务、计划或记忆系统；
- 新的插件平台；
- 新的 Provider 抽象；
- 新的会话数据库；
- 新的 Prompt 编排器；
- Pi 的替代实现或私有分支。

### 0.2 唯一事实来源

以下内容必须由 Pi 管理，桌面端不得复制并重新定义：

- Agent 状态；
- 消息上下文；
- Tool 执行；
- Model 和 Thinking Level；
- Session JSONL；
- Branch、Fork、Clone、Tree；
- Compaction 和 Retry；
- Extension、Skill、Prompt、Theme；
- Provider 和认证状态。

桌面端只能维护纯 UI 状态，例如：

- 当前窗口尺寸和位置；
- 当前面板是否展开；
- 当前消息行是否折叠；
- 当前滚动位置；
- 当前 UI 主题模式。

这些 UI 状态不得进入 Pi 的 Agent 上下文，也不得改变 Pi 的运行语义。

### 0.3 不可越界项

以下内容禁止进入代码：

- `AppAgent`、`TaskRunner`、`WorkflowEngine`、`MemoryManager` 等自定义 Agent 层；
- 自定义 Prompt 注入器；
- 自动追加 Prompt、自动跟进、自动重试编排；
- 自定义 Sub-agent、Plan、Todo、MCP 或后台 Agent；
- 自定义插件协议、插件市场或插件生命周期；
- 自定义 Tool 抽象并隐藏 Pi 原生 Tool；
- 自定义 Provider 层并绕过 Pi；
- 自己保存一份对话历史并作为第二事实来源；
- 截取 TUI ANSI 输出再转换成 GUI；
- 在 UI 中添加未对应 Pi 原生命令或 RPC 的 Agent 功能；
- 以“用户体验优化”为理由改写用户 Prompt 或 Pi 事件。

---

## 1. 锁定技术架构

### 1.1 默认方案

- [ ] 使用 Flutter Desktop 作为跨平台原生 UI。
- [ ] 禁止 Flutter Web、WebView、HTML UI、Electron、Tauri WebView。
- [ ] 使用官方 `pi --mode rpc` 作为 Agent 进程。
- [ ] Flutter 只实现 Pi 官方 RPC 的 JSONL 客户端。
- [ ] 开发环境可以使用本地 Node/Pi 包；发布环境必须随应用携带经过验证的 Pi 运行时或官方 Pi 二进制。
- [ ] 不依赖用户机器上任意版本的全局 `pi`。
- [ ] 不创建自定义 Node Agent Host。
- [ ] 不创建自定义 Agent Loop。
- [ ] 不创建自定义 Session Manager。

### 1.2 Rust 的边界

- [ ] 第一阶段不引入 Rust Agent 层。
- [ ] 如果后续使用 Rust，只允许用于窗口、进程树、PTY、文件监听，以及作为 Pi `CredentialStore` 的系统 Keychain 存储实现等 OS 能力。
- [ ] Rust 不得读取、重写或重新解释 Pi 的 Agent 上下文。
- [ ] Rust 不得执行 LLM 调度。
- [ ] Rust 不得定义新的 Tool、Provider、Session 或 Prompt 语义。

### 1.3 技术架构复核

完成本节后必须检查：

- [ ] 架构图中只有一个 Agent：Pi。
- [ ] Pi Desktop 不能单独在没有 Pi 的情况下运行 Agent。
- [ ] 所有 Agent 事件都来自 Pi RPC。
- [ ] 所有 Agent 命令都映射到 Pi RPC 或 Pi 官方 SDK。
- [ ] 删除任何名为 harness、orchestrator、workflow、agent-service 的自定义核心模块。
- [ ] 通过复核后，才能开始实现 RPC Client。

---

## 2. 建立 Pi 版本和公共 API 基线

### 2.1 Pi 依赖基线

- [ ] 记录使用的 `@earendil-works/pi-coding-agent` 版本。
- [ ] 记录 Node.js 最低版本要求。
- [ ] 只使用 Pi 的公开导出，不导入 `src/` 内部文件。
- [ ] 记录 RPC 协议版本、Session 文件版本和支持的 Pi 版本范围。
- [ ] 固定依赖版本，禁止无审查自动升级 Pi。
- [ ] 阅读并保存以下 Pi 文档的实现依据：SDK、RPC、JSON Event、Session Format、Extensions、Packages、Models。

### 2.2 运行验证

- [ ] 启动官方 Pi RPC 进程。
- [ ] 验证 `get_state`。
- [ ] 验证 `get_messages`。
- [ ] 验证 `get_entries`。
- [ ] 验证 `get_tree`。
- [ ] 验证 `get_available_models`。
- [ ] 验证 `get_commands`。
- [ ] 验证 `prompt`、`abort`、`new_session`。
- [ ] 验证进程退出、异常退出和重复启动。

### 2.3 立即复核

- [ ] 没有调用任何其他 Agent 框架。
- [ ] 没有直接调用 Provider API。
- [ ] 没有将 Pi 消息转换成自定义消息协议后再执行。
- [ ] 没有创建额外的“会话服务”。
- [ ] 没有把 Pi RPC 结果缓存成新的 Agent 状态。

---

## 3. 实现最薄的 Pi RPC Client

### 3.1 传输层

- [ ] 使用子进程 stdin/stdout 通信。
- [ ] 按 LF (`\\n`) 解析 JSONL。
- [ ] 支持 CRLF 输入，但只把 LF 作为记录边界。
- [ ] 不使用会把 Unicode 行分隔符误判为换行的通用读取器。
- [ ] 支持带 `id` 的请求响应关联。
- [ ] 支持异步 Event 和同步 Response 同时到达。
- [ ] 支持 stderr 单独收集，不混入 stdout 协议流。
- [ ] 支持进程退出时拒绝所有未完成请求。
- [ ] 支持 abort 和正常关闭。

### 3.2 允许的 Client API

Client API 只能是 Pi RPC 的直接映射，例如：

- `prompt`
- `steer`
- `follow_up`
- `abort`
- `get_state`
- `get_messages`
- `get_entries`
- `get_tree`
- `new_session`
- `switch_session`
- `fork`
- `clone`
- `set_model`
- `cycle_model`
- `get_available_models`
- `set_thinking_level`
- `cycle_thinking_level`
- `get_available_thinking_levels`
- `set_steering_mode`
- `set_follow_up_mode`
- `compact`
- `set_auto_compaction`
- `set_auto_retry`
- `abort_retry`
- `get_session_stats`
- `get_fork_messages`
- `get_last_assistant_text`
- `set_session_name`
- `get_commands`
- `export_html`

禁止添加：

- `runTask`
- `startAgent`
- `askAndSummarize`
- `autoContinue`
- `createPlan`
- `remember`
- `delegate`
- `smartRetry`

### 3.3 立即复核

- [ ] Client 是协议客户端，不是调度器。
- [ ] Client 不决定什么时候继续调用模型。
- [ ] Client 不合并或改写 Prompt。
- [ ] Client 不对 Tool 进行二次执行。
- [ ] Client 不实现上下文压缩。
- [ ] Client 不创建 Pi 不存在的事件。

---

## 4. 设计 UI 状态模型

### 4.1 状态来源

- [ ] 当前 Pi 状态来自 `get_state` 和 RPC Events。
- [ ] 对话正文来自 `message_start`、`message_update`、`message_end`。
- [ ] `message_end.message` 是最终权威内容。
- [ ] Tool 状态来自 `tool_execution_start/update/end`。
- [ ] Session 树来自 `get_tree`。
- [ ] 增量同步使用 `get_entries(since)`。
- [ ] 队列状态来自 `queue_update`。
- [ ] Compaction 和 Retry 状态直接展示 Pi Event。
- [ ] 应用重启后优先从 Pi Session 恢复，不从本地 UI 缓存恢复对话。

### 4.2 UI Projection 规则

- [ ] 所有 UI 状态都能从 Pi 状态重新构建。
- [ ] UI 丢失后不会影响 Pi Session。
- [ ] UI 状态不写入 Pi Message。
- [ ] UI 状态不进入 LLM Context。
- [ ] 不建立第二套 `ConversationState`。
- [ ] 不建立第二套 `ToolState`。
- [ ] 不建立第二套 `SessionState`。

### 4.3 立即复核

用以下问题审查每个状态字段：

1. 这个字段是否来自 Pi？
2. 如果来自 Pi，是否可以直接映射而不是重新建模？
3. 如果不是来自 Pi，它是否纯粹属于窗口或视觉状态？
4. 它是否会影响下一个 Prompt、Tool 或 Session？
5. 如果会影响，是否已经交还给 Pi 处理？

只要第 4 项为“是”且第 5 项为“否”，立即停止并删除该状态。

---

## 5. UI 信息架构

### 5.1 主窗口

- [ ] 应用启动后直接进入最近 Pi Session 或 Session 选择界面。
- [ ] 不设计 AI 营销首页。
- [ ] 不设计“创建任务”“开始规划”“选择 Agent”等引导流程。
- [ ] 左侧为项目与 Session Archive。
- [ ] 中间为 Pi Transcript。
- [ ] 右侧为可选的 Branch/Tool/Usage Inspector。
- [ ] 底部为原始 Prompt Editor 和 Pi Footer。

### 5.2 顶部区域

只显示必要上下文：

- 当前 cwd；
- 当前 Session 名称；
- 当前 Model；
- 当前 Thinking Level；
- 当前流式状态。

禁止：

- “AI 能力等级”；
- “智能模式”；
- “Agent 人格”；
- “任务完成率”；
- Pi 未提供的健康分数或建议。

### 5.3 Transcript

- [ ] 用户消息和助手消息以文档形式展示，不使用聊天气泡。
- [ ] Assistant Markdown 可阅读、可复制、可折叠。
- [ ] Thinking 默认折叠，但可由用户展开。
- [ ] Tool Call 显示真实 Tool 名称和参数。
- [ ] Tool Result 显示真实输出、错误和截断信息。
- [ ] Edit 结果显示 Pi 提供的 Diff。
- [ ] Bash 输出支持流式更新和折叠。
- [ ] Compaction、Retry、Branch Summary 作为明确的 Pi 事件展示。
- [ ] 不把 Tool 调用伪装成“助手正在完成任务”。

### 5.4 Session Tree

- [ ] 使用 Pi 的真实 Entry ID、Parent ID 和 Label。
- [ ] 支持 Tree 导航、Branch、Fork、Clone。
- [ ] 不把 Branch 重命名为“版本”或“方案”。
- [ ] 不在桌面端自行复制 Branch 内容。
- [ ] Session 切换直接调用 Pi 的 Session API。

### 5.5 输入区

- [ ] 支持多行输入。
- [ ] 支持图片附件并按 Pi ImageContent 发送。
- [ ] 空闲时发送 `prompt`。
- [ ] 流式时明确区分 `steer` 和 `follow_up`。
- [ ] 不自动选择其中一种。
- [ ] Slash Command 建议来自 Pi `get_commands`。
- [ ] 不创建新的桌面专用 Slash Command 语法。

### 5.6 视觉设计复核

- [ ] 不使用紫色渐变、光晕、玻璃拟态、机器人头像。
- [ ] 不使用大面积圆角卡片堆叠。
- [ ] 不使用无意义的无限动画。
- [ ] 使用稳定边界、克制颜色和清晰层级。
- [ ] 普通正文、控制项、代码输出使用明确的字体角色。
- [ ] 深色模式不是纯黑背景，不改变信息架构。
- [ ] 键盘操作、焦点状态、对比度和中文输入法经过测试。

---

## 6. 实现 Pi 命令和快捷键映射

### 6.1 原则

- [ ] 每个按钮都必须对应一个 Pi 官方 RPC 或已有 Pi 概念。
- [ ] 原生命令不可用时，不创造一个同名但语义不同的替代品。
- [ ] 桌面快捷键只是 Pi 命令的另一种输入方式。
- [ ] 快捷键不会触发额外的自动 Agent 行为。

### 6.2 必须支持

- [ ] 发送 Prompt。
- [ ] Steering Message。
- [ ] Follow-up Message。
- [ ] Abort。
- [ ] New Session。
- [ ] Resume / Switch Session。
- [ ] Fork。
- [ ] Clone。
- [ ] Tree Navigation。
- [ ] Model Picker。
- [ ] Thinking Level Picker。
- [ ] Compact。
- [ ] Session Stats。
- [ ] Export。

### 6.3 立即复核

- [ ] UI 操作不会绕开 Pi RPC。
- [ ] UI 操作不会直接写 Session JSONL。
- [ ] UI 操作不会自行执行 bash、edit、write 或其他 Tool。
- [ ] UI 操作不会向 Prompt 添加隐藏文本。

---

## 7. Pi 原生扩展兼容

### 7.1 Resource Discovery

- [ ] 使用 Pi 的默认资源发现规则。
- [ ] 读取标准的 Extension、Skill、Prompt、Theme 和 Context File。
- [ ] 显示资源名称、来源、路径和加载错误。
- [ ] 不把资源复制到桌面端私有目录后再加载。
- [ ] 不新增桌面应用专属资源目录。

### 7.2 Extension UI Protocol

- [ ] 实现 `extension_ui_request`。
- [ ] 支持 `select`。
- [ ] 支持 `confirm`。
- [ ] 支持 `input`。
- [ ] 支持 `editor`。
- [ ] 支持 `notify`。
- [ ] 支持 `setStatus`。
- [ ] 支持 `setWidget`。
- [ ] 支持 `setTitle`。
- [ ] 支持 `set_editor_text`。
- [ ] 所有响应使用 Pi 的 `extension_ui_response`。
- [ ] 不创建另一套桌面 Extension UI API。

### 7.3 TUI 专用能力

- [ ] 明确记录 `ctx.ui.custom()` 等 TUI 专用能力的限制。
- [ ] 不尝试解析或模拟任意 `pi-tui` Component。
- [ ] 不定义 Flutter Component 到 Pi TUI Component 的私有转换协议。
- [ ] 对不支持的请求遵循 Pi RPC 已定义的语义（例如 `undefined`、no-op 或协议错误），不得自行替换行为。
- [ ] 如果桌面端提供兼容性提示，该提示只能是 UI 诊断，不能成为新的 UI 协议或改变 Agent 行为。
- [ ] 在文档中说明扩展如何使用 Pi 跨模式 UI API。

### 7.4 立即复核

- [ ] 用户安装的仍然是 Pi Package，而不是桌面插件。
- [ ] 扩展生命周期仍由 Pi 管理。
- [ ] 扩展错误仍通过 Pi Event 暴露。
- [ ] 桌面端没有扩展签名、市场、沙箱或权限模型的私有替代品。

---

## 8. Model、Provider 和认证

### 8.1 Model

- [ ] 模型列表来自 Pi。
- [ ] 模型切换调用 Pi `set_model`。
- [ ] Thinking Level 调用 Pi `set_thinking_level`。
- [ ] 自定义模型通过 Pi `models.json` 或 Pi 原生 Provider 机制加载。
- [ ] 不建立桌面端 Model Registry。
- [ ] 不直接调用 OpenAI、Anthropic 或其他 Provider API。

### 8.2 Auth

- [ ] 优先使用 Pi 的标准认证、`auth.json`、环境变量和 OAuth 能力。
- [ ] 如果使用 OS Keychain，只能作为 Pi `CredentialStore` 的底层存储实现，不得建立第二套凭据模型。
- [ ] 不在桌面端保存第二份 API Key。
- [ ] 不把 API Key 放入 SQLite、日志、命令行参数或 Session。
- [ ] 如果 RPC 没有暴露某项认证操作，只能调用 Pi 官方 SDK 的对应能力。
- [ ] 任何 SDK 调用必须是直接转发，不得附带新的 Agent 逻辑。

### 8.3 立即复核

- [ ] 桌面端不是 Provider Gateway。
- [ ] 桌面端不重写 Provider 请求。
- [ ] 桌面端不做模型路由、自动降级或自定义重试。
- [ ] 模型可用性和认证状态以 Pi 返回为准。

---

## 9. Session 和文件存储

### 9.1 Session

- [ ] 使用 Pi JSONL Session。
- [ ] 使用 Pi 的 Session Directory。
- [ ] 使用 Pi 的 SessionManager/RPC 管理 Session。
- [ ] 不直接修改 Session JSONL。
- [ ] 不将消息复制到 SQLite。
- [ ] 不使用桌面数据库替代 Session Tree。
- [ ] 不自行实现 Session migration。

### 9.2 桌面端本地配置

只允许保存纯 UI 配置：

- [ ] 窗口位置。
- [ ] 窗口大小。
- [ ] 面板宽度。
- [ ] UI 浅色/深色模式。
- [ ] UI 字体和显示密度。
- [ ] 上次打开的窗口状态。
- [ ] UI 主题偏好只能是桌面显示设置；不得新增桌面 Theme Extension API，Pi 原生 Theme 仍按 Pi 的资源机制处理。

禁止保存：

- [ ] Agent Memory。
- [ ] Prompt 历史副本。
- [ ] Tool 结果副本作为事实来源。
- [ ] 自定义 Session 元数据。
- [ ] 自定义 Model 状态。

### 9.3 立即复核

删除桌面端本地配置后：

- [ ] Pi Session 仍然完整。
- [ ] Pi 可以从原目录恢复。
- [ ] 用户不会丢失 Prompt、Branch 或 Tool Result。
- [ ] 桌面端不会因为 UI 缓存丢失而改变 Agent 行为。

---

## 10. 安全边界

### 10.1 不改变 Pi 默认语义

- [ ] 不在桌面端静默拦截 Tool Call。
- [ ] 不在桌面端静默修改 bash 命令。
- [ ] 不在桌面端静默修改路径。
- [ ] 不在桌面端静默限制 Tool 参数。
- [ ] 不在桌面端增加自定义确认流程来替代 Pi Extension。
- [ ] 如果用户需要权限门禁，使用 Pi 原生 Extension 机制。
- [ ] 桌面端只负责展示 Pi Extension 发出的确认请求。

### 10.2 系统层安全

- [ ] 进程启动、关闭和崩溃处理不泄漏密钥。
- [ ] stdout 只输出 RPC JSONL。
- [ ] stderr 不进入对话上下文。
- [ ] 日志默认不记录 Prompt、API Key 或完整 Tool 输出。
- [ ] 发行版中不执行用户未请求的后台命令。
- [ ] 应用退出时正常结束 Pi Session。

### 10.3 立即复核

- [ ] 安全逻辑没有变成新的 Agent Policy Engine。
- [ ] 没有新增 `PermissionManager` 作为 Pi 语义层。
- [ ] 没有为了安全而偷偷改变 Pi Tool 的结果。
- [ ] 所有需要用户确认的行为，都能追溯到 Pi Extension 或操作系统。

---

## 11. 测试计划

### 11.1 RPC 测试

- [ ] JSONL 分包测试。
- [ ] UTF-8 多字节字符测试。
- [ ] CRLF 测试。
- [ ] 异步 Event 和 Response 交错测试。
- [ ] 请求超时和进程退出测试。
- [ ] abort 测试。
- [ ] stderr 隔离测试。
- [ ] 大 Tool 输出测试。

### 11.2 Pi 行为测试

- [ ] 新建 Session。
- [ ] 恢复最近 Session。
- [ ] 切换 Session。
- [ ] Fork。
- [ ] Clone。
- [ ] Tree 导航。
- [ ] Compaction。
- [ ] Auto Retry。
- [ ] Model 切换。
- [ ] Thinking Level 切换。
- [ ] Steering 和 Follow-up 队列。
- [ ] 图片消息。
- [ ] Tool 执行和错误。

### 11.3 扩展兼容测试

- [ ] Skill 加载。
- [ ] Prompt Template 加载。
- [ ] Extension Tool 加载。
- [ ] Extension Command 加载。
- [ ] `select`。
- [ ] `confirm`。
- [ ] `input`。
- [ ] `editor`。
- [ ] `notify`。
- [ ] `setStatus`。
- [ ] `setWidget`。
- [ ] Extension Error。
- [ ] TUI-only 能力按约定失败或降级，不能静默改写。

### 11.4 越界测试

- [ ] 扫描是否出现第二套 Agent 状态。
- [ ] 扫描是否出现自定义 Prompt 注入。
- [ ] 扫描是否出现自定义 Tool 调度。
- [ ] 扫描是否出现自定义 Provider 请求。
- [ ] 扫描是否出现独立会话数据库。
- [ ] 扫描是否出现插件市场或插件 API。
- [ ] 扫描是否出现自动后台任务。
- [ ] 扫描是否出现 TUI ANSI 抓取。

---

## 12. 发布和打包

- [ ] macOS、Windows、Linux 分别携带经过验证的 Pi 运行时。
- [ ] 不要求用户自行安装 Node 或 Pi。
- [ ] 不使用用户全局 Pi 配置作为唯一运行依赖。
- [ ] 发行版中的 Pi 版本和桌面端版本建立明确兼容关系。
- [ ] 完成各平台代码签名和安装测试。
- [ ] 验证升级不会破坏已有 Pi Session。
- [ ] 验证卸载不会删除用户的 Pi Session、Extension、Skill 或配置。
- [ ] 提供 Pi 版本、RPC 协议版本和资源加载诊断信息。
- [ ] 不在安装包中内置私有 Extension、Skill、Prompt 或 Tool。

### 发布前复核

- [ ] 安装后的应用仍然只是 Pi 客户端。
- [ ] 删除桌面应用后，用户的 Pi 数据仍可被官方 Pi 使用。
- [ ] 用户可以脱离桌面端继续使用官方 Pi。
- [ ] 用户可以脱离桌面端维护 Extension、Skill、Prompt 和 Model 配置。

---

## 13. 每个步骤的强制复核模板

每完成一个 TODO，必须在进入下一个 TODO 前回答以下问题：

### Pi 核心复核

- [ ] 这一步是否直接使用 Pi 官方 RPC 或公开 SDK？
- [ ] 是否导入了 Pi 内部实现文件？
- [ ] 是否绕过 Pi 直接调用 Provider 或 Tool？
- [ ] 是否改变了 Pi 的消息、Session、Model 或 Tool 语义？

### Harness 复核

- [ ] 是否出现了新的 Agent 调度器？
- [ ] 是否出现了新的任务、计划、记忆或工作流抽象？
- [ ] 是否出现了自动 Prompt、自动 Follow-up 或后台运行？
- [ ] 是否出现了第二个事实来源？

### 插件复核

- [ ] 是否新增了桌面专用插件 API？
- [ ] 是否新增了桌面专用资源目录？
- [ ] 是否新增了插件市场、安装器或权限系统？
- [ ] 用户自定义是否仍然通过 Pi 原生 Extension、Skill、Prompt、Theme 和 Package？

### UI 复核

- [ ] 这是 Pi 状态的展示，还是新的 Agent 功能？
- [ ] 是否使用了 Pi 原有术语？
- [ ] 是否存在 AI 营销化、装饰性动画或无意义的卡片堆叠？
- [ ] 是否支持键盘、焦点、中文输入法和长文本阅读？

### 事实来源复核

- [ ] 删除桌面端缓存后，Pi Session 是否仍然正确？
- [ ] 重启桌面端后，是否从 Pi 恢复状态？
- [ ] 用户是否可以继续使用官方 Pi？

**以上任意一项不通过，当前步骤标记为阻塞，不得合并。**

---

## 14. 里程碑顺序

### M0：边界冻结

- [x] 完成本文件复核。
- [x] 锁定 Flutter Desktop + 官方 Pi RPC。
- [x] 明确不做的功能全部登记。
- [x] 通过越界审查。

### M1：最小可运行客户端

- [ ] 启动官方 Pi RPC。
- [ ] 读取并展示 Session。
- [ ] 发送 Prompt。
- [ ] 展示流式文本。
- [ ] 支持 Abort。
- [ ] 通过逐步复核。

### M2：完整 Pi 会话体验

- [ ] Tool 展示。
- [ ] Thinking 展示。
- [ ] Session Tree。
- [ ] Fork / Clone / Resume。
- [ ] Compaction / Retry。
- [ ] Model / Thinking Level。
- [ ] 通过逐步复核。

### M3：Pi 原生扩展兼容

- [ ] Commands。
- [ ] Skills。
- [ ] Prompts。
- [ ] Themes。
- [ ] Extension UI Protocol。
- [ ] 明确 TUI-only 限制。
- [ ] 通过逐步复核。

### M4：原生桌面完成度

- [ ] 键盘操作。
- [ ] 中文输入法。
- [ ] 可访问性。
- [ ] 主题和密度。
- [ ] 多平台打包。
- [ ] 进程生命周期。
- [ ] 通过逐步复核。

### M5：发布

- [ ] 兼容性矩阵完成。
- [ ] 越界扫描完成。
- [ ] Pi Session 升级/降级测试完成。
- [ ] 用户配置保留测试完成。
- [ ] 发行版代码签名完成。
- [ ] 最终人工复核完成。

---

## 15. 最终发布前的一票否决清单

出现以下任意情况，不得发布：

- [ ] Pi Desktop 有自己的 Agent Loop。
- [ ] Pi Desktop 有自己的 Memory、Plan、Todo 或 Workflow。
- [ ] Pi Desktop 修改了用户 Prompt。
- [ ] Pi Desktop 在后台自动继续工作。
- [ ] Pi Desktop 绕过 Pi 直接调用模型 Provider。
- [ ] Pi Desktop 保存第二份会话历史。
- [ ] Pi Desktop 定义了自己的插件机制。
- [ ] Pi Desktop 内置了无法通过 Pi 原生机制关闭的 Tool。
- [ ] Pi Desktop 用 TUI 抓取或模拟 GUI。
- [ ] Pi Desktop 的主界面更像 AI 营销首页，而不是 Pi 工作控制台。
- [ ] 删除桌面应用后，用户无法继续使用自己的 Pi 数据。

> 最终判断标准：
>
> **如果删除所有桌面 UI，剩下的仍然应该是完整、标准、可独立运行的 Pi。**
>
> **如果桌面端新增的任何能力不能解释为“Pi 原生状态的展示或 Pi 官方 API 的调用”，就应该删除或延期。**

---

## 16. 本文自检记录

> 以下只证明 TODO 文档本身已经完成复核，不代表任何产品代码已经实现。

### 复核轮次一：边界复核

- [x] 明确 Pi 是唯一 Agent。
- [x] 明确桌面端只能是 UI 和官方协议客户端。
- [x] 明确禁止自定义 Harness、Agent Loop、插件协议和第二事实来源。
- [x] 明确用户扩展只能使用 Pi 原生 Extension、Skill、Prompt、Theme 和 Package。
- [x] 明确 TUI-only 扩展的兼容性边界。

### 复核轮次二：技术复核

- [x] 默认架构为 Flutter Desktop + 官方 `pi --mode rpc`。
- [x] 明确禁止 WebView、Electron、Tauri WebView 和 TUI ANSI 抓取。
- [x] 明确 RPC Client 不得拥有 Agent 调度职责。
- [x] 明确 Session、Model、Tool、Context 和认证以 Pi 为事实来源。
- [x] 明确 Rust 只能作为可选 OS 能力层。

### 复核轮次三：UI 复核

- [x] UI 使用 Pi 原有术语。
- [x] UI 采用文档/控制台/会话归档方向，而不是聊天机器人方向。
- [x] 已禁止 AI 营销化、光晕、渐变和无意义动画。
- [x] 已要求键盘、焦点、中文输入法、长文本和可访问性测试。
- [x] 已要求所有按钮都映射到 Pi 官方 RPC 或已有 Pi 概念。

### 复核轮次四：存储与安全复核

- [x] 没有把 SQLite 或其他数据库列为 Agent 历史来源。
- [x] 没有增加桌面端自己的 Permission/Policy Engine。
- [x] 没有允许桌面端绕过 Pi 直接执行 Tool 或调用 Provider。
- [x] 已要求删除桌面端 UI 缓存后 Pi Session 仍然可用。
- [x] 已要求删除桌面应用后用户仍可使用官方 Pi。

### 当前结论

- [x] 文档边界复核通过。
- [x] 文档结构检查通过。
- [x] M0 已完成；产品代码仍须从 M1.1 的 Flutter 工具链准备开始。

---

## 17. 第二次独立越界审查

### 审查范围

本轮只审查以下问题：

1. 是否引入了 Pi 之外的 Agent/Harness 运行语义；
2. 是否引入了其他产品常见但 Pi 明确不提供的功能；
3. 是否定义了桌面端私有的插件、Provider、Session 或 Prompt 机制；
4. 是否把普通 UI 需求误写成 Agent 能力；
5. 是否存在没有明确来源的外部 Harness 设计。

### 审查结果

- [x] 没有发现独立 Agent Loop、任务调度器、Workflow、Memory、Plan、Todo、Sub-agent 或后台 Agent 的正向设计。
- [x] 相关词汇只出现在禁止项、复核项和一票否决项中，没有被设计为产品能力。
- [x] 没有发现其他 Harness 产品的品牌、专有概念或私有协议被引入。
- [x] Session、Branch、Fork、Clone、Tree、Compaction、Retry、Model、Thinking Level、Tool 和 Extension 均对应 Pi 已有概念。
- [x] UI 的 Archive、Transcript、Inspector 只是展示布局，不拥有新的 Agent 状态或调度语义。
- [x] Flutter 只作为原生桌面 UI，官方 Pi RPC 才是 Agent 进程和事实来源。
- [x] 没有定义桌面端插件 API、桌面资源格式、插件市场或私有扩展生命周期。
- [x] 没有定义第二套 Provider、Model Registry、Session Store 或 Credential Model。
- [x] 已明确 OS Keychain 只能作为 Pi `CredentialStore` 的存储实现。
- [x] 已明确 TUI-only 能力必须遵循 Pi RPC 的既有 `undefined`、no-op 或错误语义。
- [x] 已明确桌面 UI 主题偏好不能演变成新的 Theme Extension API。
- [x] 已明确安全确认不能演变成桌面端私有 Permission/Policy Engine。

### 本轮结论

- [x] **TODO 文档的设计原则层面未发现越界。**
- [x] **未发现私自增加其他 Harness 产品设计的情况。**
- [x] **文档符合 Pi 的最小核心、可扩展但不强制扩展、由用户通过 Pi 原生机制自定义的思想。**
- [ ] 不能将本结论等同于产品代码已经合规；每次实现都必须重新执行第 13 节复核。
- [ ] M0 未完成前，不得开始产品代码实现。
