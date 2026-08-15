# Chengyin Companion 全球化与本地化计划

## 1. Language Rollout

### P0：Day 0–45 产品语言

| Locale | 角色 | 原因 |
|---|---|---|
| `zh-Hans` | 完整 UI + 完整声音 + 视频 | 当前产品和首批用户 |
| `en` / `en-US` | 完整 UI + 完整声音 + 英雄视频 | GitHub、官网、商品页与全球社区的默认和 fallback |

### P1：Day 45–90 产品语言

- `zh-Hant`
- `ja-JP`
- `ko-KR`

统一节奏：Day 45–60 制作，Day 61–75 由母语用户验收，Day 76–90 只公开已通过的声明范围。日语和韩语的桌宠/角色文化匹配度高，但仍要在中英文核心体验稳定后再承诺完整声音与英雄片。

### P1.5：先本地化商店与落地页

- `de-DE`
- `es-419`
- `pt-BR`

德国先验证高付费潜力；西语拉美和巴西葡语先验证较大的开发者增长潜力。三者先上线页面、字幕和样片，再用点击、下载、复看和购买数据决定是否生成完整产品内音画。

### P2：由数据解锁

- `fr-FR`
- `es-ES`
- `it-IT`
- `th-TH`
- `vi-VN`
- `id-ID`

P1.5/P2 必须根据下载、预览、候补名单和付费数据排序，不能只按全球人口。

## 2. Current Gap

当前已经建立 `zh-Hans` / `en` 双资源、476 个共享键和自动 parity 检查；关系语气、
显示模式、播放模式、关心节奏、心情、互动动作、场景、迷你生活、投喂物和造型等
动态标签以及 Codex 工作状态、生活关心、小游戏进度、互动学习、备份/内容包错误已经改用稳定
语义键，主设置页固定标题也有英文值。CI 与 doctor 会拒绝仅补一种基础语言、重复键
或 `%d` / `%@` 格式占位符不一致的改动。

这仍不是“英文完整产品”声明：预生成语音和口型视频仍以中文为主。
约 150 个资源文件也说明不能依赖逐个界面临时翻译。后续仍需把四种
本地化对象彻底分离：

1. UI 文本；
2. 角色台词；
3. 视频/音频资产；
4. 商店、网站和营销元数据。

## 3. Locale Architecture

```text
Resources/
├── Localizable.xcstrings
├── Persona/
│   ├── zh-Hans.json
│   ├── en.json
│   ├── ja.json
│   └── ko.json
├── Packs/
│   └── manifest locale declarations
└── StoreMetadata/
    ├── direct-checkout/
    ├── app-store/
    └── website/
```

禁止把中文句子继续作为素材 ID。使用稳定语义键：

```text
task.success.short.01
task.success.playful.02
health.hydration.gentle.01
game.feed.win.01
store.pack.orbit.preview.cta
```

## 4. Fallback

- UI：用户 locale → 语言族 → `en` → `zh-Hans`；
- 角色文本：用户关系语气 + locale → locale 默认 → 英文默认；
- 视频：locale 原生音画 → 语言无关视频 + locale TTS → 静音动作；
- 商店：必须至少有英文，不能显示另一语言的空字段；
- 缺失本地化不能阻止 Starter Pack 启动。

## 5. Relationship Tone

世界各地用户对“老公/老婆”“宝贝”和直接调情接受度不同。不要把昵称写死。

首次设置提供：

- Friendly：朋友式桌宠；
- Warm：温柔陪伴；
- Romantic：轻浪漫；

并独立选择：

- 是否使用昵称；
- 喜欢的称呼；
- 调情频率；
- 是否播放睡前/早安；
- 是否显示商店情境推荐。

所有档位都使用同样的免费功能和任务庆祝，不把 Romantic 变成付费权益。

## 6. Transcreation

台词先写“意图”，再由各语言重写：

