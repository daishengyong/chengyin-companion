# 可验证源码预览包契约

简体中文 · [English](SOURCE-PACKAGE-CONTRACT.md)

这份契约只回答一个范围明确的问题：澄音源码预览 ZIP 是否真正包含克隆、构建、测试、改造和贡献所需的公开表面，同时没有夹带本地缓存、私有路径或生成后的发行产物。它不把这个产物声明成已经可以公开发行。

## 构建与验证

从可信的仓库检出目录运行：

```bash
source_package_root="$(mktemp -d)"
./scripts/check-python-runtime.sh
./scripts/build-portable-source.sh --output "$source_package_root/chengyin-source.zip"
python3 scripts/audit-portable-source.py "$source_package_root/chengyin-source.zip" --json
python3 scripts/audit-public-source-secrets.py --json
python3 scripts/audit-product-boundary.py --scope development --json
./scripts/run-portable-source-smoke.sh
```

构建器拒绝覆盖已有压缩包。默认顶层目录名同时包含运行时源码指纹和独立的源码包指纹：前者标识可执行应用的输入，后者覆盖所有已暂存的公开源码与贡献材料。因此，仅脚本、Schema、测试或文档变化时也会得到新的源码包身份，同时不会假装应用二进制发生了变化。显式名称只能包含字母、数字、点、下划线和连字符，并且必须以 `-source` 结尾。

## 机器可读内容

每个压缩包只有一个顶层目录。`SOURCE-PACKAGE.json` 声明应用构建身份、完整源码包身份、macOS 与架构下限、纳入与排除目录、校验和清单以及当前由所有者控制的发行门；`SOURCE-SHA256SUMS.txt` 覆盖除自身外的每个普通文件。源码包指纹由每个普通文件的相对路径与 SHA-256 共同计算，但排除生成后的 `SOURCE-PACKAGE.json` 与 `SOURCE-SHA256SUMS.txt`，从而避免循环身份。对应 JSON Schema 是 `Schemas/source-package-v1.schema.json`。

`clone-build-contribute-v1` 完整度档包含 Swift 应用与契约源码、测试、创作者工具、Content Pack v2 Schema 和示例、CI、双语公开治理文档、机器可验证的产品边界、模块维护与审阅路由策略、本地打包说明与发行门注册表。它排除工作副本元数据、本地智能体状态、构建缓存、已安装产物、私有视频生产输入、已停止采用的商业化研究和生成后的发行文件。

## 经过审计的公共 Git 初始化

`python3 scripts/bootstrap-public-git.py --destination <new-absolute-directory> --json`
会把上述白名单源码包转换为一个独立的公共仓库候选。它先重新审计 ZIP，再进行解压，
对解压后的源树执行有界凭证审计，初始化尚无提交的 `main` 分支，精确暂存每一个公开
普通文件，拒绝私有或生成目录，最后使用 macOS 排他重命名发布新目录。已有目标不会被
合并或替换。回执不包含本机路径，并明确记录没有创建提交、远端或作者身份，没有请求
网络，也没有修改权威开发目录。

这是一份暂存契约，不是仓库所有权或发行批准。第一次提交、作者身份、规范托管平台、
远端和组织仍由项目所有者决定。运行 `./scripts/run-public-git-bootstrap-smoke.sh` 可覆盖
成功路径，以及相对路径、已有目标、项目内部目标、符号链接父目录和未知参数的拒绝用例。

## 不可信压缩包边界

审计器在不解压的情况下读取 ZIP。它会拒绝绝对路径和路径穿越、反斜线、符号链接、重复名称、大小写或 Unicode 碰撞、文件与目录规范化碰撞、隐藏或未声明根目录、本机元数据、生成或私有路径、过多文件、超大文件、危险压缩比、校验清单漏项、文件字节变化、构建身份不一致和发行门漂移。它还会对包内源码执行同一套有界秘密策略与本地优先产品边界策略；即使重新计算校验和，凭证、收费接入、强制账户、广告、自动分享或历史商业化文档泄漏仍会被拒绝。失败统一使用稳定错误码注册表，并返回不泄露隐私的恢复动作。

