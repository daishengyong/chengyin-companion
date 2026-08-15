# Reviewed community pack index v1 / 社区内容包审阅索引 v1

The repository index is an offline contribution gate, not a store, remote catalog,
or plugin loader. It lists repository-relative Content Packs whose exact manifest
hash has passed strict Content Pack v2 validation and a separate versioned index
review. The app does not fetch this file, execute pack code, create an account, or
make a network request.

仓库索引是离线贡献门，不是商店、远程目录或插件加载器。它只列出仓库内已通过 strict-v2
检查、并由独立版本化索引审阅绑定到准确 manifest SHA-256 的内容包。应用不会联网读取索引、
执行内容包代码、创建账户或引入登录。

## Trust boundary / 信任边界

- `community/index.json` and every referenced pack are untrusted input.
- Paths must be visible, repository-relative directories without traversal,
  hidden components, backslashes or symbolic links.
- The index is bounded to 512 KiB and 64 entries; every manifest is bounded to
  512 KiB and must match both the entry hash and the review hash.
- Pack ID/version must match the exact reviewed manifest.
- `audit-content-pack.sh --strict --json` remains authoritative for media,
  rights, adult/fictional status, accessibility, fallback and review readiness.
- Only `PASS + READY_FOR_LAB + strict-v2 + contributionReady` may enter the index.
- `READY_FOR_LAB` is not final legal approval, official signature, notarization,
  public distribution readiness or endorsement by the project owner.

- `community/index.json` 与每个被引用的内容包都按不可信输入处理。
- 路径只能是仓库内可见的相对目录，不允许穿越、隐藏分量、反斜杠或符号链接。
- 索引最大 512 KiB、64 项；manifest 最大 512 KiB，且必须同时匹配条目哈希和审阅哈希。
- 内容包 ID/版本必须与被审阅 manifest 完全一致。
- 媒体、权利、成年/虚构状态、无障碍、回退和审阅就绪仍以 strict 内容包审计为准。
- 只有 `PASS + READY_FOR_LAB + strict-v2 + contributionReady` 才能进入索引。
- `READY_FOR_LAB` 不代表最终法律审核、官方签名、公证、公开发行就绪或所有者背书。

## Contributor flow / 贡献流程

```bash
./scripts/audit-content-pack.sh /path/to/pack --strict --json
shasum -a 256 /path/to/pack/manifest.json
python3 scripts/audit-community-pack-index.py community/index.json --json
```

1. Put the declarative pack under the repository root; no executable file or URL
   can be introduced through the index.
2. Complete Content Pack v2 package/per-asset rights, accessibility, fallback and
   approved reviews.
3. Record the exact pack ID, version, repository-relative path and manifest hash.
4. A different index review binds its reviewer ID and positive review version to
   the same manifest hash.
5. CI reruns the strict pack audit. Any later manifest byte change invalidates the
   entry until both hashes and the review are refreshed.

1. 把纯声明式内容包放在仓库根目录下；索引不能引入可执行文件或 URL。
2. 完成 Content Pack v2 的包级/逐资产权利、无障碍、回退和批准审阅。
3. 记录准确的内容包 ID、版本、仓库相对路径与 manifest 哈希。
4. 独立索引审阅使用审阅者 ID 和正整数版本绑定同一个 manifest 哈希。
5. CI 重新执行 strict 审计；manifest 任意字节变化都会让条目失效，直到重新审阅并更新两个哈希。
