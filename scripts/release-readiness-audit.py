#!/usr/bin/env python3
"""Report release states without upgrading a local preview into a release claim."""

from __future__ import annotations

import argparse
import json
import plistlib
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "dist" / "Chengyin Companion.app"
GATES = ROOT / "release" / "release-gates.json"
STARTER_AUDITOR = ROOT / "scripts" / "audit-starter-media.py"
STARTER_RESOURCES = ROOT / "Sources" / "CompanionApp" / "Resources"

EXPECTED_ROOT_KEYS = {
    "schemaVersion",
    "mediaRights",
    "finalLicense",
    "developerID",
    "notarization",
    "ownerReleaseApproval",
}
EXPECTED_GATE_KEYS = {"status", "evidenceRefs"}
ALLOWED_STATUSES = {
    "mediaRights": {"pending", "passed", "rejected"},
    "finalLicense": {"pending-owner-decision", "approved", "rejected"},
    "developerID": {"not-configured", "configured", "revoked"},
    "notarization": {"not-submitted", "accepted", "rejected"},
    "ownerReleaseApproval": {"not-granted", "granted", "withdrawn"},
}


def load_gates() -> dict:
    data = json.loads(GATES.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or set(data) != EXPECTED_ROOT_KEYS:
        raise ValueError("release gate registry has missing or unknown fields")
    if data.get("schemaVersion") != 1:
        raise ValueError("unsupported release gate schema")
    for key, allowed in ALLOWED_STATUSES.items():
        value = data.get(key)
        if not isinstance(value, dict) or set(value) != EXPECTED_GATE_KEYS:
            raise ValueError(f"invalid {key} gate shape")
        if value.get("status") not in allowed:
            raise ValueError(f"invalid {key} gate status")
        refs = value.get("evidenceRefs")
        if not isinstance(refs, list) or len(refs) > 32:
            raise ValueError(f"invalid {key} evidence references")
        if not all(isinstance(ref, str) and 0 < len(ref) <= 160 for ref in refs):
            raise ValueError(f"invalid {key} evidence reference")
    return data


def engineering_installable() -> bool:
    return all(
        path.exists()
        for path in (
            APP / "Contents" / "Info.plist",
            APP / "Contents" / "MacOS" / "ChengyinCompanion",
            APP / "Contents" / "SharedSupport" / "CompanionEventEmitter",
        )
    )


def valid_local_preview() -> bool:
    if not engineering_installable():
        return False
    result = subprocess.run(
        ["codesign", "--verify", "--deep", "--strict", str(APP)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def developer_id_signed() -> bool:
    if not engineering_installable():
        return False
    result = subprocess.run(
        ["codesign", "-dv", "--verbose=4", str(APP)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    return result.returncode == 0 and "Authority=Developer ID Application:" in result.stderr


def read_build_identity() -> str | None:
    plist_path = APP / "Contents" / "Info.plist"
    if not plist_path.is_file():
        return None
    try:
        with plist_path.open("rb") as stream:
            value = plistlib.load(stream).get("ChengyinBuildIdentity")
        return value if isinstance(value, str) and len(value) <= 120 else None
    except (OSError, plistlib.InvalidFileException):
        return None


def starter_media_contract() -> dict:
    command = [
        sys.executable,
        str(STARTER_AUDITOR),
        "--resources",
        str(STARTER_RESOURCES),
        "--json",
    ]
    packaged_resources = APP / "Contents" / "Resources"
    if packaged_resources.is_dir():
        command.extend(["--bundle", str(packaged_resources)])
    result = subprocess.run(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return {
            "status": "FAIL",
            "assetCount": 0,
            "rightsApprovedAssetCount": 0,
            "accessibilityApprovedAssetCount": 0,
            "licenseApproved": False,
            "publicDistributionReady": False,
        }
    try:
        receipt = json.loads(result.stdout)
    except json.JSONDecodeError:
        return {
            "status": "FAIL",
            "assetCount": 0,
            "rightsApprovedAssetCount": 0,
            "accessibilityApprovedAssetCount": 0,
            "licenseApproved": False,
            "publicDistributionReady": False,
        }
    safe_keys = {
        "status",
        "assetCount",
        "rightsApprovedAssetCount",
        "accessibilityApprovedAssetCount",
        "licenseApproved",
        "publicDistributionReady",
        "distributionState",
    }
    return {key: receipt[key] for key in safe_keys if key in receipt}


def build_receipt(gates: dict) -> dict:
    installable = engineering_installable()
    preview = valid_local_preview()
    developer_signed = (
        gates["developerID"]["status"] == "configured"
        and developer_id_signed()
    )
    starter_contract = starter_media_contract()
    state = {
        "engineeringInstallable": installable,
        "personalPreview": preview,
        "mediaRightsPassed": (
            gates["mediaRights"]["status"] == "passed"
            and starter_contract.get("publicDistributionReady") is True
        ),
        "finalLicenseApproved": gates["finalLicense"]["status"] == "approved",
        "developerIDSigned": developer_signed,
        "notarized": gates["notarization"]["status"] == "accepted",
        "ownerReleaseApprovalGranted": (
            gates["ownerReleaseApproval"]["status"] == "granted"
        ),
    }
    public_ready = all(state.values())
    blockers = [key for key, passed in state.items() if not passed]
    return {
        "schemaVersion": "chengyin.release-readiness/v1",
        "status": "PUBLIC_RELEASE_READY" if public_ready else "NOT_PUBLIC_RELEASE_READY",
        "buildIdentity": read_build_identity(),
        "states": state,
        "starterMediaContract": starter_contract,
        "blockingGates": blockers,
        "publicReleaseReady": public_ready,
        "ownerActionRequired": not public_ready,
        "safeSummary": (
            "All public release gates passed."
            if public_ready
            else "Engineering and preview states do not imply public release readiness."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    try:
        receipt = build_receipt(load_gates())
    except (OSError, ValueError, json.JSONDecodeError) as error:
        safe = {
            "schemaVersion": "chengyin.release-readiness/v1",
            "status": "AUDIT_INVALID",
            "safeSummary": "Release gate registry is invalid.",
            "recoveryAction": "Restore release/release-gates.json from the repository and rerun the audit.",
        }
        print(json.dumps(safe, ensure_ascii=False, sort_keys=True))
        return 2

    if args.json:
        print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
    else:
        print(receipt["status"])
        for key, passed in receipt["states"].items():
            print(f"{'PASS' if passed else 'PENDING'}  {key}")
        print(receipt["safeSummary"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
