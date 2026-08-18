# 改进计划（执行跟踪）

> 来源：2026-08-19 全面审查（架构合同核对 + RPC/测试/UI 审计 + 与 Pi 0.84.2 `docs/rpc.md` 逐条对照）。
> 本文件只做执行跟踪；边界合同仍以 [`TODO.md`](../TODO.md) 为准。每个阶段完成后更新勾选并单独 commit。

## S1 功能性协议修复（P0）✅ 已完成

- [x] fork / switch_session：处理 Pi 返回的 `cancelled: true`，向用户反馈，不再按成功处理。
- [x] Extension UI：未知 dialog method 必须回 `cancelled` 响应，不得让 Pi 扩展挂起（TODO.md §7.3 的 undefined/no-op/错误语义）；窗口关闭时未答完的 dialog 也补发 cancelled。
- [x] Prompt/Steer/Follow-up：`success: false` 响应时恢复草稿并显示错误，不吞错、不丢用户输入。
- [x] `message_update.usage`：流式期间把 Pi 的累计 usage 投影出来（Usage 实时展示）。
- [x] `agent_settled` 后刷新 `get_session_stats`，修复 context% / token 计数漂移。
- [x] fork/switch/rename/export 等动作的失败与取消在 UI 上可见（SnackBar / Inspector 错误行）。
- [x] Landing 任务卡防重复触发（busy guard）。
- 不做：`set_auto_retry` 开关 —— Pi 0.84.2 `get_state` 不暴露该标志，桌面端自存开关状态会违反 §4.2「所有 UI 状态都能从 Pi 状态重新构建」；命令保留在 Client API 层。

## S2 RPC 传输层健壮性（P0）

- [ ] 请求超时：`sendCommand` 支持超时；compact/export 等长命令可覆盖为更长超时。
- [ ] 关闭语义：close stdin → 宽限等待 → SIGTERM → 宽限等待 → SIGKILL，不再可能无限挂起。
- [ ] 首个监听者接入前缓冲事件，消除 broadcast 丢弃竞态。
- [ ] 未匹配的 response 不再泄漏进 events 流，改走 errors 诊断。
- [ ] JsonlFramer：消除 O(n²) 重组；加最大行长保护（大 Tool 输出场景）。
- [ ] stdout 畸形 UTF-8 路由到 errors 流（不再逃逸为未捕获 zone 错误）。
- [ ] stderr 解码错误只做诊断，不再杀 Pi 进程。
- [ ] 以上每项补对应测试（扩展 fixture：慢关闭、大行、迟到响应、坏 UTF-8 stderr）。

## S3 前端修复（P1）

- [ ] 快捷键跨平台对齐：密度切换补 Ctrl 变体（Windows/Linux 当前不可用）。
- [ ] Markdown：链接可识别（复制 URL 到剪贴板，不引入 url_launcher，保持边界）。
- [ ] 去掉硬编码 Apple 字体名，改为跨平台字体族回退。
- [ ] PromptBar：`set_editor_text` 副作用移出 build；硬编码字号跟随 textScale。
- [ ] 删除死代码：PaneFrame、QuietButton.expanded、_SlotRow、不可达插入分支。
- [ ] 其余前端审计发现（待审计结果合并）。

## S4 测试补齐（P1）

- [ ] 共享 Pi 可用性检测助手，消除两处复制粘贴。
- [ ] smoke 测试断言 Pi 版本基线（0.84.2）。
- [ ] errors 流 / 协议错误路径测试。
- [ ] 大 payload（大 Tool 输出）framing 测试。
- [ ] abort 语义测试（fixture 支持 abort）。

## S5 文档与状态同步

- [ ] `docs/validation.md` 更新：私有目录扫描与 Session JSONL 只读预览的合同偏差需要决策，先如实记录。
- [ ] `docs/implementation-plan.md` / README 状态与本轮修复同步。

## 不做（边界原因）

- url_launcher / WebView / 任何 Provider 直连（边界扫描会拦截）。
- 自动重试/自动继续编排（合同禁止；Retry 只展示 Pi 事件与转发官方命令）。
