#!/usr/bin/env python3
"""Run local, network-free Chengyin contribution gates with path-safe receipts."""

from __future__ import annotations

import json
import os
import pathlib
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from typing import Optional, Union


SCHEMA_VERSION = "chengyin.contributor-check/v1"
RELEASE_STATE = "NOT_PUBLIC_RELEASE_READY"
SUPPORTED_PROFILES = {"quick", "full", "pack"}


@dataclass(frozen=True)
class Check:
    identifier: str
    command: tuple[str, ...]
    recovery_action: str
    timeout_seconds: int = 300
    depends_on_previous: bool = False
    expected_artifact: Optional[pathlib.Path] = None


def quick_checks() -> list[Check]:
    return [
        Check(
            "python-runtime",
            ("./scripts/check-python-runtime.sh",),
            "Run ./scripts/check-python-runtime.sh and install a supported Python 3 if requested.",
        ),
        Check(
            "public-source-secret-audit",
            ("python3", "scripts/audit-public-source-secrets.py", "--json"),
            "Run python3 scripts/audit-public-source-secrets.py --json; revoke and remove any detected credential before contributing or packaging.",
        ),
        Check(
            "product-boundary",
            ("python3", "scripts/audit-product-boundary.py", "--scope", "public", "--json"),
            "Run python3 scripts/audit-product-boundary.py --scope public --json and remove any payment, forced-account, advertising, automatic-sharing or public historical-research regression.",
        ),
        Check(
            "public-git-bootstrap",
            ("./scripts/run-public-git-bootstrap-smoke.sh",),
            "Run ./scripts/run-public-git-bootstrap-smoke.sh and restore the audited staged main candidate without adding a commit or remote.",
            timeout_seconds=900,
        ),
        Check(
            "public-doc-parity",
            ("python3", "scripts/check-public-doc-parity.py"),
            "Run python3 scripts/check-public-doc-parity.py and align the paired public documents.",
        ),
        Check(
            "localization-parity",
            ("python3", "scripts/check-localization-parity.py"),
            "Run python3 scripts/check-localization-parity.py and update both base locales.",
        ),
        Check(
            "accessibility-localization",
            ("python3", "scripts/audit-accessibility-localization.py", "--json"),
            "Run python3 scripts/audit-accessibility-localization.py --json and repair the reported semantic contract.",
        ),
        Check(
            "content-pack-archive-integration",
            ("python3", "scripts/check-content-pack-archive-integration.py"),
            "Run python3 scripts/check-content-pack-archive-integration.py and restore the shared safe archive import contract.",
        ),
        Check(
            "content-pack-scaffold",
            ("./scripts/run-content-pack-scaffold-smoke.sh",),
            "Run ./scripts/run-content-pack-scaffold-smoke.sh and restore atomic path-safe draft creation without inferred rights.",
            timeout_seconds=600,
        ),
        Check(
            "content-pack-locale-matrix",
            ("./scripts/run-content-pack-locale-matrix-smoke.sh",),
            "Run ./scripts/run-content-pack-locale-matrix-smoke.sh and restore copy-free media eligibility and accessibility fallback receipts.",
            timeout_seconds=600,
        ),
        Check(
            "first-session-integration",
            ("python3", "scripts/check-first-session-integration.py"),
            "Run python3 scripts/check-first-session-integration.py and restore the local-first onboarding contract.",
        ),
        Check(
            "game-reward-audit-integration",
            ("python3", "scripts/check-game-reward-audit-integration.py"),
            "Run python3 scripts/check-game-reward-audit-integration.py and restore all six fullscreen reward and pet-restoration proofs.",
        ),
        Check(
            "game-reward-receipt-matrix",
            ("python3", "scripts/run-game-reward-receipt-smoke.py"),
            "Run python3 scripts/run-game-reward-receipt-smoke.py and restore the simulated rejection matrix without claiming live GUI proof.",
        ),
        Check(
            "stable-error-codes",
            ("python3", "scripts/check-error-code-contract.py"),
            "Run python3 scripts/check-error-code-contract.py and register or repair the stable failure code.",
        ),
        Check(
            "local-preview-contract",
            ("./scripts/run-local-preview-smoke.sh",),
            "Run ./scripts/run-local-preview-smoke.sh and restore the zero-install process, build and launch contract.",
            timeout_seconds=600,
        ),
        Check(
            "app-server-adapter",
            ("./scripts/run-codex-app-server-adapter-smoke.sh",),
            "Run ./scripts/run-codex-app-server-adapter-smoke.sh and restore privacy-safe turn mapping without claiming whole-task completion.",
            timeout_seconds=600,
        ),
        Check(
            "event-spool-security",
            ("python3", "scripts/check-event-spool-integration.py"),
            "Run python3 scripts/check-event-spool-integration.py and restore the bounded no-follow local event inbox contract.",
        ),
        Check(
            "shared-day-lifecycle",
            ("python3", "scripts/check-shared-day-integration.py"),
            "Run python3 scripts/check-shared-day-integration.py and restore one bounded care/work lifecycle without media or private task content.",
        ),
        Check(
            "module-stewardship",
            ("python3", "scripts/audit-module-stewardship.py", "--audit", "--json"),
            "Run python3 scripts/audit-module-stewardship.py --audit --json and restore deterministic review routing.",
        ),
        Check(
            "core-boundaries",
            ("python3", "scripts/audit-core-module-boundaries.py", "--json"),
            "Run python3 scripts/audit-core-module-boundaries.py --json and move policy back behind the documented boundary.",
        ),
        Check(
            "swift-compiler-boundaries",
            ("python3", "scripts/audit-swift-compiler-boundaries.py", "--json"),
            "Run python3 scripts/audit-swift-compiler-boundaries.py --json and restore compiler-parsed imports and required public Core declarations.",
        ),
        Check(
            "relationship-runtime",
            ("python3", "scripts/check-relationship-runtime-integration.py"),
            "Run python3 scripts/check-relationship-runtime-integration.py and restore bounded relationship memory outside app composition.",
        ),
        Check(
            "gesture-discovery-runtime",
            ("./scripts/run-gesture-discovery-coordinator-smoke.sh",),
            "Run ./scripts/run-gesture-discovery-coordinator-smoke.sh and restore restart-safe capability-only gesture discovery with cancellable hints.",
            timeout_seconds=600,
        ),
        Check(
            "presentation-runtime",
            ("./scripts/run-presentation-runtime-coordinator-smoke.sh",),
            "Run ./scripts/run-presentation-runtime-coordinator-smoke.sh and restore unified click, palette, fallback and game-reward expansion/restoration.",
            timeout_seconds=600,
        ),
        Check(
            "microgame-window-policy",
            ("./scripts/run-microgame-window-policy-smoke.sh",),
            "Run ./scripts/run-microgame-window-policy-smoke.sh and restore selected-display catch targets, clickable hide peeks, no-repeat edges and malformed-geometry recovery.",
            timeout_seconds=600,
        ),
        Check(
            "pet-feedback-runtime",
            ("./scripts/run-pet-feedback-runtime-coordinator-smoke.sh",),
            "Run ./scripts/run-pet-feedback-runtime-coordinator-smoke.sh and restore generation-safe mood, pose and effect lifetimes.",
            timeout_seconds=600,
        ),
        Check(
            "content-library-runtime",
            ("./scripts/run-content-library-runtime-coordinator-smoke.sh",),
            "Run ./scripts/run-content-library-runtime-coordinator-smoke.sh and restore stale-safe inventory, recovery and playback-health ownership.",
            timeout_seconds=600,
        ),
        Check(
            "preference-store",
            ("./scripts/run-preference-store-smoke.sh",),
            "Run ./scripts/run-preference-store-smoke.sh and restore typed defaults, migration, malformed repair and retired-key cleanup outside App composition.",
            timeout_seconds=600,
        ),
        Check(
            "voice-selection-runtime",
            ("./scripts/run-voice-selection-runtime-smoke.sh",),
            "Run ./scripts/run-voice-selection-runtime-smoke.sh and restore bounded general/interaction voice history, addressed filtering, preferred-ID selection and cooldown outside App composition.",
            timeout_seconds=600,
        ),
        Check(
            "settings-backup-projection",
            ("./scripts/run-settings-backup-projection-smoke.sh",),
            "Run ./scripts/run-settings-backup-projection-smoke.sh and restore capability-free export, explicit repair receipts, privacy retirement and safe fallback outside App composition.",
            timeout_seconds=600,
        ),
        Check(
            "content-pack-store-modularity",
            ("python3", "scripts/check-content-pack-store-modularity.py"),
            "Run python3 scripts/check-content-pack-store-modularity.py and restore the reviewable transaction, model and durability boundaries.",
        ),
        Check(
            "content-pack-validator-modularity",
            ("python3", "scripts/check-content-pack-validator-modularity.py"),
            "Run python3 scripts/check-content-pack-validator-modularity.py and restore the raw-field, contribution and asset/filesystem capability boundaries.",
        ),
        Check(
            "swiftpm-package-graph",
            ("python3", "scripts/audit-swiftpm-package-graph.py", "--json"),
            "Run python3 scripts/audit-swiftpm-package-graph.py --json and restore the reviewed local package graph.",
        ),
        Check(
            "starter-inventory",
            ("python3", "scripts/refresh-starter-media-manifest.py", "--check"),
            "Run python3 scripts/refresh-starter-media-manifest.py --check; review changed Starter metadata before writing it.",
        ),
        Check(
            "starter-audit",
            ("python3", "scripts/audit-starter-media.py", "--json"),
            "Run python3 scripts/audit-starter-media.py --json and restore exact Starter inventory or review state.",
        ),
        Check(
            "community-index",
            (
                "python3",
                "scripts/audit-community-pack-index.py",
                "community/index.json",
                "--json",
            ),
            "Run python3 scripts/audit-community-pack-index.py community/index.json --json and repair the reviewed manifest binding.",
        ),
        Check(
            "canonical-experience-pack",
            ("python3", "scripts/check-example-experience-pack.py"),
            "Run python3 scripts/check-example-experience-pack.py and restore the complete executable-free v2 learning example.",
        ),
        Check(
            "first-use-low-impact",
            ("./scripts/run-first-use-low-impact-audit.sh", "--zero-authorization"),
            "Run ./scripts/run-first-use-low-impact-audit.sh --zero-authorization and restore the local fallback path.",
        ),
        Check(
            "release-boundary",
            ("./scripts/run-release-readiness-smoke.sh",),
            "Run ./scripts/run-release-readiness-smoke.sh and keep every owner-controlled release gate explicit.",
        ),
    ]


