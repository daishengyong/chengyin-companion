# 澄音 Companion 节目制片人交接包

这个包用于把整期节目的事实、素材、可安装产品和制作流程交给另一位真人制片人及她自己的 Codex。

## 10 分钟启动

1. 不要只打开 ZIP 预览；完整解压到一个新的工作目录。
2. 把本包根目录和 `01-CODEX-START-PROMPT.md` 一起交给 Codex。
3. 让 Codex 先校验 `SHA256SUMS.txt`，再运行 `producer-tools/Check Production Environment.command`。
4. 回答 Codex 最多三个方向问题，先锁定平台、时长、主持方式和是否现场生成。
5. 默认先用现成素材录节目；火山账号和 Seedance 不是开工前置条件。

## 目录

- `program-materials/`：节目脚本、镜头、环境、录制与发布材料。
- `editorial-assets/`：可直接用于剪辑的应用素材和 Seedance 幕后素材。
- `product-packages/`：安装包、DMG、源码包和校验。
- `generation-workbench/`：只有明确要重新生成时才使用。
- `producer-tools/`：环境检查与无秘密配置模板。

## 当前边界

这是 `preproduction_ready` 的交接包，不是节目成片。应用仍是个人预览版；公开发行前需要完成媒体权利、许可证、Developer ID 签名和 Apple 公证复核。

任何新的 Seedance/TTS/API 调用、云上传、购买或发布都需要真人当轮明确确认。
