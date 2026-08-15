# Codex 伴侣产品与工程架构

> 目标：让 Companion 对 Codex 任务可靠响应，但不依赖私有会话格式、不偷偷借用用户订阅、不恢复无效录音聊天；让内容、角色、窗口和事件都可独立演进，并保持本地优先、无收费、无强制账户、无广告和无自动分享。

## 1. 产品边界

### 保留

- 点击、双击、长按、拖动、甩动；
- 头像、局部、全屏；
- 任务完成、失败、长任务和连续完成；
- 喝水、伸展、早晚提醒；
- 小游戏；
- Seedance 原生音画；
- TTS 仅声音/降级；
- 本地偏好、记忆与静默窗口；
- Codex 主动调用的安装、doctor、修复和制包 Skill。

### 移除

- 无效麦克风按钮；
- 录音状态；
- 未跑通的 GPT Live 对话入口；
- 全屏聊天框；
- 假装能够实时聊天的 UI。

### 不承诺

- Companion 独立进程直接使用用户的 ChatGPT/Codex 订阅额度；
- 后台无授权调用 Codex；
- 读取所有 Codex 内部会话格式永远兼容；
- OpenAI 官方背书。

## 2. 逻辑架构

```text
Presentation
  ├── Pet Mode
  ├── Stage Mode
  ├── Fullscreen Mode
  ├── Gallery
  └── Settings / Doctor

Application
  ├── Interaction Engine
  ├── Response Scheduler
  ├── Event Intelligence
  ├── Game Engine
  ├── Reminder Engine
  └── Explicit Local Export

Domain
  ├── Companion Event
  ├── Persona / Tone / Locale
  ├── Scene / Asset
  ├── Pack / Trust State
  └── User Preference / Recent Memory

Infrastructure
  ├── Video / Audio Player
  ├── Pack Store
  ├── Event Adapters
  ├── State Store / Keychain
  ├── Update / Restore
  └── Local Diagnostics
```

## 3. Swift 模块建议

```text
Packages/
├── CompanionCore/
│   ├── Events/
│   ├── Scheduling/
│   ├── Interaction/
│   └── Preferences/
├── CompanionMedia/
│   ├── Player/
│   ├── Audio/
│   └── PresentationProjection/
├── CompanionPackKit/
│   ├── Manifest/
│   ├── Validation/
│   ├── Installation/
│   └── Recovery/
├── CompanionEventProtocol/
│   ├── Schema/
│   ├── Server/
│   └── Client/
├── CompanionCodexAdapter/
│   ├── ProtocolAdapter/
│   └── LegacyLocalSessionAdapter/
├── CompanionTrust/
│   ├── Provenance/
│   └── SignatureInterfaces/
├── CompanionGames/
└── CompanionDiagnostics/
```

拆分现有超大文件：

| 当前 | 目标 |
|---|---|
| `CompanionViewModel.swift`（受单调下降门约束的迁移表面） | AppCoordinator + Scheduler + Interaction + Game + Event + Preferences |
| `ContentView.swift`（受单调下降门约束的迁移表面） | PetView + StageView + FullscreenView + GalleryView；设置和播放控件已拆分 |
| Bundle 内写死媒体 | `CompanionContentLibrary` + PackStore |
| JSONL watcher | EventAdapter |
| UserDefaults 全状态 | schemaVersion 的 SettingsStore + StateStore |

## 4. Versioned Companion Event Protocol

### 为什么需要

当前直接递归读取 `~/.codex/sessions/**/*.jsonl` 并依赖 `event_msg -> task_complete`。这是内部实现，字段或目录一变就失效。它可以作为 Legacy Adapter，不应成为公开兼容契约。

### Protocol v1

当前 v1 已实现原子写入的本地 file spool：

```text
~/Library/Application Support/Chengyin/events/<event-id>.json
```

