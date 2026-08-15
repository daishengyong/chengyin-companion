#!/usr/bin/env python3
"""Strip rights-pending Starter media from a generated public Git candidate.

This command is intentionally unable to modify the authoritative checkout. It
operates only on a separate, already-audited bootstrap destination and removes
the exact files declared by the Starter manifest. Unknown media makes the
operation fail instead of being silently deleted or licensed by inference.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import tempfile


CONTRACT = "chengyin.public-code-only/v1"
SOURCE_ROOT = pathlib.Path(__file__).resolve().parents[1]
RESOURCE_RELATIVE = pathlib.Path("Sources/CompanionApp/Resources")
MANIFEST_NAME = "starter-media.json"
MARKER_NAME = "public-code-only.json"
STALE_PACKAGE_ATTESTATIONS = ("SOURCE-PACKAGE.json", "SOURCE-SHA256SUMS.txt")
FORBIDDEN_SUFFIXES = {
    ".mov",
    ".mp4",
    ".m4v",
    ".mp3",
    ".wav",
    ".m4a",
    ".aac",
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".gif",
    ".tiff",
    ".icns",
    ".zip",
    ".dmg",
    ".pkg",
}
APPROVED_PUBLIC_MEDIA_SHA256 = {
    "examples/packs/hello-workday/media/shared-win-enter.mov":
        "6429b62abfdd63d5dff0cd5f351e0c735d6e328383195a5df363cc008eb8547f",
    "examples/packs/hello-workday/media/shared-win-react.mov":
        "fdfd7c5231cb8a77414e5962d304cf62ebab3140c46c7f9955776633ca56c182",
    "examples/packs/hello-workday/media/shared-win-exit.mov":
        "0e63ef87354ddbec9d00ce143b7e5c9769b0a7992417b046748755211d0fd083",
}


class PreparationError(Exception):
    pass


def bounded_root(value: str) -> pathlib.Path:
    root = pathlib.Path(value).expanduser()
    if not root.is_absolute() or root.is_symlink() or not root.is_dir():
        raise PreparationError("root must be a regular existing absolute directory")
    resolved = root.resolve()
    if resolved == SOURCE_ROOT.resolve():
        raise PreparationError("authoritative source checkout cannot be stripped")
    if not (resolved / ".git").is_dir():
        raise PreparationError("root must be a generated Git candidate")
    return resolved


def safe_asset_path(resources: pathlib.Path, raw: object) -> pathlib.Path:
    if not isinstance(raw, str) or not raw or "\\" in raw:
        raise PreparationError("Starter manifest contains an invalid asset path")
    relative = pathlib.PurePosixPath(raw)
    if relative.is_absolute() or any(part in {"", ".", ".."} for part in relative.parts):
        raise PreparationError("Starter manifest contains an escaping asset path")
    candidate = resources.joinpath(*relative.parts)
    if candidate.resolve(strict=False).parent != resources.resolve() and resources.resolve() not in candidate.resolve(strict=False).parents:
        raise PreparationError("Starter asset resolves outside Resources")
    return candidate


def write_marker(resources: pathlib.Path, removed_count: int) -> None:
    marker = {
        "schemaVersion": 1,
        "contract": CONTRACT,
        "starterMediaBundled": False,
        "removedDeclaredAssetCount": removed_count,
        "runtimeFallback": "animatedSystemSymbolsAndLocalContentPacks",
        "networkRequired": False,
        "licenseInferencePerformed": False,
        "approvedFixtureMediaBundled": len(APPROVED_PUBLIC_MEDIA_SHA256),
    }
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=".public-code-only.", suffix=".json", dir=resources
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(marker, stream, ensure_ascii=False, indent=2, sort_keys=True)
            stream.write("\n")
        os.replace(temporary_name, resources / MARKER_NAME)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


def prepare(root: pathlib.Path) -> dict[str, object]:
    resources = root / RESOURCE_RELATIVE
    manifest_path = resources / MANIFEST_NAME
    if resources.is_symlink() or not resources.is_dir() or manifest_path.is_symlink():
        raise PreparationError("regular Starter Resources and manifest are required")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise PreparationError("Starter manifest is unreadable") from error
    assets = manifest.get("assets")
    if not isinstance(assets, list) or not assets:
        raise PreparationError("Starter manifest must declare at least one asset")

    declared: list[pathlib.Path] = []
    seen: set[pathlib.Path] = set()
    for asset in assets:
        if not isinstance(asset, dict):
            raise PreparationError("Starter manifest asset is not an object")
        path = safe_asset_path(resources, asset.get("path"))
        if path in seen:
            raise PreparationError("Starter manifest repeats an asset path")
        if path.is_symlink() or not path.is_file():
            raise PreparationError("Starter manifest does not match the candidate tree")
        seen.add(path)
        declared.append(path)

    for path in declared:
        path.unlink()
    manifest_path.unlink()
    for relative in STALE_PACKAGE_ATTESTATIONS:
        attestation = root / relative
        if attestation.is_symlink():
            raise PreparationError("source-package attestation is symbolic")
        if attestation.exists():
            attestation.unlink()

    for directory in sorted(resources.rglob("*"), key=lambda item: len(item.parts), reverse=True):
        if directory.is_dir() and not directory.is_symlink():
            try:
                directory.rmdir()
            except OSError:
                pass

    write_marker(resources, len(declared))

    unexpected: list[str] = []
    approved_fixture_count = 0
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in FORBIDDEN_SUFFIXES:
            continue
        relative = path.relative_to(root).as_posix()
        expected_hash = APPROVED_PUBLIC_MEDIA_SHA256.get(relative)
        if expected_hash is None:
            unexpected.append(relative)
            continue
        actual_hash = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual_hash != expected_hash:
            unexpected.append(relative)
            continue
        approved_fixture_count += 1
    if unexpected:
        sample = ", ".join(unexpected[:5])
        raise PreparationError(
            f"unknown binary media remains after exact stripping: {sample}"
        )

    return {
        "schemaVersion": 1,
        "contract": CONTRACT,
        "status": "PASS",
        "removedDeclaredAssetCount": len(declared),
        "remainingForbiddenMediaCount": 0,
        "approvedCC0FixtureMediaCount": approved_fixture_count,
        "starterManifestPresent": False,
        "staleSourcePackageAttestationsPresent": False,
        "codeOnlyMarkerPresent": True,
        "authoritativeSourceMutation": False,
        "releaseState": "SOURCE_PREVIEW_ONLY",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--json", action="store_true")
    arguments = parser.parse_args()
    try:
        result = prepare(bounded_root(arguments.root))
    except (OSError, PreparationError) as error:
        result = {
            "schemaVersion": 1,
            "contract": CONTRACT,
            "status": "FAIL",
            "code": "PUBLIC_CODE_ONLY_PREPARATION_FAILED",
            "message": str(error),
            "recoveryAction": "Discard this generated candidate and bootstrap a new one.",
            "authoritativeSourceMutation": False,
            "releaseState": "NOT_PUBLIC_RELEASE_READY",
        }
    if arguments.json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    elif result["status"] == "PASS":
        print(
            "Public code-only preparation: PASS "
            f"({result['removedDeclaredAssetCount']} declared assets removed)"
        )
    else:
        print(f"FAIL  [{result['code']}] {result['message']}")
        print(f"ACTION  {result['recoveryAction']}")
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
