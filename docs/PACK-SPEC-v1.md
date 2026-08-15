# Chengyin Content Pack v1

本文定义澄音内容包第一版的安全边界。它是实现草案，不是最终公开协议。

新内容建议使用向后兼容的 [Experience Pack v2](PACK-SPEC-v2.md)；v1 包仍受支持，
无需为了继续播放而迁移。

> 当前实现（2026-08-11）：本地包验证、事务安装、原子活动版本、升级/回滚、
> 可恢复卸载、显式备份、运行时 trigger/locale 解析和首播健康回滚已落地并通过
> 67/67 smoke。视频 H.264/H.265、AAC、时长、尺寸、音轨声明、首帧、中点／尾点真实解码与 250ms 音视频时间轴包络已在
> staging 探测、本地目录与 `.chengyinpack` 图形化导入；生产 Ed25519、公钥轮换和真实付费权益仍是发布阻断项。

## 设计目标

- 同一份横屏视频可供头像、半身和全屏通过安全区裁切复用。
- 新增场景、动作、台词和配置不需要重新编译 Core。
- 免费包、官方付费包和用户本地包使用同一结构。
- 安装、更新、卸载和回滚不影响用户设置。
- 第一版只允许声明式内容，禁止任意代码。

## 包结构

```text
cc.chengyin.pack.example-1.0.0.chengyinpack
├── manifest.json
├── manifest.sig
├── preview/
│   ├── cover.webp
│   └── trailer.mov
├── media/
│   ├── scene.mov
│   └── fallback.m4a
├── games/
│   └── feed.json
└── localization/
    └── zh-Hans.json
```

## Manifest 必填字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `schemaVersion` | Integer | 固定为 1 |
| `id` | String | 反向域名、全局唯一 |
| `version` | SemVer | 内容包版本 |
| `minAppVersion` | SemVer | 最低 Core 版本 |
| `tier` | Enum | `free`、`paid` 或 `local` |
| `character` | String | 角色标识 |
| `locales` | [String] | 支持语言 |
| `assets` | [Asset] | 素材声明 |
| `license` | String | 内容许可证标识 |

官方包还必须有独立的 `manifest.sig`。用户本地包可以无签名，但 UI 必须明确标记“本地未审核内容”。

## Video Asset

```json
{
  "id": "kitchen-welcome",
  "kind": "video",
  "path": "media/kitchen-welcome.mov",
  "sha256": "64 lowercase hex characters",
  "durationMs": 5200,
  "width": 1280,
  "height": 720,
  "aspectRatio": "16:9",
  "hasNativeAudio": true,
  "loop": false,
  "cropAnchors": {
    "pet": {"x": 0.50, "y": 0.32, "scale": 2.8},
    "stage": {"x": 0.50, "y": 0.50, "scale": 1.0},
    "fullscreen": {"x": 0.50, "y": 0.50, "scale": 1.0}
  },
  "triggers": ["doubleTap", "evening"],
  "tags": ["kitchen", "warm", "welcome"],
  "cooldownSeconds": 900,
  "weight": 1.0
}
```

`x` 与 `y` 是 `0...1` 的归一化焦点，其中 `y=0` 表示画面顶部；`scale`
是 `1...8` 的缩放值。新包使用 `pet`、`stage`、`fullscreen`。运行时继续接受
v1 已发布包中的 `partial` 和 `full` 别名，但迁移或审计不得据此伪造新的授权状态。
缺失锚点会使用稳定的形态默认值；非法数值在安装校验时拒绝，在投影边界还会再次
安全回退。开启“降低动态效果”时不创建视频投影，而使用静态内置回退。

## 触发模型

第一版只允许白名单触发器：

- `idle`
- `singleTap`
- `doubleTap`
- `longPressRelease`
- `drag`
- `fling`
- `taskStarted`
- `taskLongRunning`
- `taskCompleted`
- `taskFailed`
- `taskCancelled`
- `responseReady`
- `morning`
- `evening`
- `hydration`
- `stretch`
- `gameWon:<game-id>`
- `manual:<action-id>`

Core 当前约定以下稳定手动 ID，内容包不要依赖中文显示名：

- `manual:action.<drink|stretch|clap|jump|twirl|laugh|heart|kiss|cheer>`
- `manual:scene.<scene-id>`
- `manual:mini.<mini-scene-id>`
- `manual:event.<event-id>`

四个非终态工作日触发器 `taskStarted`、`taskLongRunning`、
`taskCancelled`、`responseReady` 要求 `minAppVersion >= 0.19.42`。开始、
长任务和取消只在没有主动互动、小游戏或前景媒体占用注意力时选择内容；普通
`taskProgress` 只更新安静陪伴状态，不形成素材触发器。`responseReady` 只表示
Codex 出现新结果，绝不能作为任务完成声明。旧包和旧的
`manual:event.reply_ready` 路由继续可用；迁移不得把它改写成 `taskCompleted`。