目录权限为当前用户 `0700`，事件文件为 `0600`，每个事件最大 64 KiB。应用通过
目录描述符、`openat`/no-follow、单硬链接和文件名／内容 UUID 绑定读取；单次最多
查看 4,096 个目录条目、保留 512 个安全事件和 36 小时寿命，并在运行中投影损坏与
修复状态。完整边界见 [Event spool 安全合同](EVENT-SPOOL-SECURITY.zh-Hans.md)。
现有 Codex session JSONL 的 Legacy adapter 默认关闭，因为内部 `task_complete` 只能
证明一次 turn 结束。Unix domain socket 可在需要更低延迟或双向健康检查时作为后续
transport，不能改变 envelope。

事件：

```json
{
  "protocolVersion": "1.0",
  "eventId": "uuid",
  "source": "codex",
  "sourceVersion": "optional",
  "type": "task.completed",
  "taskRef": "opaque-local-id",
  "occurredAt": "2026-07-30T12:34:56Z",
  "durationMs": 123456,
  "outcome": "success",
  "privacy": {
    "containsTaskTitle": false,
    "containsPath": false,
    "containsCode": false
  },
  "metadata": {
    "completionCount": 1
  }
}
```

允许类型：

- `response.ready`；
- `task.started`；
- `task.progress`；
- `task.completed`；
- `task.failed`；
- `task.cancelled`；
- `task.long_running`；
- `integration.health`；
- `integration.disconnected`。

默认不传：

- prompt；
- 回复正文；
- 代码；
- 文件路径；
- 仓库；
- 用户名；
- token；
- 机密。

### 事件安全

- inbox 根和安全事件只允许当前用户，拒绝软链接、硬链接、FIFO 与宽松权限；
- event size ≤64 KiB；
- JSON schema；
- `eventId` 去重；
- 时间窗；
- 有界条目数、保留数与寿命，只清理再次验证过的安全普通文件；
- 不接受 shell command；
- 不接受 URL；
- taskRef 不可用于打开文件；
- 每分钟速率限制；
- 每轮来源健康状态和路径安全稳定码；
- Companion 自身任务过滤。

## 5. Event Adapter

```swift
public protocol CompanionEventAdapter: Sendable {
    var id: String { get }
    func health() async -> AdapterHealth
    func events() -> AsyncStream<CompanionEvent>
}
```

实现：

- `LocalProtocolAdapter`：公开首选；当前由 `CompanionEventEmitter` + file spool 提供；
- `LegacyLocalSessionAdapter`：兼容当前本地 session；
- `SimulationAdapter`：首启和测试；
- `ManualAdapter`：快捷键/菜单；
- 未来 `GitHubAppAdapter`：独立云产品，不进入近期。

所有 Adapter 转为同一 `CompanionEvent`。UI 不知道事件来自 Codex、模拟还是其他工具。

当前可用的隐私安全模拟：

```bash
CHENGYIN_EVENT_ROOT="$(mktemp -d)" swift run CompanionEventEmitter task.completed 1000
```

当前也已实现官方 `notify` 的隐私清理 mapper：

```bash
CHENGYIN_EVENT_ROOT="$(mktemp -d)" swift run CompanionEventEmitter codex-notify \
  '{"type":"agent-turn-complete","cwd":"/discarded","input-messages":["discarded"],"last-assistant-message":"discarded"}'
```

mapper 只识别 `type=agent-turn-complete`，生成新的不透明本地 ID，并丢弃 `thread-id`、`turn-id`、`cwd`、`input-messages`、`last-assistant-message` 及未知字段；原始 payload 不写日志、不落盘。

当前还提供 App Server 回合通知的单消息隐私投影入口：

```bash
CHENGYIN_EVENT_ROOT="$(mktemp -d)" swift run --disable-sandbox CompanionEventEmitter codex-app-server \
  '{"method":"turn/completed","params":{"threadId":"discarded","turn":{"id":"discarded","status":"completed","durationMs":1200}}}'
```

它已把 `turn/started`、完成、失败和中断状态投影到统一事件，并删除上游 ID、items、错误详情与未知字段。它不包含 App Server 进程管理、握手、重连、流控或配置写入，因此仍属于可选 adapter ingress，而不是完整托管集成。完整合同见 [Codex App Server 适配器](CODEX-APP-SERVER-ADAPTER.zh-Hans.md)。

