# Codex App Server 回合事件适配器

[English](CODEX-APP-SERVER-ADAPTER.md)

该适配器把一条受信任的本地 Codex App Server 回合通知投影为
Companion Event v1。它解决的是状态语义和隐私清理，不负责启动 App
Server、建立 JSON-RPC 连接、修改 Codex 配置或判断跨回合的用户目标是否完成。

## 完成真实性

| App Server 输入 | Companion 输出 | 用户含义 |
| --- | --- | --- |
| `turn/started` + `inProgress` | `task.started` | 一次 Codex 回合已经开始 |
| `turn/completed` + `completed` | `response.ready` | 有新的 Codex 结果可看；不是整个任务完成 |
| `turn/completed` + `failed` | `task.failed` | 本回合失败 |
| `turn/completed` + `interrupted` | `task.cancelled` | 本回合被中断 |

只有显式任务编排器、用户动作或语义已验证的适配器可以发送
`task.completed`。该投影层在源码和测试中都没有从 App Server 回合完成生成
`task.completed` 的路径。

## 最小隐私投影

适配器只读取 `method`、`params.threadId`、`params.turn.id`、`status` 和可选的
`durationMs`。两个上游 ID 只用于拒绝空值或异常输入，随后立即丢弃。事件不保留
ID、items、错误正文、提示词、回答、工作目录、路径、个人信息、上游时间戳或未知
字段。写入的 Companion Event 使用新的本地 UUID，`taskRef` 为空，metadata 为空，
所有隐私声明均为 false。

输入上限是单条通知 1 MiB，时长上限是 30 天。公开的
[最小投影 Schema](../Schemas/codex-app-server-turn-events-v1.schema.json) 允许上游
添加字段，因为这些字段会被丢弃；它不是完整 App Server 协议的来源真实性证明。

## 本地验证

以下命令只在临时目录写入事件，不触碰正在运行的应用：

```bash
CHENGYIN_EVENT_ROOT="$(mktemp -d)" swift run --disable-sandbox CompanionEventEmitter codex-app-server '{"method":"turn/completed","params":{"threadId":"local-probe","turn":{"id":"local-turn","status":"completed","durationMs":1200}}}'
./scripts/run-codex-app-server-adapter-smoke.sh
```

第二条检查四种状态、未知消息忽略、文件权限、隐私删除、稳定错误码与恢复动作。

## 集成边界

当前公开产物提供的是“单通知入口”：一个受信任的本地传输层可以把收到的完整
通知作为第二个参数交给 `CompanionEventEmitter codex-app-server`。当前版本不包含
常驻 App Server 管理器、初始化握手、重连、流控、进程生命周期管理或用户级配置
写入，因此不能宣称完整 App Server 集成已经完成。

接入真实传输时应保持以下边界：

1. 用户明确开启，并能看到启动命令、数据范围和关闭方法；
2. 只转发单条受支持的回合通知，不记录原始 JSON；
3. 传输层负责健康检查、重连、去重和有界队列；
4. 未识别的 method 被安静忽略，结构损坏则返回稳定错误码；
5. 适配器断开时，点击、游戏、周期关怀和本地素材仍完整可用；
6. 不把内部一致性校验描述为上游来源认证或主动攻击防护。

## 失败回执

错误使用 `APP_SERVER_EVENT_*` 稳定码，输出包含一个可执行恢复动作，不包含用户名、
绝对路径或上游 ID。支持的失败包括 JSON 损坏、结构缺失、method/status 不一致、
时长越界和输入过大。错误不会写入半成品事件，也不会回退成“任务完成”。

