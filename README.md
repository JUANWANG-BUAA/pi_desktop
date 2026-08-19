# Pi Desktop

Pi Desktop 是 Pi 核心的 Flutter Desktop 原生客户端。它通过官方 `pi --mode rpc` JSONL 协议展示 Pi 的 Session、Model、Tool、Extension、Skill、Prompt、Theme 和 Package 能力。

许可证为 [MIT](LICENSE)。参与开发请先读 [CONTRIBUTING.md](CONTRIBUTING.md)。安全漏洞请按 [SECURITY.md](SECURITY.md) 私下报告，不要开公开 Issue。

## 快速开始（macOS）

需要已固定的工具链：Flutter 3.47.0、Dart 3.13.0、Node.js ≥22.19.0、Pi 0.84.2（详见 [`docs/pi-baseline.md`](docs/pi-baseline.md)）。

```bash
npm install --global @earendil-works/pi-coding-agent@0.84.2
flutter pub get
flutter run -d macos
```

提交前运行 `tool/check.sh`。Git hooks 不会随仓库推送，clone 后执行一次 `tool/install_hooks.sh`。CI 在每次 push/PR 上跑同一套检查，并构建 macOS / Linux / Windows Debug。

## 当前状态

- M0：边界冻结、技术基线和 Git 仓库初始化已完成。
- M1.1：Flutter Desktop 三平台骨架和纯 UI 壳已完成；macOS Debug 构建已验证。Linux/Windows 由 CI Debug 构建覆盖，安装包仍属 M5。
- M1.2：Pi RPC Transport、严格 JSONL framing、响应关联和生命周期测试已完成。
- M1.3：Session 状态恢复、Transcript 流式投影、Prompt、Steer、Follow-up、Abort 和显式重启已完成。
- M2：Tool/Thinking/Queue/Compaction/Retry/Tree/Model/Session 控件已接入；真实 Provider 行为矩阵待带凭据的 Pi Session 回归。
- M3：Pi Extension UI 请求/响应、状态展示、基于 `get_commands` 的 Slash Command 建议和 Pi 资源来源诊断已接入；完整 Extension/Skill/Prompt/Theme 发现仍受官方 RPC 暴露范围限制。
- M4：键盘快捷键、IME 安全的 Enter/换行、浅色/深色与密度、崩溃清理和 Control Room 显示层已接入；本轮又完成草稿持久化、Markdown 链接/序号、传输层超时与关闭健壮性、错误可见性等加固（详见 `docs/improvement-plan.md`）。多平台打包与签名仍属 M5。
- 本地环境：已固定 Flutter 3.47.0 / Dart 3.13.0、Node.js 24.19.0 和 Pi 0.84.2。

## 边界

Pi 是唯一的 Agent 和事实来源。Pi Desktop 只维护纯 UI 状态，并直接调用 Pi 官方 RPC；不实现 Agent Loop、Provider Gateway、Tool 调度器、Session 数据库、Prompt 编排器或桌面专属插件协议。

当前 Pi `0.84.2` RPC 仍缺 session 列表、完整资源诊断和非图片附件。产品选择 **Direction A**：向官方要这些命令（规格见 [`docs/rpc-upstream.md`](docs/rpc-upstream.md)），而不是在桌面端另做一套。在上游落地前，Archive 的 session 列表是标明的文件系统预览；非图片附件不再以 `@path` 拼进 prompt。

边界合同由 `test/boundary/boundary_scan_test.dart` 机器强制执行；提交前必须通过 `tool/check.sh`（可用 `tool/install_hooks.sh` 安装为 pre-commit 钩子）。

详细边界合同见 [`TODO.md`](TODO.md)（内部合同，不是新人入口）。公开里程碑见 [`docs/roadmap.md`](docs/roadmap.md)，架构说明见 [`docs/architecture.md`](docs/architecture.md)，分阶段执行计划见 [`docs/implementation-plan.md`](docs/implementation-plan.md)，变更记录见 [`CHANGELOG.md`](CHANGELOG.md)。

## 开发顺序

1. ~~安装并固定 Flutter Desktop 工具链~~（M1.1 已完成）。
2. ~~实现最薄的 Pi RPC 进程传输和 JSONL framing~~（M1.2 已完成）。
3. ~~实现 Session 恢复、Prompt、流式事件和 Abort~~（M1.3 已完成）。
4. M2/M3 的 Pi 原生控件和 Extension UI 已按官方 RPC 接入；M4 的键盘、主题密度与显示层已落地。真实 Provider 行为矩阵、跨平台打包和发布验证继续按 `docs/implementation-plan.md` 推进。

每个阶段必须通过对应复核和测试后单独 commit；不要提交 API Key、Pi Session JSONL 或本地安装产物。
