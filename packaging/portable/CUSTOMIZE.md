# 用 Codex 改造自己的伴侣

推荐从“小改动 → 内容包 → 深度玩法”逐层推进。

## 1. 换一段视频（10 分钟）

把新的 16:9 H.264/AAC 视频放入：

```text
Sources/CompanionApp/Resources/
```

优先替换同名素材，例如 `companion-event-task_complete.mov`。然后告诉 Codex：

```text
检查新视频的分辨率、时长、音轨和首帧，把它接入任务完成场景；
运行全部检查并安装到本机，但测试事件必须写到临时目录。
```

## 2. 改台词和提醒

台词索引位于：

```text
Sources/CompanionApp/Resources/voice-lines.json
```

音频位于 `Resources/Audio/`。不要只改 JSON 而漏掉音频文件；Codex 的 doctor 会逐条检查存在性和可解码性。

## 3. 新增动作或小游戏

让 Codex 先定位：

- `Models.swift`：动作、场景和状态模型；
- `CompanionViewModel.swift`：调度、优先级、提醒和交互状态；
- `ContentView.swift`：窗口、视频层和鼠标手势；
- `CompanionWorkDirector.swift`：Codex 任务生命周期。

一次只增加一个明确闭环：输入动作 → 即时反馈 → 视频/声音奖励 → 冷却与避免重复 → 自动测试。

## 4. 用 Seedance 生成新角色与场景

建议先做一条无视频输入的“角色母片”，锁定成年原创角色、发型、脸型、身材比例、服装、色彩和镜头语言；之后尽量用母片作为视频输入生成派生动作，以降低成本并提高身份一致性。

每个镜头都记录：Prompt、模型、任务 ID、输入权利、资源包 Tokens、输出哈希、是否有原生音轨、自动转写结果和人工审核状态。不要模仿明星、公众人物或可识别真人。

## 5. 最稳妥的 Codex 指令模板

```text
在当前 Chengyin Companion 源码上增加【你的玩法】。
要求：复用现有三种窗口形态和视频调度；不读取对话、代码、路径或 Prompt；
不把 agent-turn-complete 当成任务完成；测试事件只能写入临时目录；
完成后运行 doctor，真实安装通过后才发送一次 task.completed。
```

