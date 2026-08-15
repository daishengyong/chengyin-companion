# 为澄音 Companion 做贡献

简体中文 · [English](CONTRIBUTING.en.md)

感谢你帮助改进澄音。项目优先接受能提升稳定性、隐私、可恢复性、无障碍和内容扩展能力的贡献。

## 五条贡献路径

1. **文档与本地化**：修正文案、补充中英文说明、改善无障碍描述。
2. **声明式内容**：在不加入可执行代码的情况下贡献原创媒体和内容包。
3. **体验规则**：贡献反应、仪式、场景故事和小游戏配置；Content Pack v2
   发布前先使用 RFC 描述需要的扩展点。
4. **事件适配器**：把可信工具生命周期映射到隐私最小的 Companion Event。
5. **Swift Core**：改进调度、状态、播放、恢复、窗口和系统集成。

第一次贡献推荐从文档、本地化、测试夹具或 `good first issue` 开始。公共协议、
持久化字段、权限和新的核心玩法先按 [治理规则](GOVERNANCE.zh-Hans.md) 提交短 RFC。

## 开始前

1. 先搜索现有 Issue 和 Discussion，避免重复工作。
2. 大型功能先写简短提案，说明用户问题、交互和数据边界。
3. 不要提交密钥、账户凭证、购买记录或用户诊断数据。
4. 不要提交没有明确商业使用权的真人照片、声音、音乐或视频。
5. 角色素材必须明确为成年虚构角色，不能模仿可识别真人。
6. 阅读 [公开路线图](ROADMAP.zh-Hans.md) 和 [社区行为规范](CODE_OF_CONDUCT.zh-Hans.md)。

中英文是当前基础语言。新增语义化文案键时必须同时更新两个 `Localizable.strings`，
并运行 `python3 scripts/check-localization-parity.py`；不要依赖其中一种语言的 fallback
掩盖缺失翻译。
README 与贡献指南还必须运行 `python3 scripts/check-public-doc-parity.py`，保证双语入口的
命令、相对链接和标题层级不会漂移。

审阅前还应使用[模块维护契约](docs/MODULE-STEWARDSHIP.zh-Hans.md)路由仓库改动路径。回执只
给出稳定的角色、检查、风险、RFC 和所有者门 ID，不会暴露传入路径；待分配角色也不会被
伪装成不存在的 GitHub 身份。

新增失败分支时遵守 [稳定错误码约定](docs/ERROR-CODES.md)：底层错误使用稳定代码和
英文技术描述，界面通过 `CompanionErrorPresentation` 给出双语恢复建议，不能直接展示
可能包含用户名或绝对路径的系统错误。

## 本地检查

先运行快速、无需联网的贡献者检查门。它的 JSON 回执只包含稳定检查 ID 和恢复命令，
不会带出用户名、仓库路径或内容包路径：

```bash
./scripts/check-contribution.py --profile quick --json
python3 scripts/audit-module-stewardship.py --audit --json
python3 scripts/audit-public-source-secrets.py --json
```

准备发行相关 PR 前使用 `--profile full`，它会运行完整隔离的克隆／构建／贡献源码包门，
因此耗时更长。声明式内容包贡献者使用严格本地模式：

```bash
./scripts/check-contribution.py --profile pack --pack <pack-directory> --json
```

这些模式不会安装应用、打开预览浏览器、请求网络、上传诊断或声称已经可以公开发行。
秘密审计只读取可携源码白名单，不读取环境变量值、构建缓存、`video-production` 或用户私有目录；
发现真实凭证时应先吊销，再从当前源树与 Git 历史移除。PASS 不能证明历史从未泄漏。

## 建立干净的公共 Git 候选

不要在可能包含私有制作输入、缓存和历史发行产物的开发目录直接执行 `git init`。
从可信检出目录运行以下离线命令，它会先构建并审计公开源码包，再在一个全新目录创建
`main` 分支并精确暂存公开文件：

```bash
python3 scripts/bootstrap-public-git.py --destination <new-absolute-directory> --json
```

成功回执必须显示 `staged-unborn-main`、`commitCreated=false`、
`remoteConfigured=false`，并且源码包审计与凭证审计都为 `PASS`。工具不会配置作者、
创建第一次提交或添加远端；这些动作继续由项目所有者决定。校验和只能证明包内一致性，
不能证明来源真实性，也不能把 `NOT_PUBLIC_RELEASE_READY` 提升为正式发行。

```bash
./scripts/bootstrap-local.sh --check-only
swift build -c release
swift run CompanionContractChecks

./scripts/run-content-pack-smoke.sh
./scripts/run-core-policy-smokes.sh
./scripts/run-creator-error-receipt-smoke.sh
./scripts/run-contribution-metadata-smoke.sh
./scripts/run-content-pack-preview-projection-smoke.sh
./scripts/run-content-pack-experience-authoring-smoke.sh
python3 scripts/check-public-doc-parity.py
```

