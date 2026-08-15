# Project-local preview without installation

[简体中文](LOCAL-PREVIEW.zh-Hans.md) · English

`scripts/preview-local.sh` is the shortest safe path from a source clone to a
visible Chengyin Companion. It builds and launches `dist/Chengyin Companion.app`
without reading provider credentials, using the network, or changing
`/Applications`.

```bash
./scripts/preview-local.sh
```

To inspect prerequisites and process conflicts without building, stopping, or
launching anything:

```bash
./scripts/preview-local.sh --check-only --json
```

## Lifecycle contract

The command performs a source-only Mac preflight, classifies every running
`ChengyinCompanion` process, and fails closed if an installed or unverified copy
is active. It may send a normal termination signal only to the executable whose
resolved path is exactly this checkout's `dist` preview. The PID and executable
path are revalidated immediately before termination; no force-kill fallback is
used.

After a successful stop, the command builds into the existing transactional
staging path, launches that exact project-local bundle, and waits until it is the
single verified Chengyin process. This closes the common gap where a bundle was
rebuilt on disk while an older in-memory process kept showing stale behavior.
Process discovery uses macOS `libproc` directly instead of shelling out to
`ps`/`pgrep`; if the OS cannot return a trustworthy snapshot, the preview fails
closed before changing any process.

SwiftPM derived data is resolved through `scripts/swift-build-cache.sh`. The
default cache is outside the checkout, namespaced by the physical project path
and build lane, and write-probed before compilation. A relative override, a
cache inside the source tree, a symlink that resolves back into the source tree,
or an unwritable cache fails closed with a stable recovery code. This keeps a
read-only clone or restricted workspace buildable without adding derived files
to the portable source contract. Advanced local setups may provide an absolute
parent through `CHENGYIN_SWIFT_BUILD_CACHE_ROOT`.

The shared Swift toolchain preflight also write-probes any inherited Clang and
SwiftPM module-cache paths. It resolves the parent to one physical path spelling
and uses a Chengyin-owned compiler/SDK namespace below it; an inaccessible user
cache is replaced by an isolated temporary parent. This prevents `/var` and
`/private/var` aliases or stale foreign module files from colliding, so direct
`swiftc` creator and audit tools follow the same restricted-workspace behavior
as the application build.

If the build fails after a previous project preview was stopped, the command asks
macOS to relaunch the still-valid previous preview. It never modifies the
installed copy. A launch failure leaves the newly built `dist` candidate in
place and returns an executable recovery action.

## Receipt and boundaries

`--json` emits `chengyin.local-preview/v1`, validated by
`Schemas/local-preview-receipt-v1.schema.json`. The receipt reports only process
counts, origin categories, stage states, a reproducible build identity, and a
stable `LOCAL_PREVIEW_*` failure code. It contains no username, PID, media name,
or absolute path.

A PASS proves only that the current checkout built and launched one verified
project-local preview. It does not prove installation, media rights, final
licensing, Developer ID signing, notarization, physical clean-Mac behavior, or
public-release readiness.
