# 不安装的一键项目预览

简体中文 · [English](LOCAL-PREVIEW.md)

`scripts/preview-local.sh` 是从源码克隆到看见澄音 Companion 的最短安全路径。
它构建并启动 `dist/Chengyin Companion.app`，不读取服务商凭据、不联网，也不修改
`/Applications`。

```bash
./scripts/preview-local.sh
```

只检查前置条件和进程冲突，不构建、不停止进程也不启动应用：

```bash
./scripts/preview-local.sh --check-only --json
```

## 生命周期契约

命令先执行仅源码的 Mac 预检，再分类所有正在运行的 `ChengyinCompanion` 进程。
如果发现已安装副本或来源未验证的副本，它会关闭失败。只有当可执行文件解析后的路径
严格等于当前克隆的 `dist` 预览时，才允许发送正常退出信号；退出前会重新核对 PID 与
路径，并且不会用强制杀进程兜底。

旧项目预览正常退出后，命令通过现有事务式 staging 构建，启动这个明确的项目内
bundle，并等待它成为唯一且可验证的澄音进程。这修复了“磁盘上的 bundle 已重建，
内存里的旧进程却继续展示旧行为”的常见断层。
进程发现直接使用 macOS `libproc`，不再调用可能被受限环境禁止的 `ps`/`pgrep`；如果系统
无法返回可信快照，预览会在改变任何进程之前关闭失败。

SwiftPM 派生数据由 `scripts/swift-build-cache.sh` 解析。默认缓存位于源码克隆之外，
按照物理项目路径和构建用途隔离，并在编译前执行真实写探针。相对覆盖路径、源码树内
缓存、解析后返回源码树的符号链接以及不可写缓存都会用稳定恢复代码关闭失败。这样只读
克隆或受限工作区仍可构建，也不会把派生文件带进可移植源码契约。高级本地环境可以通过
`CHENGYIN_SWIFT_BUILD_CACHE_ROOT` 提供一个绝对父目录。

共享 Swift 工具链预检还会对继承的 Clang 与 SwiftPM 模块缓存执行写探针，把父目录解析为
唯一的物理路径写法，并在其下使用由编译器与 SDK 隔离的 Chengyin 专属命名空间；不可访问的
用户缓存会被替换为隔离临时父目录。这样 `/var` 与 `/private/var` 别名或外部陈旧模块不会
相互碰撞，直接调用 `swiftc` 的创作者和审计工具也与应用构建具有相同的受限工作区行为。

如果停止旧项目预览后构建失败，命令会请求 macOS 重新打开仍然有效的上一份预览，
绝不会改动已安装副本。如果新候选已经构建但启动失败，它会保留 `dist` 候选并返回
可执行的恢复动作。

## 回执与边界

`--json` 输出 `chengyin.local-preview/v1`，由
`Schemas/local-preview-receipt-v1.schema.json` 约束。回执只包含进程数量、来源类别、
阶段状态、可复现构建身份和稳定的 `LOCAL_PREVIEW_*` 错误码，不包含用户名、PID、
素材名称或绝对路径。

PASS 只证明当前克隆构建并启动了一个可验证的项目内预览；它不证明已安装、媒体权利、
最终许可证、Developer ID 签名、公证、实体干净 Mac 表现或公开发行就绪。
