# Pi Desktop

Pi Desktop 是 Pi 核心的 Flutter Desktop 原生客户端。它通过官方 `pi --mode rpc` JSONL 协议展示 Pi 的 Session、Model、Tool、Extension、Skill、Prompt、Theme 和 Package 能力。

## 当前状态

- M0：边界冻结、技术基线和 Git 仓库初始化已完成。
- M1.1：Flutter Desktop 三平台骨架和纯 UI 壳已完成；尚未接入 Pi RPC。
- 本地环境：已固定 Flutter 3.47.0 / Dart 3.13.0、Node.js 24.19.0 和 Pi 0.84.2。

## 边界

Pi 是唯一的 Agent 和事实来源。Pi Desktop 只维护纯 UI 状态，并直接调用 Pi 官方 RPC；不实现 Agent Loop、Provider Gateway、Tool 调度器、Session 数据库、Prompt 编排器或桌面专属插件协议。

详细边界合同见 [`TODO.md`](TODO.md)，架构说明见 [`docs/architecture.md`](docs/architecture.md)，分阶段执行计划见 [`docs/implementation-plan.md`](docs/implementation-plan.md)。

## 开发顺序

1. ~~安装并固定 Flutter Desktop 工具链~~（M1.1 已完成）。
2. 先实现最薄的 Pi RPC 进程传输和 JSONL framing。
3. 再实现 Session 恢复、Prompt、流式事件和 Abort。
4. 按 TODO.md 的 M2–M5 逐步扩展，不跨阶段引入新 Agent 语义。

每个阶段必须通过对应复核和测试后单独 commit；不要提交 API Key、Pi Session JSONL 或本地安装产物。
