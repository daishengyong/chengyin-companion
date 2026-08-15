# 澄音 Companion：从这里开始

这是面向 Apple Silicon Mac（M1/M2/M3/M4）、macOS 14 或更高版本的个人预览安装包。

## 安装

1. 双击 `Install Chengyin Companion.command`。
2. 首次运行若被 macOS 阻止，在“系统设置 → 隐私与安全性”中选择“仍要打开”。
3. 应用默认安装到 `~/Applications/Chengyin Companion.app`，不需要管理员密码。
4. 安装器会在 `~/.codex/AGENTS.md` 加入一个有明确起止标记的完成事件规则；不会修改 `~/.codex/config.toml`。
5. 重新开始一个 Codex 任务。只有主任务真实完成后，伴侣才播放庆祝视频。

## 立即试玩

- 单击：短反应。
- 双击：生活或幻想场景。
- 长按再松开：抚摸反馈和随机动作。
- 拖拽、快速甩动、拖到屏幕边缘：不同声音与动画反馈。
- `Command + Shift + M`：切换头像、半身、全屏。
- `Command + Shift + R`：本地预览任务完成庆祝，不会伪造 Codex 任务状态。

## 诊断与卸载

- 双击 `Diagnose Chengyin Companion.command` 检查系统、应用、事件桥和 Codex 规则。
- 双击 `Uninstall Chengyin Companion.command`：应用会移到废纸篓，只删除安装器自己加入的 Codex 规则；个人记忆默认保留。

## 二次改造

完整说明见 `CUSTOMIZE.md`。如果同时下载了源码改造包，可让 Codex 从修改一个视频、一个台词或一个互动开始，不必重写整个应用。
源码预览包在 `SOURCE-PACKAGE.json` 中声明克隆、构建与贡献范围，并用
`SOURCE-SHA256SUMS.txt` 检查包内一致性；这两项不是发布者数字签名，不能单独证明来源。

## 发布边界

本包是 ad-hoc 签名的个人预览版本，未进行 Developer ID 签名和 Apple 公证。现有媒体还需要完成公开发行权利复核。它可以用于本人演示、录制和隔离电脑验证，不应被描述为已经可公开商业分发的正式版本。