def pack_checks(pack_path: pathlib.Path, preview_path: pathlib.Path) -> list[Check]:
    pack_argument = str(pack_path)
    return [
        Check(
            "pack-validate",
            ("./scripts/validate-content-pack.sh", pack_argument, "--json"),
            "Run ./scripts/validate-content-pack.sh <pack-directory> --json and repair the first validation failure.",
            timeout_seconds=600,
        ),
        Check(
            "pack-strict-audit",
            ("./scripts/audit-content-pack.sh", pack_argument, "--strict", "--json"),
            "Run ./scripts/audit-content-pack.sh <pack-directory> --strict --json and complete factual rights, accessibility and fallback evidence.",
            timeout_seconds=600,
            depends_on_previous=True,
        ),
        Check(
            "pack-locale-matrix",
            ("./scripts/audit-content-pack-locales.sh", pack_argument, "--json"),
            "Run ./scripts/audit-content-pack-locales.sh <pack-directory> --json and review media eligibility and accessibility fallback warnings.",
            timeout_seconds=600,
            depends_on_previous=True,
        ),
        Check(
            "pack-offline-preview",
            (
                "./scripts/preview-content-pack.sh",
                pack_argument,
                "--output",
                str(preview_path),
                "--no-open",
            ),
            "Run ./scripts/preview-content-pack.sh <pack-directory> --no-open and repair the local preview failure.",
            timeout_seconds=600,
            depends_on_previous=True,
            expected_artifact=preview_path,
        ),
    ]


