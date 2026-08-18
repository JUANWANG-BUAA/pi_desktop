# Pi Desktop

Pi Desktop 是 Pi 核心的 Flutter Desktop 原生客户端。它通过官方 `pi --mode rpc` JSONL 协议展示 Pi 的 Session、Model、Tool、Extension、Skill、Prompt、Theme 和 Package 能力。

## 当前状态

- M0：边界冻结、技术基线和 Git 仓库初始化已完成。
- M1.1：Flutter Desktop 三平台骨架和纯 UI 壳已完成；尚未接入 Pi RPC。
- M1.2：Pi RPC Transport、严格 JSONL framing、响应关联和生命周期测试已完成。
- M1.3：Session 状态恢复、Transcript 流式投影、Prompt、Steer、Follow-up、Abort 和显式重启已完成。
- M2：Tool/Thinking/Queue/Compaction/Retry/Tree/Model/Session 控件已接入；真实 Provider 行为矩阵待带凭据的 Pi Session 回归。
- M3：Pi Extension UI 请求/响应、状态展示和基于 `get_commands` 的 Slash Command 建议已接入；资源诊断待继续完成。
- 本地环境：已固定 Flutter 3.47.0 / Dart 3.13.0、Node.js 24.19.0 和 Pi 0.84.2。

## 边界

Pi 是唯一的 Agent 和事实来源。Pi Desktop 只维护纯 UI 状态，并直接调用 Pi 官方 RPC；不实现 Agent Loop、Provider Gateway、Tool 调度器、Session 数据库、Prompt 编排器或桌面专属插件协议。

详细边界合同见 [`TODO.md`](TODO.md)，架构说明见 [`docs/architecture.md`](docs/architecture.md)，分阶段执行计划见 [`docs/implementation-plan.md`](docs/implementation-plan.md)。

## 开发顺序

1. ~~安装并固定 Flutter Desktop 工具链~~（M1.1 已完成）。
2. ~~实现最薄的 Pi RPC 进程传输和 JSONL framing~~（M1.2 已完成）。
3. ~~实现 Session 恢复、Prompt、流式事件和 Abort~~（M1.3 已完成）。
4. ~~按 TODO.md 的 M2–M5 逐步扩展~~（M2 控件实现已接入；先完成真实 Pi 行为矩阵，再进入 M3）。

每个阶段必须通过对应复核和测试后单独 commit；不要提交 API Key、Pi Session JSONL 或本地安装产物。