内容包不能直接读文件、网络、剪贴板、摄像头或麦克风。

## 播放选择

Core 根据以下顺序选择素材：

1. 事件必须与 `triggers` 匹配；
2. 当前形态必须存在可用裁切；
3. 必须满足语言和权益；
4. 冷却期内不重复；
5. 排除最近六次播放；
6. 按时段、标签和 `weight` 加权随机；
7. 没有符合项时回退到 Starter Pack。

## 安装约束

- 单包压缩体积上限：512 MiB。
- 文件数上限：256。
- 解压体积上限：1.5 GiB。
- 路径必须是相对路径且不能包含 `..`。
- 禁止软链接、硬链接、Mach-O、脚本、动态库和隐藏可执行文件。
- 视频第一版限定 H.264/H.265 + AAC 的 MOV/MP4。
- 音频限定 AAC/M4A/WAV。
- 图片限定 PNG/JPEG/WebP。
- JSON 必须通过对应 schema。

具体上限在公开发布前根据真实素材压缩结果校准。

## 安装事务

```text
download
  → verify archive hash
  → unzip to temporary directory
  → validate manifest and paths
  → verify every file hash
  → verify signature and entitlement
  → decode media headers/first frame/audio track
  → atomically move into packs/<id>/<version>
  → mark active
```

任何一步失败都删除临时目录并继续使用当前版本。更新成功后保留上一版本，直到新版本至少完成一次成功播放。

`.chengyinpack` 是 ZIP 容器，可将文件直接放在归档根，也可只包含一个顶层目录；两种布局都必须
在对应包根包含 `manifest.json`。运行时先把用户选择复制为 mode-0700 私有快照，再同时核验中央目录
和每个局部文件头，拒绝 ZIP64、加密、非 stored/deflate 压缩、路径穿越、链接、隐藏项、重复／大小写／
Unicode 碰撞、局部头欺骗、超大条目与高压缩比。固定的 `/usr/bin/ditto` 只处理这份已检查快照；
解压后文件集合、类型和大小必须与预检完全一致，然后才进入原有内容包验证和事务安装。

```bash
./scripts/build-content-pack-archive.sh /tmp/my-pack /tmp/my-pack.chengyinpack --json
./scripts/audit-content-pack-archive.sh /tmp/my-pack.chengyinpack --json
```

构建器不会覆盖已有文件，会在临时归档通过独立审计后才原子发布。成功回执不包含本机路径，也不代表
素材权利、签名或公开发行已经通过。

## 移除与跨重启恢复

“移除”不会立即删除内容包，而是把整个包目录原子移动到 mode-0700 的本机恢复区。
恢复区最多展示 128 项；应用重启后仍会重新枚举。UI 只接收经过 ASCII、长度和单层父目录
约束的不透明条目 ID，不接收或显示绝对路径。每项恢复前会重新验证 `active.json`、活动版本、
manifest 和素材树；损坏、链接或声明不一致的项只能单项永久清理，不能恢复，也不会阻断其他
合法恢复项。

恢复先确认目标包不存在，再移动并重新完成完整包验证。验证失败时会把目录移回原恢复位置；
若连回滚也失败，返回 `PACK_STORE_RECOVERY_ROLLBACK_FAILED`，不得声称现有内容未受影响。
永久清理必须由用户逐项确认，只删除解析后的一个直接子项；符号链接只删除链接本身，不跟随到
外部目标。恢复区校验保证的是本机事务与路径边界，不证明素材授权或包来源真实性。

当前运行时把 `active.json` 作为真相源。活动包中的视频只有在未被禁用时才进入
内存 catalog；播放器真实推进到至少一个可见时间点后把 pending 版本标记为
healthy。首播失败时，有上一版本就原子回滚，没有上一版本就禁用该包并继续使用
Starter Bundle。版本目录保持不可变，播放中的 URL 不会被就地覆盖。

## 权益与离线

- `free` 和 `local` 不查询支付状态。
- `paid` 安装时验证 entitlement；播放时只读取本地签名缓存。
- 永久购买不因网络离线失效。
- 订阅内容在最后一次在线验证后至少保留 30 天离线宽限。
- 支付服务不可用不能阻止 Starter Pack 启动。

## 版本与迁移

- Core 忽略不认识的可选字段。
- Core 拒绝高于自身支持范围的 `schemaVersion`。
- 包更新不得覆盖 `state.sqlite` 或用户设置。
- 删除包前显示其保存数据；用户可选择保留游戏进度。

## 公开前必须补齐

- JSON Schema 文件。
- Ed25519 签名和密钥轮换方案。
- `chengyin-pack validate` 命令行验证器。
- 恶意压缩包和损坏媒体测试夹具。
- 内容许可证、角色权利、音色权利和模型输出清单。
- 商店下架与安全撤回协议。
- 干净 Mac 端到端归档导入与恢复的人工作者验证。
