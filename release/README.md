# 澄音 Companion 本轮交付

## 建议使用顺序

1. `Chengyin-Companion-Episode-01-Production-Kit.zip`：先审节目总稿、逐镜表和 Codex 主提示词。
2. `Chengyin-Companion-*-macos-arm64-preview.zip`：节目中演示的直接安装包。
3. 同版本 `.dmg`：另一种分发/演示形式，内容与 ZIP 安装包一致。
4. 同版本 `-source.zip`：包含克隆、构建、测试、改造和贡献契约的源码预览包。
5. `*-SHA256SUMS.txt`：校验本轮交付文件在传输后是否保持一致。

## 当前状态

- 支持：Apple Silicon、macOS 14+。
- 安装位置：`~/Applications/Chengyin Companion.app`。
- 安装器不会修改 `~/.codex/config.toml`，只在全局 AGENTS 中写入一个可识别、可卸载的规则区块。
- 源码包带有 `SOURCE-PACKAGE.json` 与逐文件 SHA-256 清单，并通过不可信 ZIP、解压后完整应用产品编译和贡献矩阵；SHA 清单只证明包内一致性，不认证来源。
- ZIP、DMG、源码边界、隔离 HOME 安装、诊断和临时事件桥按各自回执分层验证；没有回执的目标机 GUI 项仍是待验证。
- 当前是个人预览包：ad-hoc 签名，尚未 Developer ID 签名或 Apple 公证。
- 媒体和源码许可证仍需公开发行复核，因此现在不要把它描述为正式公开商业版本。

详细状态见节目制作包中的 `08-REVIEW-AND-DELIVERY-RECEIPT.md`。