### 4.1 官方上游信号与本地协议的关系

file spool / 未来 UDS 是**传输层**，不是 Codex 事件来源。生产架构按能力递进：

```text
Codex official notify / trusted lifecycle hook / App Server
  → privacy-clean mapper
  → Companion Event v1
  → current-user file spool（未来可选 UDS）
  → Response Scheduler
```

官方能力边界：

| Companion 语义 | 官方来源 | 映射性质 |
|---|---|---|
| `response.ready` | `notify` 的 `agent-turn-complete` | 官方信号；只表示一次 agent turn 结束并有新结果，不等同整个用户任务成功 |
| `task.started` | App Server `turn/started` | 官方信号；仅 App Server 集成保证 |
| `response.ready` / `task.failed` / `task.cancelled` | App Server `turn/completed` 的最终 status | 官方 turn 信号；`completed` 映射中性新结果，不能自动宣称长期任务完成 |
| `task.completed` | 显式任务编排器、用户动作或语义已验证的 adapter | Companion 任务语义；不能仅由 `agent-turn-complete` 推断 |
| 项目 Stop hook | 用户信任后的 lifecycle hook | 可选集成；不是静默默认 |
| `task.progress` | Companion 根据开始时间与仍未结束状态推导 | 本地推导，不声称 Codex 原生提供 |
| `task.long_running` | Companion 定时阈值推导 | 本地推导 |
| `integration.health` / `disconnected` | adapter 心跳与超时 | Companion 本地状态 |