```json
{
  "id": "task.success.playful.02",
  "intent": "Celebrate completion with playful admiration",
  "maxSeconds": 4.2,
  "relationshipTone": ["warm", "romantic"],
  "avoid": ["dependency", "guilt", "sexual pressure"]
}
```

示例：

- 中文可以更自然地使用“辛苦啦”“真厉害”；
- 英文避免机械直译 “husband”，默认用 “hey, you did it”；
- 日文根据礼貌度和亲密度重写，不强行逐词对应；
- 韩文区分称呼和敬语层级；
- 西语/葡语需要明确性别和地区用词；
- 德语 UI 预留更长文本空间。

每条本地化经过：

1. 母语译写；
2. 第二位审校；
3. 音频时长检查；
4. 产品内真实播放；
5. 文化与年龄评级复核。

## 7. Voice & Video

### Voice Contract

每个 locale 记录：

- voice provider；
- voice ID 和许可；
- 性格标签；
- 速度、音高和响度；
- 商业使用范围；
- 禁止模仿真人；
- fallback voice。

### Video Contract

内容包 asset 支持：

```json
{
  "id": "task-success-hero-01",
  "video": "media/task-success-hero-01.mov",
  "audioVariants": {
    "zh-Hans": "audio/zh-Hans/task-success-hero-01.m4a",
    "en": "audio/en/task-success-hero-01.m4a"
  },
  "nativeVideoVariants": {
    "ja": "media/ja/task-success-hero-01.mov",
    "ko": "media/ko/task-success-hero-01.mov"
  }
}
```

语言无关动作复用视频；有清晰近景口型的英雄台词使用 locale 原生视频。

## 8. UI Rules

- 支持文本放大和 40% 长度扩张；
- 按钮不能用固定宽度截断；
- 数字、日期、时间和复数用系统 formatter；
- 不把文字烘焙进视频；
- 字幕可开关，默认跟随系统无障碍设置；
- 提供 Reduce Motion、仅声音和静音；
- RTL 在 P2 前完成布局技术测试，即使暂不发布阿拉伯语；
- 昵称和用户输入不得上传用于分析。

## 9. Store Localization

Apple 允许对名称、说明、关键词、截图和隐私 URL 做 locale 本地化，用户也能用本地化关键词搜索。[App Store Connect 本地化](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information/)

每个首发 locale 需要：

- 产品名和副标题；
- 一句话价值；
- 长说明；
- 5–8 张真实截图；
- 30–45 秒 trailer；
- 隐私、支持、退款和内容权利页面；
- AI 生成内容披露；
- 年龄/成熟内容说明；
- 非 OpenAI 官方产品声明。

## 10. Marketing Voice

### Chinese

重点：“Codex 做完任务，桌面上的她真的会庆祝。”

### English

重点：“A cinematic desktop companion that reacts when your work gets done.”

### Japanese

重点：デスクトップ常駐、作業応援、自然なリアクション；避免直译“AI girlfriend”。

### Korean

重点：데스크톱 동반자、작업 완료 리액션、미니게임。

不同地区用同一真实功能做表达，不伪造不同能力。

## 11. Localization QA

- 所有 key 在当前声明为“完整支持”的 locale 有值；
- 没有中文 fallback 泄漏到英语商店；
- 文本扩张不遮挡菜单；
- TTS/视频语言与 UI 一致；
- ASR 自动核对 spoken script；
- 昵称、性别和敬语正确；
- 退款、隐私和订阅条款由专业人员审校；
- 每个 locale 至少 3 位真实用户完成首启和一次购买 sandbox；
- 本地化缺失不会导致崩溃或丢失权益。

## 12. Rollout Gate

一个语言只有同时满足以下条件才声明“完整支持”：

- UI 100%；
- Starter 台词 100%；
- 付费包商品页 100%；
- 关键视频音频/口型通过；
- 支持与退款模板可用；
- 至少一次母语用户验收；
- 崩溃、恢复和购买 sandbox 通过。

否则只能标记“界面文本支持”或“字幕支持”，不能夸大为完整本地化。
