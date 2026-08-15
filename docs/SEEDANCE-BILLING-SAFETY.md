# Seedance Mini 本地计费硬保护

> 状态：已用于 `scripts/generate-seedance-task-complete.py`。它降低误调用和
> 套餐溢出的风险，但不能替代火山控制台的模型关闭、API Key 权限与推理限额。

## 不变量

本项目的外部生成入口只接受精确模型：

```text
doubao-seedance-2-0-mini-260615
```

Seedance Standard、Fast、别名和未来模型 ID 全部 fail-closed；没有危险开关，
也不能通过命令行覆盖。历史目录中的 Fast 合约仅作为生成凭证保留，不能重跑。

每个新合约必须包含：

```json
{
  "model": "doubao-seedance-2-0-mini-260615",
  "billing_guard": {
    "batch_id": "CC-B1-20260731",
    "max_calls": 10,
    "max_package_tokens": 2000000
  }
}
```

固定代码上限是每批 10 次、2,000,000 套餐 Tokens。合约只能进一步收紧，不能
放宽。预算包含当前调用 15% 或至少 50,000 Tokens 的预测误差保护；账本另保留
500,000 Tokens，不允许计划用到零余额。

## Provider Console 对账门

火山 API 的 usage 只返回用量，不能证明最终由资源包还是现金余额结算。因此本地
估算余额不能单独授权生成。新调用前，账本必须同时满足：

- `model` 为精确 Mini Model ID；
- `pay_as_you_go_spillover_allowed` 明确为 `false`；
- `provider_console_reconciled` 为 `true`；
- 每一笔 `topups[].provider_console_reconciled` 为 `true`；
- `provider_console_reconciled_at` 不超过 72 小时；
- `provider_console_remaining_package_tokens` 来自资源包管理页；
- 本地余额不得大于控制台快照；
- `pool_id` 与控制台 Mini 资源包一致。

推荐对账步骤：

1. 在火山费用中心打开 Seedance 2.0 Mini 的资源包实例；
2. 核对实例 ID、当前余量、到期日和最近用量；
3. 把快照写入 `video-production/seedance/mini-external-call-ledger.json`；
4. 将对应充值记录标为已对账；
5. 先运行 dry-run，检查打印的模型、批次预算、余额来源和安全余量；
6. 只有确认输出正确，才使用精确二次确认短语提交。

当前账本包含一笔尚未在控制台对账的 100M top-up，所以外部生成默认被阻止。这是
预期行为，不应为了继续生成而伪造 `true`。

## 两阶段运行

第一阶段只检查，不读 API Key、不导入方舟 SDK、不上传参考视频、不访问网络：

```bash
python3 scripts/generate-seedance-task-complete.py \
  --shot-dir video-production/seedance/<shot-id> \
  --dry-run
```

通过后，人工复核 `seedance_preflight` JSON 中的：

- `model`；
- `batch_id`、`planned_calls` 和批次上限；
- `predicted_package_deduction` 与 `variance_guard`；
- `provider_console_remaining_package_tokens`；
- `locally_tracked_remaining_package_tokens`；
- `intended_balance_source` 与
  `billing_source_verified_by_generation_api=false`。后者明确表示生成 API 不返回
  最终扣费来源，不能把本地判断写成火山真实账单结论。

第二阶段才允许真实提交：

```bash
python3 scripts/generate-seedance-task-complete.py \
  --shot-dir video-production/seedance/<shot-id> \
  --confirm-submit 'USE RECONCILED MINI PACKAGE'
```

合约预算是第一重确认，精确短语是第二重确认。脚本在打印完整预检收据之前不会
读取凭据或初始化方舟客户端。

## 自动检查

以下测试完全离线，覆盖 Standard/Fast 误调、未对账、未对账充值、批次调用上限、
批次 Token 上限和 dry-run 不读取凭据：

```bash
python3 scripts/seedance-safety-checks.py
```

## 仍需控制台保护

本地代码和 JSON 都能被拥有文件权限的人修改，因此不能充当云账户的最终断路器。
生产前仍应：

- 关闭 Standard 与 Fast；
- 使用只授权 Mini 的独立 API Key；
- 给 Mini 设置推理限额；
- 设置资源包余量与账单预警；
- 批次结束后重新核对控制台账单。