Codex 官方 Advanced Configuration 说明 `notify` 当前支持 `agent-turn-complete`，并把事件作为一个 JSON 参数传给外部程序；生命周期 hooks 可来自用户配置或受信任项目的 `.codex/hooks.json`。[Codex Advanced Configuration](https://developers.openai.com/codex/config-advanced) [Codex Configuration Reference](https://developers.openai.com/codex/config-reference)

Codex App Server 官方协议提供 `turn/started` 与 `turn/completed`，后者包含 `completed`、`interrupted`、`failed` 等 turn 最终状态；它适合以后需要完整状态机的深度集成，但仍不自动证明一个跨 turn 的用户目标已经完成。[Codex App Server README](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md) [Unlocking the Codex harness](https://openai.com/index/unlocking-the-codex-harness/)

### 4.2 三档安装方式

1. **默认安全档**：应用完整可玩；用户通过菜单/模拟事件体验，不读取 Codex 私有文件。
2. **低运维档**：安装签名 helper 后，向用户展示将写入 `~/.codex/config.toml` 的精确 `notify` 配置；只有明确确认后才修改。示意：

   ```toml
   notify = ["/absolute/signed/path/CompanionEventEmitter", "codex-notify"]
   ```

3. **深度档**：用户主动启用 App Server adapter，获得 started/final status。项目 lifecycle hook 只在项目被用户信任且配置内容可见时启用。

卸载必须能恢复原配置。安装器不得覆盖用户已有 `notify`；若已有命令，应停止并给出手动合并方案。Skill 可以诊断和生成配置草案，但不能在没有确认时静默编辑用户级 Codex 配置。

### 4.3 Codex 主任务完成规则

本地应用包携带稳定 helper：

```text
/Applications/Chengyin Companion.app/Contents/SharedSupport/CompanionEventEmitter
```

用户可在全局 `~/.codex/AGENTS.md` 中明确授权主 Codex agent：只有在用户的具体实施目标真正完成、必要检查通过、需要的本地安装已经验证后，才在最终答复前调用一次：

```bash
"/Applications/Chengyin Companion.app/Contents/SharedSupport/CompanionEventEmitter" task.completed
```

该规则不能由 subagent、计划步骤、普通问答、评审、预览、dry-run、部分完成或阻塞任务触发。测试必须设置 `CHENGYIN_EVENT_ROOT` 到临时目录。这样既不占用 Codex 单一 `notify` 配置，也不会把 `agent-turn-complete` 错当成整个任务完成。

### Legacy Adapter 的明确边界

- 标为 Experimental；
- 公开支持的 Codex 版本范围；
- `doctor` 检查目录和字段；
- 解析失败降级，不崩溃；
- 不扫描不相关文件；
- 不上传 session；
- 设置页明确说明本地只读。
- Free Edition 的点击、游戏、提醒和手动任务庆祝不依赖任何 Codex adapter，集成失效时仍是完整产品。

## 6. Codex Plugin / Skill

Codex 官方插件可以封装 skills、apps 和 workflow guidance；可用性受计划、地区和管理员设置影响。Chengyin 插件承担主动、可审计工作：

- install；
- update；
- doctor；
- repair；
- restore；
- pack validate；
- pack preview；
- share card draft；
- emit test event。

它不承担：

- Companion 常驻 LLM；
- 未授权后台调用；
- 收费、账户或广告接入；
- 发送邮件或社交媒体；
- 修改 Codex 本体 UI；
- 模拟 OpenAI 官方功能。

## 7. Event Intelligence

### 输入

```swift
struct CompanionContext {
    let event: CompanionEvent?
    let now: Date
    let sessionDuration: Duration
    let mode: PresentationMode
    let recentAssets: [AssetID]
    let dailyCounts: DailyCounts
    let preferences: Preferences
    let quietHours: DateInterval?
}
```

### 输出

```swift
enum ResponseDecision {
    case play(asset: AssetID, returnPolicy: ReturnPolicy)
    case audioOnly(asset: AssetID)
    case defer(until: Date)
    case ignore(reason: SilenceReason)
}
```

### 决策顺序

1. Quiet Hours；
2. 用户禁用；
3. 事件去重；
4. 当前高优先级视频；
5. 事件强度；
6. 最近重复；
7. 当前模式；
8. 角色/语气/locale 可用资产；
9. fallback；
10. 播放与 returnPolicy。

### 优先级

| 级别 | 事件 |
|---|---|
| P0 | 用户明确点击/小游戏 |
| P1 | 可信 task.completed / task.failed |
| P2 | response.ready / long_running / 连续完成 |
| P3 | 健康提醒 |
| P4 | 空闲表演 |

用户输入可以打断空闲，但不能随意打断购买安装和关键系统提示。多个完成事件 10 秒内合并成“连续完成”。

### 当前 P0 伴侣导演

当前运行时已把协议事件串成隐私最小的工作弧：

```text
task.started
  → focused idle
  → task.progress / task.long_running
  → task.completed / task.failed / task.cancelled
  → 分级庆祝或支持
  → 10 秒无对话框手势回应窗口
  → 回礼视频
  → 正向共同记忆与纪念物
```

- 分级庆祝只使用任务持续时间、当日完成次数和“失败后解决”状态；
- 不读取或保存任务标题、Prompt、代码、仓库和路径；
- 完成后单击、双击、长按和拖动产生不同回礼；
- 关系语气是用户主动选择的上限，降低语气不会扣除永久进度；
- 素材选择真实执行 locale、最近六次排除、单素材 cooldown 和 `weight`；
- 8 次有意义互动形成一个保证兑现的本地惊喜，只有成功播放后才消费进度；它不连接收费、抽卡或稀缺性机制。
- 工作导演与 UI 已解耦到 `CompanionContracts`；同一套纯状态机可被应用、
  合约检查和未来事件适配器复用。
- `CompanionWorkdayStateV1` 跨重启保存当天开始、回复就绪、完成、失败、取消、
  失败后恢复与累计专注时长；字段集合不允许任务标题、Prompt、代码、仓库或路径。
- 工作日主记录损坏时回退上一份有效快照，跨日本地清零，不构建 streak、掉级或
  缺席惩罚；顶部状态只显示当天共同完成数量和隐私安全摘要。
- 工作日与关系记忆都提供显式删除入口；删除会同时清除主记录和回滚副本，避免
  后续损坏恢复把用户已经忘记的数据复活。关系删除保留用户选择的语气偏好，但清空
  共同瞬间、纪念物、惊喜进度、最近素材和播放时间。
- `CompanionAttentionBudget` 为主动音画建立会话级预算：Codex turn 边界在两分钟
  冷却、每小时上限、安静时段或媒体忙碌时降级为环境提示，不进入优先队列；
  用户直接操作和可信终态事件始终可达。
- `CompanionExperienceDirector` 是工作、生活关心、用户逗玩与环境存在感的统一仲裁层：
  用户操作立即通过；可信终态在互动或媒体忙碌时进入有界可靠队列；回合就绪降级为
  环境提示；主动关心延后到调度器下一次评估。视频、声音和窗口只执行仲裁结果。
- 体验导演只在会话内保存注意力类别和时间戳，不保存任务标识、用户文本、代码、
  Prompt、文件名或路径；关心与 Codex 提示共享一个每小时主动打扰预算。

## 8. 三种展示模式只用一套主视频

### PresentationProjection

同一 16:9 主片提供：

- `pet`：中心动态裁切，小尺寸；
- `stage`：16:9 局部；
- `fullscreen`：16:9 全屏。

pack manifest 提供：

```json
{
  "safeAreas": {
    "pet": {"x": 0.42, "y": 0.26, "width": 0.16, "height": 0.16},
    "stage": {"x": 0.10, "y": 0.05, "width": 0.80, "height": 0.90}
  },
  "focalTracks": {
    "pet": [
      {"timeMs": 0, "x": 0.46, "y": 0.32, "scale": 2.8},
      {"timeMs": 1800, "x": 0.53, "y": 0.35, "scale": 2.8},
      {"timeMs": 4000, "x": 0.48, "y": 0.33, "scale": 2.8}
    ]
  }
}
```

坐标从源画面左上角计量。轨道必须从 0ms 开始、严格递增且不超过视频时长；Core 线性
插值并把边缘裁切限制在可见范围，验证器保证 safe area 在所有关键帧中完整可见。只有动态
轨道启用 15 Hz 播放时间观察，静态资产没有该周期成本；离线 creator preview 用无脚本的
首／中／尾故事板显示同一几何。

头像不是严肃圆形半身照，而是从完整表演中选择可理解的中心动作。需要全身动作时：

```text
pet idle
  → event
  → expand to stage
  → play full response
  → return to pet
```

### 透明全屏

提供：

- Transparent Overlay；
- Cinematic Background；
- Dim Desktop。

默认遵循用户上次选择。透明模式需要：

- 可见退出按钮/快捷键；
- 不拦截不必要鼠标事件；
- 菜单不超出屏幕；
- 多显示器定位；
- Reduce Motion；
- 可随时静音。

## 9. Interaction Engine

### 输入识别

- single click；
- double click；
- long press；
- short drag；
- long drag；
- fling；
- edge bump；
- hover tease；
- rapid click combo；
- game gesture。

### 反馈合同

每个输入分两阶段：

1. ≤150ms：缩放、光效、轻声音或触觉；
2. ≤500ms：选中视频开始首帧。

禁止只有文字提示。

### 长按放开

状态：

```text
pressed
  → anticipation loop
  → release
  → choose response by hold duration
  → play video+audio
  → return
```

### Fling

速度分段：

- gentle；
- playful；
- strong。

每段至少 3 个视频响应，结合时段和最近记忆随机。过强甩动不做“受伤”或愧疚反馈，只做安全的夸张喜剧动作。

## 10. Media Player

职责：

- AVPlayer 预热；
- 音轨检测；
- 首帧；
- 循环；
- 交叉淡化；
- 响度归一；
- 故障 fallback；
- 播放结束 returnPolicy；
- 三形态投影；
- 多屏。

预加载：

- 当前 idle；
- 每种高概率交互 1 条；
- task completed 2 条；
- 提醒 1 条。

Mac mini M4 基础版目标：

- 空闲内存 <300 MB；
- 连续播放不持续增长；
- 空闲 CPU <3%；
- 视频播放 CPU/GPU 使用稳定；
- 首帧 P95 <500ms；
- 30 分钟无音画漂移；
- 低电量/高温降级。

## 11. Pack Store

### 目录

```text
Application Support/Chengyin/
├── settings.json
├── state.sqlite
├── packs/
│   ├── starter/
│   ├── community/
│   └── local/
├── staging/
├── backups/
├── diagnostics/
└── quarantine/
```

### 安装状态机

```text
downloaded
  → staged
  → manifestValidated
  → signatureValidated
  → filesValidated
  → mediaProbed
  → compatibilityChecked
  → installed
  → activated
```

失败：

```text
failure
  → quarantine
  → restorePrevious
  → report
```

检查：

- path traversal；
- symlink；
- executable；
- 文件数；
- 总大小；
- 单文件大小；
- SHA-256；
- Ed25519 签名；
- schema；
- app compatibility；
- asset ID 唯一；
- trigger 引用；
- 视频解码；
- 音轨声明；
- locale fallback；
- safe area；
- rights metadata；
- content rating。

### 当前 P0 实现边界

已实现：

- `ContentPackValidator` 的路径穿越、软/硬链接、隐藏/未声明文件、可执行文件、大小/数量、SHA-256、SemVer、trigger 和裁切锚点门；
- actor 隔离的事务 store、跨进程 `flock`、staging、不可变版本目录和 fsync + rename 的原子 `active.json`；
- 普通安装拒绝降级、同版本不同内容拒绝、显式回滚，以及可跨重启管理的恢复区；
- 社区／官方声明包需要签名验证器；旧 schema 的 `paid` tier 只做兼容解析，当前没有权益提供者，始终 fail closed；
- staging 中用 AVFoundation/ImageIO 验证媒体可播放性、视频 codec、时长、实际尺寸、AAC 声明与首个可见帧；独立有界质量探针还会真实解码中点／尾点，并拒绝超过 250ms 的音视频首尾时间轴偏移；
- `.chengyinpack` 扁平／单根 ZIP 的有界双头预检、私有 staging、固定系统解压、解压后集合核验、图形化导入及构建／审计 CLI；
- active 且未禁用的视频形成不可变运行时 catalog，按 trigger 和 locale 进入实际 AVPlayer；
- pending 版本真实播放推进后晋升 healthy；首播失败回滚上一版本或禁用首装版本，Starter Bundle 始终可用；
- 版本化设置与活动包显式备份/恢复，并排除 Codex session、Prompt、任务、事件和遥测；
- 67/67 内容包安全、媒体、两阶段事务、提交前复验、锁内一致快照、锁作用域维护、恢复区与运行时 smoke。

尚未实现：

- 生产 Ed25519 公钥/轮换、公开撤回列表与跨设备社区索引恢复；
- 综合响度、采样点之外的长时连续 seek、循环接缝和感知级口型同步自动量化；
- 官方包撤回列表、干净 Mac 端到端恢复与并发长时 soak。

## 12. 本地内容信任边界

当前产品没有账户、权益提供者、支付 SDK、结账链接或购买恢复服务。旧版清单中的
`paid` tier 仍可被解码，是为了返回稳定、可恢复的兼容错误；安装预检在没有权益检查器时
明确拒绝，应用组合根不提供任何检查器实现。可安装的公开内容依赖来源、授权、签名状态、
哈希、媒体探针和首次播放健康度，不依赖用户身份。

## 13. 显式本地入口

当前应用不注册购买或账户深链。Doctor、内容包预览、备份和诊断导出都由用户在本地界面
显式触发，并经过路径、大小、类型和隐私投影检查。任何未来 URL 入口必须先有独立威胁
模型；不能接收 shell、命令、本地绝对路径、凭证或用户 PII，也不能触发自动分享。

## 14. State 与迁移

`settings.json`：

```json
{
  "schemaVersion": 1,
  "personaId": "c01",
  "tone": "warm-support",
  "locale": "zh-Hans",
  "presentationMode": "pet",
  "quietHours": {},
  "reminders": {},
  "sharingPrompt": true
}
```

关系进度使用独立的 `CompanionRelationshipStateV1`，不与内容包或任务正文混存：

- `bondMoments` 只增不减，纪念物只解锁不回收；
- `chemistryLevel` 为 `0...3` 的会话状态，受用户选择的关系语气上限约束，
  新进程自动归零；
- `surpriseProgress` 是有上限、可保证兑现的本地进度，不用于付费随机抽取；
- 最近素材保留 12 条，素材最后播放时间保留 64 条，用于跨重启去重与 cooldown；
- 持久层仅接受 96 字节内的 ASCII 不透明 ID，不提供 prompt、代码、路径或任务标题字段；
- UserDefaults 主记录损坏时回退到上一份有效备份，两者都损坏时返回安全默认值。

迁移：

- 每版本纯函数；
- 先备份后迁移；
- 迁移失败回上一个 schema；
- 未知字段保留；
- pack 与 app 状态分离；
- 卸载说明明确保留/删除选项。

## 15. Doctor

检查：

- macOS/架构；
- 应用签名/公证；
- Pack Store 可写；
- Starter 存在；
- pack hash/signature；
- 视频解码和音轨；
- Event Adapter；
- Codex Legacy 兼容；
- 通知权限；
- 音量；
- 多显示器窗口；
- 本地导入路径；
- 内容包信任状态；
- 磁盘空间；
- 最近崩溃。

输出：

- 用户可读摘要；
- 本地详细报告；
- 一键修复安全项；
- 不自动上传；
- 上传前预览和脱敏。

## 16. 测试策略

### Unit

- Scheduler；
- 去重；
- quiet hours；
- fallback；
- manifest；
- path validation；
- signature；
- state migration；
- 内容包信任拒绝；
- 本地导入路径解析；
- locale fallback。

### Contract

- Event Protocol v1；
- Pack Schema v1；
- 产品边界回执；
- signed pack trust；
- Content manifest。

### Integration

- download → install → play；
- corrupt pack → rollback；
- upgrade → migration；
- restore on clean Mac；
- Legacy Adapter no sessions；
- 断网；
- 社区索引不可用时保持完整本地功能。

### UI

- 三形态；
- 菜单不出屏；
- 透明全屏退出；
- 手势；
- Reduce Motion；
- 字体扩张 40%；
- VoiceOver；
- 多显示器。

### Media

- 30 分钟循环；
- 26+ 视频随机切换；
- 静音/仅声音；
- 无音轨 fallback；
- 48kHz；
- 首帧；
- 音画同步；
- seek；
- 中断恢复。

## 17. CI / Release

Pull Request：

- Swift build；
- XCTest；
- schema validation；
- content lint；
- secret scan；
- dependency audit；
- license check；
- prompt lint fixtures。

Release Candidate：

- clean build；
- Developer ID；
- hardened runtime；
- notarization；
- stapling；
- DMG；
- SBOM；
- SHA256SUMS；
- install on clean VM/Mac；
- upgrade；
- rollback；
- restore；
- 30 minute media soak。

## 18. 兼容与降级

| 故障 | 降级 |
|---|---|
| Codex Adapter 不健康 | 手动/模拟事件；桌宠仍可玩 |
| Seedance 视频解码失败 | 同事件另一片 → TTS → 静音动作 |
| 音轨缺失 | TTS 或无声动作；不假装原生音画 |
| 社区索引离线 | 已安装内容和 Starter 继续；稍后重试 |
| Pack 损坏 | 上一版 → Starter |
| Locale 缺失 | 语言族 → English → 无对白 |
| GPU/温度压力 | 低分辨率、降帧、减少预载 |
| Companion 崩溃 | 安全模式，只启动 Starter |

## 19. 工程阶段

### P0 — Release Safety

- 模块拆分；
- Pack Store；
- Event Protocol；
- State migration；
- Test target；
- doctor；
- License/Privacy/Security；
- signed/notarized DMG。

### P1 — Complete Free Product

- 1 个稳定 Starter 角色与完整场景集；
- 72+ 验收片；
- i18n；
- First-Session；
- 显式本地分享卡草稿；
- Codex Skill。

### P2 — Creator and community depth

- Gallery；
- strict-v2 内容包；
- 权利与无障碍审阅；
- 社区索引与撤回；
- signed community pack。

### P3 — Ecosystem

- Creator SDK；
- community packs；
- review/moderation；
- optional cloud。

P0 未完成不能用更多视频数量掩盖发行风险。
