# 制片人与观众环境准备

这期节目应先让人看到效果，再解释环境。默认使用随包的现成视频、音频和安装包，不要求制片人先注册云服务。只有要现场重新生成 Seedance 素材时，才进入火山方舟配置。

## 1. 三条复现路径

| 路径 | 能完成什么 | 必需环境 | 是否会产生云端费用 |
|---|---|---|---|
| A. 离线录制 | 播放现成素材、讲解架构、剪辑节目 | 任意主流剪辑电脑、解压工具 | 否 |
| B. 安装与改造 | 安装伴侣、录屏交互、修改 SwiftUI、重新打包 | Apple Silicon Mac、macOS 14+、Codex、Xcode Command Line Tools | 否 |
| C. 现场生成 | 用 Seedance Mini 新生成一条原生音画视频 | B 的全部条件、Python、火山方舟 API Key、匹配的 Mini 资源包；使用视频/音频输入时还需私有 TOS | 是，提交任务即可能扣费 |

节目主线建议走 A + B；C 只演示一条 4 秒校准片。即使 C 因账号、审核、排队或余额失败，节目仍能完整录制。

## 2. 制片电脑最低清单

### 只做节目剪辑

- 20 GB 可用磁盘空间；如果生成代理文件，建议 50 GB。
- 支持 H.264/AAC 的剪辑软件，例如 Final Cut Pro、DaVinci Resolve 或 Premiere Pro。
- FFmpeg/FFprobe，用于批量检查画幅、音轨、响度和损坏文件。
- 1080p 屏幕录制能力；录制系统音频时先做 20 秒回放测试。

### 现场安装和改造伴侣

- Apple Silicon Mac（M1 或更新），macOS 14 或更新。
- Codex 桌面应用、CLI 或 IDE 形态之一，并已用制片人自己的账号登录。
- Xcode Command Line Tools；源码要求 Swift 5.10 兼容工具链。
- Git、Python 3.10+、FFmpeg/FFprobe。
- 至少 15 GB 可用空间，避免构建缓存和剪辑代理争抢空间。

Codex 的账号额度只负责 Codex 自己的智能体工作，不会替代火山方舟、Seedance、TOS 或 TTS 的计费与凭据。

## 3. macOS 工具准备

先运行交接包里的 `Check Production Environment.command`。它只检查，不安装、不读取 Key 内容、不发起网络生成。

缺少工具时可在 Codex 引导下安装。典型准备方式如下，实际版本以录制当天官方要求为准：

```bash
xcode-select --install
brew install ffmpeg python git
python3 -m venv .venv-seedance
source .venv-seedance/bin/activate
python -m pip install --upgrade pip
python -m pip install -r producer-tools/requirements-seedance.txt
```

若电脑没有 Homebrew，也可以使用系统 Git、Apple Command Line Tools，以及从 Python 官方渠道安装的 Python；不要为了节目绕过 macOS 安全机制。

## 4. 火山方舟与 Seedance Mini 准备

### 4.1 账号与产品

1. 注册并完成火山引擎要求的实名认证。
2. 在火山方舟“开通管理”中开通本轮要使用的 **Doubao-Seedance-2.0-mini**。
3. 购买或确认仍有余量的 **Seedance 2.0 Mini 专属资源包**。Standard、Fast、Mini 的资源包不能互相抵扣。
4. 在方舟 API Key 管理中创建独立 Key。节目专用 Key 不应复用长期生产 Key。
5. 在费用中心记录资源包实例、余量、到期日、最近扣费与预警阈值。

本项目当前经过验证的精确模型 ID 是：

```text
doubao-seedance-2-0-mini-260615
```

