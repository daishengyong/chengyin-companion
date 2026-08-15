# Public code-only checkout

The public MIT repository intentionally excludes the private Starter videos,
voice clips, images, icon artwork, and brand media tracked by
`starter-media.json`. Those assets have a separate rights review and are not
covered by the code license.

The public checkout remains buildable. When
`Sources/CompanionApp/Resources/public-code-only.json` is present, the build
uses animated macOS system-symbol fallbacks and accepts locally installed
Content Pack v2 packages. This mode does not download media, call a generation
provider, or infer a license for missing files.

Maintainers create this tree only from a separate audited Git candidate:

```bash
python3 scripts/prepare-public-code-only.py --root /absolute/generated/candidate --json
```

The command refuses to strip its authoritative checkout, removes only paths
declared by the Starter manifest, and fails if any unknown binary media or
archive remains.

Because stripping changes the tree after portable-source verification, the
exporter also removes the now-stale `SOURCE-PACKAGE.json` and
`SOURCE-SHA256SUMS.txt`; the Git commit becomes the public tree identity.

The only binary media retained by the public exporter is the three tiny,
person-free CC0 abstract clips in `examples/packs/hello-workday`. Their exact
paths and SHA-256 digests are pinned by the exporter; any replacement fails the
gate.

The repository also ships the reviewed GitHub Actions definition at
`ci/github-actions-code-only.yml`. A maintainer may copy it to
`.github/workflows/ci.yml` after authenticating with GitHub's `workflow` scope;
until then it is an inspectable CI template rather than an enabled workflow.

中文说明：公开 MIT 仓库只发布代码和软件文档，不发布仍在权利审阅中的 Starter
视频、语音、图片、图标和品牌素材。公开源码在无素材模式下使用动态系统图形回退，
仍可编译、运行、开发并导入本地 Content Pack v2；它不会联网补素材，也不会伪造授权。
已审阅的 GitHub Actions 配置保存在 `ci/github-actions-code-only.yml`，在仓库维护者
以 `workflow` 权限登录并复制到 `.github/workflows/ci.yml` 前不会自动运行。
