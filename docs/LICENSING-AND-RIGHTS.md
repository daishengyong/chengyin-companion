# Chengyin 授权、角色权利与素材台账

> 状态：代码 MIT 许可证已由所有者选择并落盘；Starter 媒体、品牌和第三方素材仍处于发行前权利审阅，不是法律意见  
> 原则：代码开放、完整体验可长期使用、媒体权利可审计、社区内容可恢复；不把不同权利对象塞进一个 LICENSE。

## 1. 对外准确表述

在正式文件生效前，使用：

> 开源 Core 代码 + 单独许可、可长期使用的 Starter 媒体。

不要使用：

> 整个项目和所有素材都是开源的。

原因是 OSI 开源通常描述软件许可证；角色视频、声音、音乐、商标和社区内容具有不同的再分发、修改和商业利用边界。

## 2. 四层授权

| 层 | 对象 | 候选方案 | 必须保障 | 最终 Gate |
|---|---|---|---|---|
| Code | Core、协议、验证器、Skill、构建脚本与随附软件文档 | MIT（已由所有者选择，见根目录 `LICENSE`） | 使用、修改、分发；保留版权和许可文本 | 已完成代码许可证选择；媒体不继承该许可 |
| Starter Media | 内置角色视频、音频、图片、本地化 | 独立 Starter Media License | 永久本地使用、备份、免费再分发与仓库 fork；禁止冒充官方和单独转售 | 模型/声音/音乐条款与专业审查 |
| Community Media | 贡献者角色、World、Bundle | 每包 SPDX 或独立内容许可证 | 来源、作者、允许用途、署名、成年／虚构、无障碍和撤回状态可验证 | strict-v2 审阅与贡献者授权 |
| Brand | 名称、Logo、官方角色名、Official 标识 | `TRADEMARK.md` | 社区能准确描述兼容性，不得冒充官方 | 名称检索/商标策略后确认 |

第三方依赖、字体、音乐、音效、音色和生成模型条款统一进入 `THIRD-PARTY-NOTICES`，不因打包进 Starter 而改变原许可。

## 3. Starter Media 的产品要求

Starter 的许可文本至少要允许：

- 用户和企业内部永久运行；
- 离线使用和个人备份；
- GitHub clone、fork 和公开 Release 的必要复制；
- 与兼容 Core 一起再分发；
- 为无障碍、本地化或设备适配制作必要修改；
- 项目停止维护后仍能恢复完整 Starter 体验。

同时可以保留：

- 禁止把 Starter 媒体脱离许可证单独出售、出租或冒充原创；
- 禁止用官方名称、Logo 或签名暗示官方背书；
- 禁止移除权利与第三方通知；
- 禁止将角色用于违法、欺诈、真人冒充或误导性背书；
- 修改版本必须标明非官方，不能使用官方包签名。

是否允许商业 fork 免费捆绑 Starter、是否允许修改后的角色媒体再分发，应在发行前明确，不能留给 README 暗示。

## 4. Community Pack 许可证的最低承诺

每个公开贡献包必须写清：

- 具体包含的角色、世界、视频、语言、文件大小和最低客户端版本；
- 作者、提供者、来源、授权依据、允许用途与署名要求；
- 用户获得哪些复制、修改、备份和再分发权利；
- 包撤回、损坏或不兼容时的回退策略；
- 不承诺兼容所有未来系统，但给出支持窗口与导出方案；
- 社区制作兼容工具不自动构成官方背书。

公开索引只证明机器合同和审阅状态，不替代版权、肖像、声音或其他专业法律判断。

## 5. 每个媒体文件的权利台账

内置免费素材已经使用 [Starter 素材契约](STARTER-MEDIA-CONTRACT.zh-Hans.md) 建立机器可读
清单。它会精确绑定文件哈希、来源声明、授权依据、允许用途、署名、成年／虚构状态、
中英无障碍说明、回退与审阅版本，但不会凭文件存在或模型输出自动推断授权。

每个候选资产必须有一条记录，最少字段：

```json
{
  "assetId": "cc.starter.c01.task-complete.001",
  "sha256": "64-lowercase-hex",
  "status": "quarantine|candidate|approved|withdrawn",
  "characterId": "starter.c01",
  "depictsFictionalAdult25Plus": true,
  "distributionScope": "starter|community|internal",
  "inputSources": [
    {
      "kind": "text|original-image|licensed-audio|video",
      "sourceId": "internal-id",
      "rightsBasis": "owned|licensed|provider-output",
      "identifiablePerson": false
    }
  ],
  "generation": {
    "provider": "Volcengine",
    "model": "Doubao-Seedance-2.0-mini",
    "taskId": "provider-task-id",
    "createdAt": "ISO-8601",
    "resourceTokens": 173700,
    "termsSnapshot": "internal-document-id"
  },
  "audio": {
    "native": true,
    "voiceLicense": "provider-terms-id",
    "musicLicense": "none|license-id"
  },
  "reviews": {
    "identity": "pass",
    "adultAge": "pass",
    "realPersonSimilarity": "pass",
    "contentPolicy": "pass",
    "cultural": "pass",
    "audio": "pass"
  },
  "approvedBy": "human-reviewer-id",
  "approvedAt": "ISO-8601"
}
```

台账不存 API Key、临时签名 URL、真人姓名或不必要的个人信息。真实人物输入一律保持 `quarantine`，除非人物肖像、摄影作品、服装/场地和商业衍生授权都有可验证文件。

## 6. 原创角色和相似度门

- 公开角色明确为 25 岁以上虚构成年人；
- 不输入用户先前提供的真人照片；
- 不使用明星、网红、演员或公众人物姓名、照片、声音、标志造型；
- 不使用“像 X”“X 与 Y 的混合”“规避审查但达到同样效果”的提示；
- 上线前做反向图片检索、内部盲审和跨文化复核；
- 收到可信肖像/版权申诉时先撤下分发，保全台账，再进入人工处理。

身份相似度不是只看脸：发型、服装、姿势、场景、声线和营销文案的组合也可能造成可识别联想。

## 7. 发布前文件清单

未完成以下文件前，不宣称公开发行就绪：

```text
LICENSE-CODE
LICENSE-STARTER-MEDIA
TRADEMARK.md
THIRD-PARTY-NOTICES
CONTENT-RIGHTS.md
PRIVACY.md
TERMS.md
```

其中 `PRIVACY`、`TERMS` 和内容许可证需要按真实主体、数据流和发行地区复核。

## 8. 决策记录

正式选择必须记录：

- 决策日期与负责人；
- 仓库/发布版本；
- 代码和依赖扫描结果；
- Starter/社区媒体权利抽样；
- 模型、音色和音乐条款的归档版本；
- 专业审查意见和待办；
- 旧版本迁移方式；
- 对用户已取得权利是否有影响。

许可证变更不能追溯撤销用户已经合法取得的永久使用权。