模型 ID、API 参数、价格和资源包规则都可能变化。录制当天必须以火山方舟的模型列表、[创建视频生成任务 API](https://www.volcengine.com/docs/82379/1520757?lang=zh)、[查询视频生成任务 API](https://www.volcengine.com/docs/82379/1520758?lang=zh)和费用中心为准。不要仅因为名字中含 `mini` 就放行一个新的模型 ID。

### 4.2 API Key 安全配置

复制交接包中的模板：

```bash
cp producer-tools/seedance.env.example producer-tools/seedance.env
chmod 600 producer-tools/seedance.env
```

手工把自己的值填入 `producer-tools/seedance.env`。不要把 Key 粘贴到 Prompt、代码、截图、录屏、聊天记录、Git 仓库或节目工程。录制终端前先清屏；环境检测器只显示“已设置/未设置”，不会打印值。

需要用视频或音频做输入时，现有生成脚本会把参考素材上传到制片人自己的私有 TOS 桶，并使用一小时签名 URL；因此还需要受限的 TOS AK/SK。纯文本和本地图片输入不要求 TOS。

### 4.3 资源包不是硬停机开关

官方计费说明明确提示：资源包耗尽后可能自动转入按量后付费。因此必须同时做四层保护：

1. 控制台：只开 Mini，关闭不用的 Standard/Fast；设置推理限额、余额与资源包余量预警。
2. Key：使用独立、最小权限、节目后可立即停用的 API Key。
3. 本地：只允许精确 Mini 模型；每批最多 10 次、最多 2,000,000 资源包 Tokens，并保留 500,000 Tokens 安全余量。
4. 人工：每批调用前重新核对费用中心；先 dry-run，再用精确确认短语提交。

若控制台没有明确的“禁止资源包溢出后付费”开关，应联系火山引擎客服确认账户级限制。清空现金余额不是可靠的安全方案。

## 5. Seedance 现场演示的安全顺序

1. 用 `generation-workbench/mini-external-call-ledger.template.json` 新建本人的账本。
2. 按费用中心真实页面填写资源包实例、余量、对账时间；不要复制原作者账号数据。
3. 从 `generation-workbench/example-shot/contract.json` 复制一个新镜头合约，只做 4 秒、480p、单次校准。
4. 先运行离线检查：

```bash
python generation-workbench/scripts/seedance-safety-checks.py
python generation-workbench/scripts/generate-seedance-task-complete.py \
  --shot-dir generation-workbench/example-shot \
  --dry-run
```

5. 把 dry-run 输出中的模型、次数、预计扣除、余额来源和安全余量展示给主持人。
6. 只有主持人本轮明确确认后，才加载 `seedance.env` 并提交。不要把确认写入永久自动化。
7. 任务成功后立即保存视频、尾帧、脱敏结果、用量和 SHA256；再回控制台核对实际扣费来源。

API Explorer 的调试按钮同样可能产生真实调用与费用，不能当作免费测试。

## 6. 录制前必须通过的检查

- 安装包能解压，包内 SHA256 校验通过。
- 26 条最终角色视频均可解码；有原生音轨的片段能听见且口型匹配。
- 159 条预生成 MP3 全部存在；TTS 只作为短反馈和纯声音模式，不冒充 Seedance 原生音画。
- 屏幕录制能同时收录旁白、应用声音和系统操作。
- Codex 看得到解压后的项目文件，并能说明将使用哪些本机内容制作技能。
- 录屏中不出现 API Key、火山账号 ID、资源包实例 ID、私人路径、Codex 私密对话或未授权真人参考图。

## 7. 给观众的最短复现路线

节目中把观众引导为：

1. 下载预览安装包，双击安装，跑诊断。
2. 完成一个真实 Codex 任务，观察一次可靠的任务完成反馈。
3. 下载源码包，让 Codex 只改一个闭环，例如新的提醒、动作或小游戏。
4. 想换角色时，先用自己有权使用的原创成年角色素材做一条母片。
5. 只有要重新生成时再配置 Seedance；先一条校准，确认身份、画幅、音轨、费用和权利，再扩量。

这样观众不需要先购买任何云服务，也能得到完整、可用的体验。