仓库顶层使用严格白名单。已声明公开源码目录里的文件仍受逐文件精确校验和与压缩包上限约束；即使有人重新计算校验清单，顶层额外加入的密钥文件、环境配置、私人照片或 Finder 元数据也会被拒绝。

## 完整性不等于来源真实性

SHA-256 清单与源码包指纹只能证明这个 ZIP 的清单、身份字段与包内文件彼此一致。它们不是数字签名，不能识别压缩包制作者，也不能防御能够同时替换内容以及全部身份／校验元数据的主动攻击者。审计脚本应来自可信检出目录，发行证据应通过可信渠道比对；在未来签名分发链建立以前，不能据此声称来源真实。

审计 `PASS` 只表示源码包符合克隆、构建和贡献的预览契约，不表示媒体权利通过、最终许可证获批、Developer ID 签名完成、公证被接受或所有者批准公开发行。这些状态继续由 `release/release-gates.json` 分层记录。

## 验证矩阵

烟测矩阵覆盖带内容地址的默认顶层名称、合法显式名称、非法名称拒绝、重新计算校验和但保留陈旧源码包指纹的连贯重打包、重新计算校验和后的凭证文件拒绝、会实际编译 `ChengyinCompanion` 应用产品的完整隔离检出、普通校验和篡改、未声明的敏感顶层文件、Finder 元数据、规范化路径碰撞、符号链接与路径穿越、并发 Swift 前置检查、确定性的 Python 3.9+ 运行时矩阵、统一贡献者检查回执、只使用角色的模块审阅路由及其拒绝矩阵、仅源码启动检查、公开文档与本地化对齐、稳定错误码、发行状态保持、Swift 契约检查、示例内容包、Content Pack v2 八状态矩阵、创作者工具完整性、投影创作、临时小游戏绑定、不会暴露路径的源码／候选／安装／运行身份矩阵、可移植的直接互动与六游戏奖励回执绑定、对应 JSON Schema，以及不能冒充真实 GUI 证据的模拟拒绝矩阵；同时还包含带负向回执、无路径泄漏的短时无界面媒体解码／内存探针。脚本会从可执行矩阵中报告当前隔离检查数量，不依赖容易陈旧的手工数字。源码包烟测不会注入鼠标输入，也不会声称 GUI 已通过；只有在一个已验证的当前应用正在运行时，`audit-direct-play-runtime.py` 与 `audit-all-game-rewards.py` 才执行各自独立的本机真实交互门；只有后者的生产回执可以标记 `proofKind=LIVE_LOCAL_GUI`。

GUI 锁屏是三态证据，不是游戏奖励失败。聚合回执返回退出码 2 的 `PENDING`，并明确写入
`proofKind=NO_GUI_PROOF`、已验证游戏数 0，且不携带展开／回收记录。只有解锁后六项全部
`PASS`，才能以 `proofKind=LIVE_LOCAL_GUI` 作为成功的真实画面证据。

烟测不会安装到 `/Applications`、启动 GUI、调用 Seedance 或 TTS、读取 API Key，也不会把预览产物升级成公开发行声明。它的短媒体探针明确返回 `releaseSoakSatisfied=false`。普通 Mac 必须给出 `HEADLESS_AVFOUNDATION_DECODE`；若检测到 Codex 外层沙箱拒绝全部 AVFoundation 帧且内存仍有界，探针改为退出码 2，并明确返回 `PENDING / PLAYBACK_SOAK_AVFOUNDATION_RESTRICTED / NO_DECODE_PROOF_RESTRICTED_SANDBOX`，源码聚合回执则为 `PASS_WITH_PENDING`。损坏媒体、部分解码失败、资源增长和延迟回归仍会失败。另存的当前 Mac 30 分钟回执只对无界面 AVFoundation 解码与有界常驻内存返回 true，仍不能替代应用在目标硬件上通过 `isReadyForDisplay` 记录的真实可见首帧、GPU 曲线或人工音画同步抽查。新 Mac 实际首装、媒体权利审批、最终许可证、Developer ID 签名、公证和所有者发行批准，仍然是各自独立取证的门。
