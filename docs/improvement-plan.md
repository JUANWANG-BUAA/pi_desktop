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

## S2 RPC 传输层健壮性（P0）✅ 已完成

- [x] 请求超时：默认 60s；compact/export 覆盖为 5 分钟；超时不杀进程、不污染后续命令。
- [x] 关闭语义：close stdin → 3s 宽限 → SIGTERM → 3s 宽限 → SIGKILL，不再可能无限挂起。
- [x] 首个监听者接入前缓冲事件（上限 4096 条），消除 broadcast 丢弃竞态。
- [x] 未匹配/迟到 response 不再泄漏进 events 流，改走 errors 诊断。
- [x] JsonlFramer：按"remainder+当前块"增量切分（O(chunk)），最大行长 64M 保护。
- [x] stdout 畸形 UTF-8 捕获后路由到 errors 流（不再逃逸为未捕获 zone 错误）。
- [x] stderr 使用 allowMalformed 解码且解码错误只做诊断，不再杀 Pi 进程。
- [x] connect/restart/reconnectIn 生命周期忙锁，杜绝重复点击并发启动两个 Pi 进程。
- [x] 测试：2MB 大记录、超时、事件缓冲、迟到响应诊断、坏 UTF-8 stderr（48 个测试通过）。

## S3 前端修复（P1）✅ 已完成

- [x] 草稿持久化：composer 文本由 shell 持有，landding/会话布局切换不再丢草稿；按 sessionId 隔离，会话间不串草稿。
- [x] 快捷键跨平台对齐：密度切换与 Abort 补 Ctrl 变体。
- [x] Markdown：有序列表保留序号、链接可点击（复制 URL + 提示，不引入 url_launcher）、水平分割线；新增 3 个 widget 测试。
- [x] 字体族补 Windows/Linux 回退（Segoe UI / Microsoft YaHei / Ubuntu / Noto / Cascadia / DejaVu）。
- [x] PromptBar：`set_editor_text` 改为连接变更监听（不再在 build 里做副作用）；输入框字号跟随 textScale。
- [x] 归档面板可拖拽调宽（复活 setArchiveWidth）。
- [x] 切换会话时 Transcript 滚动位置重置到底部（不再沿用上一会话位置）。
- [x] 大图附件：PNG 重编码超限时迭代缩放直到落入 6MB 预算（不再直接报错）。
- [x] Windows：目录/资源发现回退 USERPROFILE。
- [x] context bar Export 捕获连接中断异常。
- [x] 删除死代码：PaneFrame、QuietButton.expanded、_SlotRow、不可达插入分支。
- [x] golden 按新布局重新生成。

## S4 测试补齐（P1）✅ 已完成

- [x] `test/support/pi_test_host.dart` 共享 Pi 版本/可用性检测，消除两处复制粘贴。
- [x] smoke 测试断言 PATH 上的 pi 版本等于 docs/pi-baseline.md 固定基线 0.84.2（版本漂移必须走基线更新流程）。
- [x] errors 流 / 协议错误路径测试（已在 S2：迟到响应诊断、坏 UTF-8 stderr）。
- [x] 大 payload framing 测试（已在 S2：2MB 单记录 + 行长上限单测）。
- [x] abort 命令直通测试（fixture 新增 abort）。

## S5 文档与状态同步

- [ ] `docs/validation.md` 更新：私有目录扫描与 Session JSONL 只读预览的合同偏差需要决策，先如实记录。
- [ ] `docs/implementation-plan.md` / README 状态与本轮修复同步。

## 不做（边界原因）

- url_launcher / WebView / 任何 Provider 直连（边界扫描会拦截）。
- 自动重试/自动继续编排（合同禁止；Retry 只展示 Pi 事件与转发官方命令）。
