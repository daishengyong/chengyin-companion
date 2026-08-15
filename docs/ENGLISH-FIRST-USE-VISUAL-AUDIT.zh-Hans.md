# 英文首次使用视觉审计

[English](ENGLISH-FIRST-USE-VISUAL-AUDIT.md) · 简体中文

本契约把英文首次使用从“源码里有翻译”提升为可重复的五步窗口走查，同时明确保留
人工 VoiceOver 与物理干净 Mac 两个人工边界。它是工程证据，不是无障碍认证或公开发行批准。

## 五步路径

隔离实验副本使用独立 Bundle ID、独立 UserDefaults、临时内容库、临时事件收件箱和空的
Codex 会话目录，不读取用户现有伴侣内容。走查依次验证：轻点邀请、双击邀请、选择本地陪伴
节奏、模拟共同工作弧、仅在终点展示完成。每一步记录当前运行窗口截图、窗口是否完整可见、
英文 OCR 命中和已有辅助功能权限下可读取的稳定控件标识。

## 运行方式

只验证源码、隔离和回执契约，不启动图形界面：

```bash
./scripts/run-english-first-use-visual-audit.sh --source-only
```

在已经具备屏幕捕捉能力的 Mac 上运行当前构建的隔离视觉走查：

```bash
./scripts/run-english-first-use-visual-audit.sh
```

运行本机负向矩阵与隔离根测试：

```bash
./scripts/run-english-first-use-visual-audit-smoke.sh
```

真实走查把五张 PNG 和 `receipt.json` 写入 `dist/audits/english-first-use/`。回执不包含用户名、
绝对路径、媒体文件名、任务标题或凭据。该流程不联网，不调用 Seedance/TTS，不读取 API Key，
不修改 Codex 配置，也不会触碰 `/Applications` 中的安装版。

## 证据分层

`PASS_WITH_PENDING` 只表示隔离实验副本完成五步窗口捕捉，英文文案可见，交互能够推进，
并且运行时数据根未接触共享用户内容。辅助功能已授权时会额外记录 AX 控件标识；没有既有授权
时只标记 `PENDING_RUNTIME_ASSISTIVE_TECHNOLOGY`，不会请求新权限。

以下状态始终保留：`PENDING_HUMAN_REVIEW` 需要人工开启 VoiceOver 检查朗读顺序、焦点移动与
发音质量；`PENDING_EXTERNAL_DEVICE` 需要在物理干净英文 Mac 上检查首次下载、Gatekeeper、
缩放与视觉布局。回执固定为 `NOT_PUBLIC_RELEASE_READY`，不能外推签名、公证、媒体权利或最终
许可证已经通过。更多硬件与低动态边界见[新 Mac 首次使用与低动态效果审计](FIRST-USE-AND-LOW-IMPACT-AUDIT.md)。

供自动真实性检查使用，本证据层明确标记为 `human_review_required`，不代表无障碍人工审阅已完成。

## 失败与恢复

失败使用 `FIRST_USE_VISUAL_AUDIT_*` 稳定错误码，并给出可执行恢复动作。截图失败时只建议核对
既有屏幕捕捉能力；英文缺失时检查对应截图与本地化；交互未推进时修复稳定控件标识或手势。
任何失败都不会伪造截图、放宽英文判断，或把待人工验证状态提升为通过。
