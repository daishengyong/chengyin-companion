# CodexSkin 借鉴审计

> 日期：2026-07-30  
> 结论：借工程习惯，不借运行时架构、视觉素材或角色方向。

## 对照项目

用户所说的 “Codex QQ Skin” 高概率指：

- https://github.com/seeyouintokyo/codexskin

相关但不同的换肤项目：

- https://github.com/aithink001/Codex-Dream-Skin-Themes
- https://github.com/Fei-Away/Codex-Dream-Skin

`seeyouintokyo/codexskin` 是 macOS 上的 Codex 静态主题注入器。它通过本机
Chromium DevTools Protocol 给官方 Codex 页面增加背景、颜色和装饰层，不是桌宠、
视频伴侣或任务反馈应用。

## 实际能力差异

| 能力 | CodexSkin | Chengyin Companion |
|---|---|---|
| 运行形态 | Codex 页面内 CSS / DOM 注入 | 原生 macOS 常驻窗口 |
| 主视觉 | 静态 Hero 与配色 | 16:9 原生音画视频 |
| 角色 | 无 | 单一原创成年角色与可扩内容包 |
| 点击、双击、长按、拖拽、甩动 | 无 | 有 |
| 任务事件 | 无 | Companion Event / Codex adapter |
| 小游戏 | 无 | 有 |
| 离线播放 | 静态主题 | 本地 AVPlayer 视频与音频 |
| 对 Codex DOM 的依赖 | 高 | 无 |
| 内容包恢复 | 主题清理脚本 | 事务安装、验证、回滚与 Starter fallback |

## 借鉴

### 1. 安装—验证—恢复三段式

把面向普通用户的维护动作固定为：

```text
安装或启用
  → 自动验证
  → 明确显示健康状态
  → 一键恢复默认
```

Chengyin 应在状态栏保留三个非技术按钮：

- 检查状态；
- 修复显示；
- 恢复默认。

### 2. 幂等自愈

借鉴 `ensure / cleanup` 的思想，但不复制 DOM observer：

- 睡眠唤醒后重新确认窗口和播放器；
- 显示器切换后重新约束窗口；
- 视频解码失败时切下一条并回滚损坏包；
- AVPlayer 或窗口丢失时可重复执行恢复，不产生多个窗口或播放器。

### 3. 轻量外观清单

在现有 Content Pack 之上增加可选 `appearance` 层，而不是新建另一套主题系统：

```json
{
  "backgroundStyle": "transparent",
  "accentColor": "#C96B8D",
  "controlTint": "#F1D7DF",
  "subjectFocalPoint": {"x": 0.50, "y": 0.42},
  "petScale": 2.8
}
```

外观层只描述颜色、安全区和焦点，不包含脚本、CDP、远程代码或可执行文件。

### 4. 发布前安全测试思路

- 不修改、复制或重签官方 Codex；
- 不开放 CDP 或远程调试端口；
- 包资源路径不能越界；
- 官方包未签名不激活；
- 文件大小、数量和媒体规格有上限；
- 播放失败必须自动回滚；
- 验证不通过不能报告成功。

这些原则与当前 PACK-SPEC 和 20/20 内容包 smoke 一致，只需在后续 UI 自愈测试中补齐。

## 不借鉴

### CDP 注入

不采用。它依赖 Codex 页面结构、调试端口和 DOM 选择器，升级后易失效，也扩大本机
调试接口的攻击面。Chengyin 继续使用原生 Swift / NSPanel / AVPlayer。

### 静态 Hero 素材

不采用。仓库整体使用 MIT 不等于每张 Hero 的生成与商业权利链已经逐项证明，而且
这些图片与单一视频角色身份无关。

### 主题代码与高频 DOM 观察

不复制。当前项目已有更强的事务安装、签名接口、媒体探测、首播健康回滚和状态恢复。
主题注入约数 MB 的脚本载荷以及全 DOM 观察，不适合常驻视频伴侣。

### 作为产品底座

不采用。该仓库当前规模很小、没有 Release 或 CI，也没有桌宠、任务事件、视频、音画、
手势和小游戏，不应让它改变“单一澄音 + 原生视频交互”的产品方向。

## 决策

当前视频生产继续走：

```text
单一原创成年澄音母片
  → Seedance 含视频输入派生
  → 16:9 原生音画
  → pet / stage / fullscreen 同源投影
  → Content Pack 验证与回滚
```

CodexSkin 只贡献“可验证、可恢复、可自愈”的工程启发，不贡献角色、视频或注入架构。