def receipt(
    *,
    status: str,
    profile: str,
    checks: list[dict[str, object]],
    code: Optional[str],
    message: str,
    recovery_action: Optional[str],
) -> dict[str, object]:
    return {
        "schemaVersion": SCHEMA_VERSION,
        "status": status,
        "profile": profile if profile in SUPPORTED_PROFILES else "unknown",
        "networkRequired": False,
        "authoritativeSourceMutation": False,
        "releaseState": RELEASE_STATE,
        "passedCount": sum(item["status"] == "PASS" for item in checks),
        "failedCount": sum(item["status"] == "FAIL" for item in checks),
        "skippedCount": sum(item["status"] == "SKIP" for item in checks),
        "checks": checks,
        "code": code,
        "message": message,
        "recoveryAction": recovery_action,
    }


def emit(data: dict[str, object], json_mode: bool) -> int:
    if json_mode:
        print(json.dumps(data, ensure_ascii=False, sort_keys=True))
    elif data["status"] == "PASS":
        print(
            "Contributor check: PASS "
            f"({data['profile']}, {data['passedCount']}/{len(data['checks'])})"
        )
        print(f"Release state: {RELEASE_STATE}")
    else:
        print(f"FAIL  [{data['code']}] {data['message']}", file=sys.stderr)
        if data["recoveryAction"]:
            print(f"ACTION  {data['recoveryAction']}", file=sys.stderr)
    return 0 if data["status"] == "PASS" else 1


