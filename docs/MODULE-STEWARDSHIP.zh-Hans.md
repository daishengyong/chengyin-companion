# 模块维护与贡献审阅路由

简体中文 · [English](MODULE-STEWARDSHIP.md)

澄音用可执行契约记录审阅归属，同时不虚构人员或 GitHub 账号。
`community/module-stewardship.json` 是经过审阅的策略，
`Schemas/module-stewardship-v1.schema.json` 是公开结构，
`scripts/audit-module-stewardship.py` 是权威的离线审计器和改动路径路由器。

## 契约回答什么

每个被路由的模块只在回执中给出稳定 ID：

- 审阅角色；
- 必须执行的本地检查及可执行命令；
- 风险类别；
- RFC 策略；
- 所有者门策略。

回执不会包含提交的路径、检出目录、用户名、进程 ID 或媒体文件名；工具不请求网络，
并始终保留明确的 `NOT_PUBLIC_RELEASE_READY` 边界。

## 运行契约

审计策略本身：

```bash
python3 scripts/audit-module-stewardship.py --audit --json
```

路由一个或多个仓库改动路径：

```bash
python3 scripts/audit-module-stewardship.py --path Sources/CompanionContracts/CompanionEvent.swift --path docs/MODULE-STEWARDSHIP.md --json
```

也可以通过换行分隔的版本控制改动列表传入路径，原始路径不会进入回执：

```bash
git diff --name-only --diff-filter=ACMRTUXB | python3 scripts/audit-module-stewardship.py --stdin --json
```

路由器按规范化的仓库相对名称匹配，因此能处理已删除文件；策略审计会另行证明每个
声明的前缀和精确路径都真实存在于可信检出中。精确路径优先于前缀，否则最长匹配前缀
优先。同等精度歧义、未知根目录、生成／私有区域、路径穿越语法和符号链接策略文件都会
以稳定 `STEWARDSHIP_*` 错误码失败，并给出可执行恢复建议。

## 身份与所有者边界

六个维护角色有意保持为 `unassigned-until-canonical-github-organization`。
maintainer 与 release-owner 记录表达所有者边界，不代表公开账号身份。项目所有者建立
规范 GitHub 组织后，可以通过另一项经过审阅的改动绑定真实账号并生成
`.github/CODEOWNERS`；在此之前，由 Pull Request 与 ADR 记录实际参与审阅的人。

路由不等于批准。匹配到角色不能证明素材权利、无障碍质量、安全性、最终许可证、签名、
公证或公开发行同意。回执只是把这些审阅和所有者门显示出来，避免贡献静默越界。

## 演进策略

新增仓库区域时：

1. 添加一个范围尽量小的模块路由，优先复用现有角色和检查 ID。
2. 只有职责确实不同才增加新角色或检查。
3. 命令保持本地、纯参数形式，不能包含 shell 运算符、重定向、绝对路径或联网工具。
4. 在 `scripts/run-module-stewardship-smoke.sh` 中补齐正常与拒绝用例。
5. 审阅前运行快速贡献者门和公共文档双语一致性检查。

优先使用嵌套模块，不使用宽泛例外。构建产物、本地桥接目录、Python 缓存和制作备份始终
属于禁止贡献路径。
