# Seedance Mini 单镜头演示工作台

这个目录只用于制片人明确决定现场重新生成一条视频时。现成素材足以完成节目，不运行这里的脚本也不会影响录制、安装或剪辑。

## 使用顺序

1. 按 `program-materials/09-ENVIRONMENT-SETUP.md` 准备 Python 虚拟环境和火山控制台。
2. 用自己的费用中心快照填写 `video-production/seedance/mini-external-call-ledger.json`。模板默认 `provider_console_reconciled=false`，因此不会误提交。
3. 先运行完全离线的保护测试和 dry-run。
4. 把模型、次数、预计资源包扣除和停止条件展示给真人。
5. 只有真人本轮明确确认后，才加载 `producer-tools/seedance.env` 并使用精确确认短语提交。
6. 成功后回费用中心核对实际抵扣；生成 API 的 usage 不能证明最终扣的是资源包还是现金余额。

## 默认硬限制

- 只接受 `doubao-seedance-2-0-mini-260615`；
- 只接受 480p/720p；
- 单镜头 4–15 秒；
- 每批最多 10 次、2,000,000 套餐 Tokens；
- 至少保留 500,000 套餐 Tokens；
- 控制台快照超过 72 小时即阻止提交；
- 真实提交需要精确短语 `USE RECONCILED MINI PACKAGE`。

这些是本地保护，不是云端硬停机。模型 ID、价格、资源包抵扣和 API 参数必须在录制当天按火山官方页面复核。
