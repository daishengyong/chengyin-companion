# 澄音 Companion 新用户快速上手

简体中文 · [English](QUICKSTART.md)

这份指南面向第一次使用源码版的普通用户。公开仓库不包含权利待审的内置人物媒体，
但完整交互、提醒、小游戏、Content Pack 和本地事件协议都可以运行。

## 1. 安装前确认

- Apple Silicon Mac（M1/M2/M3/M4）
- macOS 14 或更高版本
- 至少 2 GB 可用空间
- Xcode Command Line Tools
- Python 3.9 或更高版本

如果缺少命令行工具，使用 Apple 的系统安装入口：

```bash
xcode-select --install
```

## 2. 最省事的方法：交给 Codex

把下面整段发给 Codex：

```prompt
请从 https://github.com/daishengyong/chengyin-companion 安装并启动 Chengyin Companion。
先检查 Apple Silicon、macOS 14+、Xcode Command Line Tools、Python 3.9+ 和 2 GB 可用空间。
克隆到 ~/ChengyinCompanion；如果该目录有用户修改，不要覆盖，改用新的临时克隆。
先运行 ./scripts/bootstrap-local.sh --check-only，通过后再运行 ./scripts/bootstrap-local.sh。
不要使用 sudo，不要绕过 macOS 安全机制，不要读取或上传密钥，不调用 Seedance/TTS，
也不要修改 ~/.codex/config.toml。最后报告安装版本、位置和启动结果。
```

安装器会构建当前源码、事务式安装到 `/Applications/Chengyin Companion.app`、保留旧版本
备份、重新启动，并核对正在运行的应用身份。失败时不会把半成品留在应用程序目录。

## 3. 手动安装

```bash
git clone https://github.com/daishengyong/chengyin-companion.git ~/ChengyinCompanion
cd ~/ChengyinCompanion
./scripts/bootstrap-local.sh --check-only
./scripts/bootstrap-local.sh
```

只想试玩、不安装到 `/Applications`：

```bash
cd ~/ChengyinCompanion
./scripts/preview-local.sh
```

## 4. 第一分钟怎么玩

1. 单击角色，确认短回应。
2. 双击角色，打开生活或幻想场景。
3. 长按一秒再松开，触发抚摸反馈。
4. 拖动角色，试试抱起、甩动和屏幕边缘吸附。
5. 按 `Command + Shift + M` 切换头像、半身和全屏。
6. 按 `Command + Shift + G` 开始“20 秒抓住我”。
7. 按 `Command + Shift + R` 预览一次任务完成庆祝。

公开代码版默认显示动态系统图形。要使用视频和声音，在应用设置里导入你拥有使用权的
`.chengyinpack`；导入前会检查来源声明、路径、大小、哈希、媒体解码和失败回退。

## 5. 让自己的 Codex 项目触发完成庆祝

自动任务庆祝是显式加入、按项目生效的能力。把下面规则加入你自己项目的 `AGENTS.md`，
不要把一次 Codex 回复结束误报成整个任务完成：

````markdown
# Chengyin Companion completion event

Only when the primary Codex agent has genuinely completed the user's concrete
objective and all required checks have passed, run exactly once immediately
before the final response:

```bash
if [ -x "/Applications/Chengyin Companion.app/Contents/SharedSupport/CompanionEventEmitter" ]; then
  "/Applications/Chengyin Companion.app/Contents/SharedSupport/CompanionEventEmitter" task.completed
fi
```

Do not emit this event for progress updates, plans, questions, failed work,
subagents, previews, dry runs, or ordinary turn completion.
````

这条规则不会发送任务标题、代码、Prompt 或路径；应用只收到一个本地终态事件。

## 6. 更新、诊断和恢复

在仓库中更新源码后重新运行：

```bash
git pull --ff-only
./scripts/bootstrap-local.sh
```

检查源码、构建、已安装应用与运行进程是否一致：

```bash
./scripts/doctor.sh
```

安装会把上一个应用保存在 `dist/install-backups/`。偏好、关系记忆和本地内容包位于应用
包之外，更新不会主动删除它们。遇到问题时提交 [GitHub Issue](https://github.com/daishengyong/chengyin-companion/issues)，优先粘贴应用生成的隐私最小诊断，不要上传 API Key 或私人媒体。

## 7. 当前公开发行边界

- 源码安装是本机 ad-hoc 开发构建，不是 Developer ID 签名、公证 DMG。
- MIT 只覆盖代码和软件文档；权利未通过的 Starter 媒体不在公开仓库。
- 应用不录音、不读取 Codex 对话、不上传诊断，也不需要账户。
- 不要从非本仓库来源下载声称包含“完整版人物素材”的安装包。

## 开发者与自动化检查

```bash
./scripts/preview-local.sh --check-only --json
./scripts/run-first-use-low-impact-audit.sh --zero-authorization
./scripts/check-contribution.py --profile quick --json
python3 scripts/audit-public-source-secrets.py --json
./scripts/run-portable-source-smoke.sh
```

这些检查分别覆盖预览前置条件、零授权降级、贡献合同、秘密扫描和隔离源码包；任何一个
通过都不能替代媒体权利、Developer ID、Apple 公证和实体新 Mac 人工验收。