def argument_failure(
    code: str,
    message: str,
    action: str,
    profile: str,
    json_mode: bool,
) -> int:
    return emit(
        receipt(
            status="FAIL",
            profile=profile,
            checks=[],
            code=code,
            message=message,
            recovery_action=action,
        ),
        json_mode,
    )


def parse_arguments(
    argv: list[str],
) -> Union[tuple[str, Optional[pathlib.Path], bool], int]:
    profile = "quick"
    pack_path: Optional[pathlib.Path] = None
    json_mode = "--json" in argv
    index = 0
    while index < len(argv):
        argument = argv[index]
        if argument == "--json":
            index += 1
        elif argument == "--profile":
            if index + 1 >= len(argv):
                return argument_failure(
                    "CONTRIBUTOR_CHECK_INVALID_ARGUMENT",
                    "The contributor-check profile value is missing.",
                    "Use --profile quick, full or pack, then retry.",
                    profile,
                    json_mode,
                )
            profile = argv[index + 1]
            index += 2
        elif argument == "--pack":
            if index + 1 >= len(argv):
                return argument_failure(
                    "CONTRIBUTOR_CHECK_INVALID_ARGUMENT",
                    "The contributor-check pack value is missing.",
                    "Provide --pack followed by a local content-pack directory.",
                    profile,
                    json_mode,
                )
            pack_path = pathlib.Path(argv[index + 1])
            index += 2
        elif argument in {"--help", "-h"}:
            print(
                "Usage: ./scripts/check-contribution.py "
                "[--profile quick|full|pack] [--pack <directory>] [--json]"
            )
            return 0
        else:
            return argument_failure(
                "CONTRIBUTOR_CHECK_INVALID_ARGUMENT",
                "The contributor-check command received an unknown option.",
                "Run ./scripts/check-contribution.py --help, correct the command, then retry.",
                profile,
                json_mode,
            )
    if profile not in SUPPORTED_PROFILES:
        return argument_failure(
            "CONTRIBUTOR_CHECK_INVALID_ARGUMENT",
            "The requested contributor-check profile is unsupported.",
            "Use --profile quick, full or pack, then retry.",
            profile,
            json_mode,
        )
    if profile == "pack" and pack_path is None:
        return argument_failure(
            "CONTRIBUTOR_CHECK_PACK_REQUIRED",
            "The pack contribution profile requires one local pack directory.",
            "Add --pack <pack-directory>, then retry the pack profile.",
            profile,
            json_mode,
        )
    if profile != "pack" and pack_path is not None:
        return argument_failure(
            "CONTRIBUTOR_CHECK_INVALID_ARGUMENT",
            "The --pack option is only valid with the pack profile.",
            "Remove --pack or select --profile pack, then retry.",
            profile,
            json_mode,
        )
    return profile, pack_path, json_mode


