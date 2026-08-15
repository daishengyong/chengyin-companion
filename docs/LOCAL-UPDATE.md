# 本地构建、更新与回滚

本文只描述源码仓库到本机 `/Applications` 的开发版更新链路。它不会创建
Developer ID 签名、公证、DMG 或公开 Release。

## 为什么源码改了，界面可能没有变化

源码、SwiftPM release 二进制、`dist` 应用包、`/Applications` 已安装应用和
当前进程是五个不同状态。`swift build -c release` 只更新 `.build`；它不会
重新组装 `dist`，也不会替换或重启 `/Applications` 中的应用。

每个由 `scripts/build-app.sh` 组装的新应用都会在 `Info.plist` 写入：

- `ChengyinSourceFingerprint`：影响应用的源码和资源 SHA-256；
- `ChengyinBuildIdentity`：版本、构建号和源码指纹短码；
- `ChengyinBuildTimestamp`：UTC 组装时间。

因此即使开发中忘记递增可见版本，也能判断正在运行的是否为当前源码。

安装器判定“已经是当前版本”时，会比较完整的源码指纹、版本、构建号、Bundle ID
和规范化构建身份。它不会要求两个应用包逐字节相同，因为重复组装同一源码时，
`ChengyinBuildTimestamp` 和 ad-hoc 签名可能变化。不同源码、版本、构建号或应用
身份仍会进入正常更新/拒绝降级路径。

## 推荐更新

如果只需要立即看到当前克隆的最新效果，优先使用不修改 `/Applications` 的一键
项目预览：

```bash
./scripts/preview-local.sh
```

它会只回收当前克隆的精确 `dist` 进程、重新构建、启动并核对运行中源码身份；已安装
副本或来源未知副本仍在运行时会关闭失败。完整契约见
[不安装的一键项目预览](LOCAL-PREVIEW.zh-Hans.md)。

确实需要更新已安装副本时，先预览安装计划：

```bash
./scripts/install-local-app.sh --dry-run
```

预览会重新构建并验证 `dist`，但不会退出、替换或重启应用。确认候选身份后运行：

```bash
./scripts/install-local-app.sh
```

流程如下：

1. 构建 release，并确认构建期间源码没有变化；
2. 在全新 staging 目录组装资源，防止旧资源残留；
3. 写入构建身份并进行本地 ad-hoc 完整性封装；
4. 校验 Bundle ID、可执行文件、资源和 bundle 指纹；
5. 正常退出旧进程；
6. 在 `/Applications` 同一文件系统内原子交换新旧 `.app`；
7. 再次验证新应用及用户状态；
8. 从明确路径重新打开，并确认新进程保持运行；
9. 把上一版移到 `dist/install-backups/`。

“已经是当前版本”的身份比较只用于决定是否需要替换。只要实际进入替换流程，
staging、安装后验证和失败回滚仍使用候选应用的严格 bundle 指纹，避免复制损坏
或非候选内容被误认为安装成功。

应用更新不会写入或删除以下用户状态：

- `~/Library/Preferences/local.zidong.chengyin-companion.plist`；
- `~/Library/Application Support/Chengyin/content-store`；
- `~/Library/Application Support/ChengyinCompanion`。

事件队列和运行锁可能在更新期间自然变化，不作为静态状态校验对象，但安装器同样
不会删除它们。

## 失败与回滚

- staging 校验失败：已安装应用保持不变；
- 旧进程无法退出：替换不会开始；
- 原子交换后的验证失败：立即交换回上一版；
- 用户状态校验异常：恢复上一版且不自动重启；
- 新应用无法保持运行：恢复并重新打开上一版；
- 更新成功：上一版保留在 `dist/install-backups/`。

当前没有图形化回滚按钮。需要回滚时先停止应用，保留当前版本，然后用同一原子安装
流程重新安装经过验证的旧候选；不要直接删除用户数据。

## Doctor

```bash
./scripts/doctor.sh
```

Doctor 分别报告：

- 当前源码指纹；
- 确定性的本地更新身份 smoke（同源码重复构建命中，不同源码/版本/构建不命中）；
- `dist` 候选的版本和构建身份；
- `/Applications` 已安装版本和构建身份；
- 运行进程是否来自明确安装路径；
- 进程是否早于已安装 bundle，因而需要重启；
- 原子交换 helper 是否可编译并通过本地 smoke。

运行身份由独立审计器统一判断：

```bash
python3 scripts/audit-local-runtime-identity.py --json
```

回执把源码、`dist` 候选、安装副本和运行进程分层报告。运行中的当前 `dist`
预览会标记为可用于工程验证，但只要安装副本仍旧，就保持
`PENDING [UI_RUNTIME_IDENTITY_INSTALL_REQUIRED]`；它不会把“预览可用”提升为
“本机安装完成”。旧进程、多个进程、来源不明副本和损坏身份都有各自稳定错误码。
JSON 和 Doctor 摘要只包含短指纹、版本、状态与来源类别，不输出 PID、用户名或绝对路径。

缺少构建身份、源码指纹不一致或更新后未重启都会明确失败，不再依靠“看起来版本号
一样”判断更新是否生效。
