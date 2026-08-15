## User problem / 用户问题

<!-- 这项改动解决什么问题？ -->

## Change / 改动

<!-- 简述实现和可见行为。 -->

## Validation / 验证

- [ ] `swift build -c release`
- [ ] 内容包 smoke 校验
- [ ] `python3 scripts/check-public-doc-parity.py`
- [ ] `python3 scripts/audit-public-source-secrets.py --json`
- [ ] `python3 scripts/audit-module-stewardship.py --audit --json`，并按改动路径回执完成角色／检查／RFC／所有者门审阅
- [ ] 若修改社区索引：`./scripts/run-community-pack-index-smoke.sh`
- [ ] 新增失败分支有稳定错误码，且界面没有直接显示原始系统错误
- [ ] 相关小游戏 smoke 校验
- [ ] 真实窗口操作检查

## Risk and data / 风险与数据

- [ ] 没有提交密钥或个人数据
- [ ] 没有新增未经说明的权限或网络请求
- [ ] 新素材已说明来源、成年虚构角色状态和使用权
- [ ] 索引条目绑定准确 manifest SHA-256，并通过 strict-v2 审阅、无障碍与回退门
- [ ] 完整免费体验没有增加计时、日限额、广告、强制登录或情绪付费墙
- [ ] 新持久化字段有迁移/回滚，新体验有离线与失败降级