def run_checks(
    project_root: pathlib.Path,
    profile: str,
    pack_path: Optional[pathlib.Path],
    temporary_root: pathlib.Path,
) -> list[dict[str, object]]:
    if profile == "pack":
        assert pack_path is not None
        checks = pack_checks(pack_path, temporary_root / "pack-preview.html")
    else:
        checks = quick_checks()
        if profile == "full":
            checks.append(
                Check(
                    "portable-clone-build-contribute",
                    ("./scripts/run-portable-source-smoke.sh",),
                    "Run ./scripts/run-portable-source-smoke.sh and repair the first isolated clone/build/contribute failure.",
                    timeout_seconds=3600,
                    depends_on_previous=True,
                )
            )

    environment = os.environ.copy()
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    environment["TMPDIR"] = str(temporary_root)
    environment["CHENGYIN_CREATOR_CACHE_ROOT"] = str(
        temporary_root / "creator-cache"
    )
    results: list[dict[str, object]] = []
    dependency_failed = False
    for check in checks:
        if check.depends_on_previous and dependency_failed:
            results.append(
                {
                    "id": check.identifier,
                    "status": "SKIP",
                    "recoveryAction": check.recovery_action,
                }
            )
            continue
        log_path = temporary_root / f"{check.identifier}.log"
        try:
            with log_path.open("wb") as log:
                completed = subprocess.run(
                    check.command,
                    cwd=project_root,
                    env=environment,
                    stdin=subprocess.DEVNULL,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    timeout=check.timeout_seconds,
                    check=False,
                )
            passed = completed.returncode == 0
            if passed and check.expected_artifact is not None:
                passed = (
                    check.expected_artifact.is_file()
                    and not check.expected_artifact.is_symlink()
                    and check.expected_artifact.stat().st_size > 0
                )
        except (OSError, subprocess.SubprocessError):
            passed = False
        results.append(
            {
                "id": check.identifier,
                "status": "PASS" if passed else "FAIL",
                "recoveryAction": None if passed else check.recovery_action,
            }
        )
        if not passed:
            dependency_failed = True
    return results


def main(argv: list[str]) -> int:
    parsed = parse_arguments(argv)
    if isinstance(parsed, int):
        return parsed
    profile, pack_path, json_mode = parsed
    project_root = pathlib.Path(__file__).resolve().parent.parent
    required = [
        project_root / "Package.swift",
        project_root / "AGENTS.md",
        project_root / "Schemas/contributor-check-receipt-v1.schema.json",
        project_root / "Schemas/all-game-rewards-v1.schema.json",
    ]
    if any(not path.is_file() or path.is_symlink() for path in required):
        return argument_failure(
            "CONTRIBUTOR_CHECK_SOURCE_MISSING",
            "The contributor gate is not running from a complete trusted checkout.",
            "Restore Package.swift, AGENTS.md and the contributor receipt schema, then retry.",
            profile,
            json_mode,
        )
    if pack_path is not None:
        if pack_path.is_symlink():
            return argument_failure(
                "CONTRIBUTOR_CHECK_PACK_REQUIRED",
                "The selected content-pack input is not a trusted regular directory.",
                "Choose a regular local content-pack directory and retry.",
                profile,
                json_mode,
            )
        try:
            pack_path = pack_path.resolve(strict=True)
        except OSError:
            return argument_failure(
                "CONTRIBUTOR_CHECK_PACK_REQUIRED",
                "The selected content-pack directory is missing or unavailable.",
                "Choose a regular local content-pack directory and retry.",
                profile,
                json_mode,
            )
        if not pack_path.is_dir() or pack_path.is_symlink():
            return argument_failure(
                "CONTRIBUTOR_CHECK_PACK_REQUIRED",
                "The selected content-pack input is not a trusted regular directory.",
                "Choose a regular local content-pack directory and retry.",
                profile,
                json_mode,
            )
    try:
        with tempfile.TemporaryDirectory(prefix="chengyin-contributor-check-") as raw:
            results = run_checks(
                project_root,
                profile,
                pack_path,
                pathlib.Path(raw),
            )
    except Exception:
        return argument_failure(
            "CONTRIBUTOR_CHECK_UNEXPECTED_ERROR",
            "The contributor gate stopped at a privacy-safe fallback boundary.",
            "Retry once; if it repeats, run the profile's documented checks individually.",
            profile,
            json_mode,
        )
    failures = [item for item in results if item["status"] == "FAIL"]
    if failures:
        first = failures[0]
        return emit(
            receipt(
                status="FAIL",
                profile=profile,
                checks=results,
                code="CONTRIBUTOR_CHECK_FAILED",
                message=f"Contributor check failed at the stable check ID: {first['id']}.",
                recovery_action=str(first["recoveryAction"]),
            ),
            json_mode,
        )
    return emit(
        receipt(
            status="PASS",
            profile=profile,
            checks=results,
            code=None,
            message="The selected local contribution profile passed.",
            recovery_action=None,
        ),
        json_mode,
    )


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