涉及小游戏时，还应运行 `scripts/` 中对应的 smoke 脚本并进行一次真实窗口操作。

涉及应用打包、版本或资源时，还应运行：

```bash
./scripts/install-local-app.sh --dry-run
./scripts/doctor.sh
```

`dist/Chengyin Companion.app` 和 `/Applications/Chengyin Companion.app`
不会因源码变化自动同步。构建脚本写入源码指纹，doctor 会把缺少身份或指纹落后的
应用标记为陈旧。不要用手工覆盖代替事务安装，也不要删除
`~/Library/Application Support/Chengyin` 或对应偏好文件。

## 内容包

- 先阅读 [Content Pack v1](docs/PACK-SPEC-v1.md) 与向后兼容的
  [Experience Pack v2](docs/PACK-SPEC-v2.md)。
- 用 `./scripts/new-content-pack.sh <目录> <反向域名ID> <角色ID> [语言] --json`
  原子创建不含密钥和可执行代码的兼容 v2 草稿；可重复使用 `--locale <语言标签>`
  声明最多 32 种语言。无路径机器回执不会推断来源、授权或审阅通过。
- 用 `./scripts/validate-content-pack.sh <目录> --json` 检查 manifest、路径、
  哈希、媒体解码、尺寸、首帧、音轨和声明式 JSON。
- 用 `./scripts/preview-content-pack.sh <目录>` 在浏览器打开经过验证的本地素材目录；
  视频会并排显示头像、舞台和全屏三种真实运行时裁切，标明声明锚点、v1 兼容别名
  或安全默认值；页面不加载远程脚本、字体或统计服务。
- 用 `./scripts/edit-content-pack-projection.sh <目录> --asset <视频ID>` 在离线页面校准
  Pet、Stage、Fullscreen 的焦点轨道与安全区；浏览器只导出无路径 JSON 回执。先用
  `python3 scripts/apply-content-pack-projection.py <目录> <回执> --check --json` 预检，
  再去掉 `--check` 事务应用。失败会恢复原 manifest，回执不代表权利或质量批准。
- 用 `./scripts/author-content-pack-experience.sh <目录> --id <体验ID> --kind <类型>
  --trigger <触发器> --step <视频ID:角色> --check --json` 无写入检查体验序列；确认后去掉
  `--check`，只有显式 `--replace` 才会替换同 ID 体验。失败会恢复原 manifest。
- 用 `./scripts/audit-content-pack.sh <目录> --strict` 检查贡献质量；审计提示不会替代
  素材权利证明、真实首播健康或官方签名验证。
- 对 v1/旧 v2 包先用 `./scripts/plan-content-pack-v2-migration.sh <目录> --json`
  生成只读迁移回执；工具不会改包，也不会从旧 `license` 字段推断授权。
- 可直接验证 [最小示例包](examples/packs/hello-workday)。
- 第一版内容包只能包含声明式媒体和配置，不能包含脚本或可执行代码。
- v2 的 `experiences` 只能引用同一包内已声明的视频，最多八步；不要提交 URL、
  shell 命令或需要 Core 执行的代码。
- 所有媒体文件必须写入 SHA-256。
- 待贡献包使用 `contribution.contractVersion: 2`，同时提供包级与逐资产来源、作者/提供者、
  授权依据、枚举化允许用途、署名、成年/虚构状态、不含私有路径的 `evidenceID`，以及
  `draft/pending/approved/rejected` 的版本化审阅。旧字段不能代填这些事实。
- 每项资产还必须有逐语言说明；视觉资产有 alt text，带声音的音频/视频有 transcript、
  captions 和 sound descriptions，并声明闪光与突发大音量及无障碍审阅状态。
- `contribution.fallback.strategy` 固定为 `starter`，严格 v2 还需逐资产 fallback。视频、
  音频和图片只能回退 Starter；声明式本地化/小游戏可以 `skip`。缺证据的旧包仍可安装，
  但严格审计保持 `DRAFT`。
- 不可信包边界与攻击用例见
  [Content Pack threat model](docs/CONTENT-PACK-THREAT-MODEL.md)。
- 本地未签名包必须在界面上明确标识，不能伪装成官方包。
- 官方包的签名和发布流程尚未开放，不要在 Issue 中索取私钥。
- 申请进入社区审阅索引前，运行
  `python3 scripts/audit-community-pack-index.py community/index.json --json`；索引只接受
  绑定准确 manifest 哈希的 strict-v2 `READY_FOR_LAB` 包，不代表最终法律或发行批准。
- 使用 GitHub 的“Content Pack submission / 内容包提交”模板提交索引申请；只公开隐私安全的
  evidence ID 和审计回执，不要上传合同、身份证明、密钥或私有路径。

## Pull Request

PR 请说明：

- 解决的用户问题；
- 对内置体验、社区内容包或本地内容包的影响；
- 测试方式；
- 是否新增权限、网络请求、持久化数据或第三方依赖；
- 素材来源和使用权。

不要在同一 PR 混入无关的格式化或生成文件。
