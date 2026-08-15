#!/usr/bin/env python3
"""Offline, privacy-safe auditor for Chengyin's reviewed manifest index."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import stat
import subprocess
import sys
from dataclasses import dataclass
from typing import NoReturn


PROJECT_ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_INDEX = PROJECT_ROOT / "community/index.json"
MAX_INDEX_BYTES = 512 * 1024
MAX_MANIFEST_BYTES = 512 * 1024
MAX_ENTRIES = 64
ID_PATTERN = re.compile(r"^[a-z0-9]+(?:[.-][a-z0-9]+)+$")
SEMVER_PATTERN = re.compile(
    r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$"
)
SHA_PATTERN = re.compile(r"^[a-f0-9]{64}$")
REVIEWER_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]{0,127}$")
TOP_FIELDS = {"schemaVersion", "indexID", "version", "entries"}
ENTRY_FIELDS = {"packID", "version", "packPath", "manifestSHA256", "review"}
REVIEW_FIELDS = {"status", "version", "reviewerID", "reviewedManifestSHA256"}
REVIEW_STATUSES = {"draft", "pending", "approved", "rejected"}


@dataclass(frozen=True)
class AuditFailure(Exception):
    code: str
    message: str
    recovery_action: str
    entry_id: str | None = None


def fail(
    code: str,
    message: str,
    recovery_action: str,
    entry_id: str | None = None,
) -> NoReturn:
    raise AuditFailure(code, message, recovery_action, entry_id)


def exact_fields(
    value: object,
    expected: set[str],
    label: str,
    entry_id: str | None = None,
) -> dict[str, object]:
    if not isinstance(value, dict):
        fail(
            "COMMUNITY_INDEX_INVALID_METADATA",
            f"{label} must be an object.",
            "Correct the index metadata and rerun the offline community-index audit.",
            entry_id,
        )
    unknown = sorted(set(value) - expected)
    missing = sorted(expected - set(value))
    if unknown:
        fail(
            "COMMUNITY_INDEX_UNKNOWN_FIELD",
            f"{label} contains unsupported fields: {', '.join(unknown)}.",
            "Remove unknown fields or update the documented index schema version.",
            entry_id,
        )
    if missing:
        fail(
            "COMMUNITY_INDEX_INVALID_METADATA",
            f"{label} is missing required fields: {', '.join(missing)}.",
            "Add every required field from community-pack-index-v1.schema.json.",
            entry_id,
        )
    return value


def regular_file_bytes(
    path: pathlib.Path,
    maximum: int,
    missing_code: str,
    too_large_code: str,
    label: str,
    entry_id: str | None = None,
) -> bytes:
    try:
        metadata = path.lstat()
    except OSError:
        fail(
            missing_code,
            f"{label} is missing or unreadable.",
            f"Restore the declared {label.lower()} and rerun the audit.",
            entry_id,
        )
    if stat.S_ISLNK(metadata.st_mode):
        fail(
            "COMMUNITY_INDEX_SYMLINK",
            f"{label} must not be a symbolic link.",
            "Replace the link with a regular repository file or directory.",
            entry_id,
        )
    if not stat.S_ISREG(metadata.st_mode):
        fail(
            missing_code,
            f"{label} is not a regular file.",
            f"Restore the declared {label.lower()} as a regular file.",
            entry_id,
        )
    if metadata.st_size > maximum:
        fail(
            too_large_code,
            f"{label} exceeds the bounded audit size.",
            f"Reduce the {label.lower()} size and rerun the audit.",
            entry_id,
        )
    try:
        return path.read_bytes()
    except OSError:
        fail(
            missing_code,
            f"{label} could not be read.",
            f"Restore readable permissions for the declared {label.lower()}.",
            entry_id,
        )


def safe_pack_directory(root: pathlib.Path, relative: object, entry_id: str) -> pathlib.Path:
    if not isinstance(relative, str) or not relative or len(relative) > 512:
        fail(
            "COMMUNITY_INDEX_UNSAFE_PATH",
            "The indexed pack path is invalid.",
            "Use a bounded repository-relative pack directory without private paths.",
            entry_id,
        )
    if "\\" in relative or "\x00" in relative or relative.startswith(("/", "~")):
        fail(
            "COMMUNITY_INDEX_UNSAFE_PATH",
            "The indexed pack path is not a safe repository-relative path.",
            "Remove absolute, home-relative, backslash, or private path syntax.",
            entry_id,
        )
    parts = pathlib.PurePosixPath(relative).parts
    if not parts or any(part in {"", ".", ".."} or part.startswith(".") for part in parts):
        fail(
            "COMMUNITY_INDEX_UNSAFE_PATH",
            "The indexed pack path contains traversal or hidden components.",
            "Use a visible repository-relative directory with no dot components.",
            entry_id,
        )

    cursor = root
    for part in parts:
        cursor = cursor / part
        try:
            mode = cursor.lstat().st_mode
        except OSError:
            fail(
                "COMMUNITY_INDEX_MANIFEST_MISSING",
                "The indexed pack directory is missing or unreadable.",
                "Restore the reviewed pack directory before publishing the index.",
                entry_id,
            )
        if stat.S_ISLNK(mode):
            fail(
                "COMMUNITY_INDEX_SYMLINK",
                "The indexed pack path crosses a symbolic link.",
                "Replace linked components with regular repository directories.",
                entry_id,
            )
    try:
        candidate = cursor.resolve(strict=True)
        candidate.relative_to(root)
    except (OSError, ValueError):
        fail(
            "COMMUNITY_INDEX_UNSAFE_PATH",
            "The indexed pack path escapes the selected repository root.",
            "Move the pack under the repository root and use a safe relative path.",
            entry_id,
        )
    if not candidate.is_dir():
        fail(
            "COMMUNITY_INDEX_MANIFEST_MISSING",
            "The indexed pack path is not a directory.",
            "Restore the reviewed pack directory and manifest.",
            entry_id,
        )
    return candidate


def validate_string(
    value: object,
    pattern: re.Pattern[str],
    code: str,
    label: str,
    entry_id: str | None = None,
    maximum: int = 128,
) -> str:
    if not isinstance(value, str) or len(value) > maximum or pattern.fullmatch(value) is None:
        fail(
            code,
            f"{label} is invalid.",
            "Correct the index identity and version metadata, then rerun the audit.",
            entry_id,
        )
    return value


def authoritative_pack_audit(pack_directory: pathlib.Path, entry_id: str) -> dict[str, object]:
    command = [
        str(PROJECT_ROOT / "scripts/audit-content-pack.sh"),
        str(pack_directory),
        "--strict",
        "--json",
    ]
    try:
        completed = subprocess.run(
            command,
            cwd=PROJECT_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=180,
            check=False,
            env=os.environ.copy(),
        )
    except (OSError, subprocess.TimeoutExpired):
        fail(
            "COMMUNITY_INDEX_UNEXPECTED_ERROR",
            "The authoritative content-pack audit could not complete.",
            "Run scripts/audit-content-pack.sh for the pack, repair the local toolchain, and retry.",
            entry_id,
        )
    try:
        receipt = json.loads(completed.stdout)
    except (json.JSONDecodeError, TypeError):
        fail(
            "COMMUNITY_INDEX_UNEXPECTED_ERROR",
            "The authoritative content-pack audit returned no valid receipt.",
            "Run the content-pack audit directly and repair the reported toolchain problem.",
            entry_id,
        )
    if completed.returncode != 0:
        fail(
            "COMMUNITY_INDEX_PACK_NOT_READY",
            "The indexed pack did not pass strict contribution audit.",
            "Complete rights, accessibility, fallback, media and review evidence, then rerun the strict pack audit.",
            entry_id,
        )
    if not (
        receipt.get("status") == "PASS"
        and receipt.get("qualityCandidate") == "READY_FOR_LAB"
        and receipt.get("contributionReady") is True
        and receipt.get("contributionMode") == "strict-v2"
        and receipt.get("packageReviewStatus") == "approved"
        and receipt.get("mediaValidationBackend")
        in {
            "avfoundation",
            "avfoundation+fixed-ffmpeg-full-software-decode",
        }
    ):
        fail(
            "COMMUNITY_INDEX_PACK_NOT_READY",
            "The indexed pack is valid but not an approved strict-v2 contribution.",
            "Finish strict-v2 evidence and approvals before adding the pack to the reviewed index.",
            entry_id,
        )
    return receipt


def audit(index_path: pathlib.Path, repository_root: pathlib.Path) -> dict[str, object]:
    try:
        root = repository_root.resolve(strict=True)
    except OSError:
        fail(
            "COMMUNITY_INDEX_INVALID_ARGUMENT",
            "The selected repository root is unavailable.",
            "Choose an existing repository root and rerun the audit.",
        )
    if not root.is_dir():
        fail(
            "COMMUNITY_INDEX_INVALID_ARGUMENT",
            "The selected repository root is not a directory.",
            "Choose the Chengyin repository root and rerun the audit.",
        )

    payload = regular_file_bytes(
        index_path,
        MAX_INDEX_BYTES,
        "COMMUNITY_INDEX_FILE_MISSING",
        "COMMUNITY_INDEX_PAYLOAD_TOO_LARGE",
        "Community index",
    )
    try:
        raw = json.loads(payload)
    except (json.JSONDecodeError, UnicodeDecodeError):
        fail(
            "COMMUNITY_INDEX_INVALID_JSON",
            "The community index is not valid UTF-8 JSON.",
            "Correct community/index.json and rerun the offline audit.",
        )
    document = exact_fields(raw, TOP_FIELDS, "Community index")
    if document["schemaVersion"] != 1:
        fail(
            "COMMUNITY_INDEX_UNSUPPORTED_SCHEMA",
            "The community index schema version is unsupported.",
            "Migrate the index to schemaVersion 1 or use a compatible auditor.",
        )
    index_id = validate_string(
        document["indexID"],
        ID_PATTERN,
        "COMMUNITY_INDEX_INVALID_METADATA",
        "Index ID",
    )
    version = validate_string(
        document["version"],
        SEMVER_PATTERN,
        "COMMUNITY_INDEX_INVALID_METADATA",
        "Index version",
    )
    entries = document["entries"]
    if not isinstance(entries, list):
        fail(
            "COMMUNITY_INDEX_INVALID_METADATA",
            "Index entries must be an array.",
            "Replace entries with the bounded array defined by the v1 schema.",
        )
    if len(entries) > MAX_ENTRIES:
        fail(
            "COMMUNITY_INDEX_TOO_MANY_ENTRIES",
            "The community index exceeds the entry limit.",
            "Split review work and keep at most 64 approved entries in this index version.",
        )

    seen: set[str] = set()
    approved: list[dict[str, object]] = []
    for offset, raw_entry in enumerate(entries):
        preliminary_id = raw_entry.get("packID") if isinstance(raw_entry, dict) else None
        safe_entry_id = preliminary_id if isinstance(preliminary_id, str) and ID_PATTERN.fullmatch(preliminary_id) else None
        entry = exact_fields(raw_entry, ENTRY_FIELDS, f"Entry {offset}", safe_entry_id)
        pack_id = validate_string(
            entry["packID"],
            ID_PATTERN,
            "COMMUNITY_INDEX_INVALID_METADATA",
            "Pack ID",
            safe_entry_id,
        )
        pack_version = validate_string(
            entry["version"],
            SEMVER_PATTERN,
            "COMMUNITY_INDEX_INVALID_METADATA",
            "Pack version",
            pack_id,
        )
        if pack_id in seen:
            fail(
                "COMMUNITY_INDEX_DUPLICATE_ENTRY",
                "The community index contains the same pack more than once.",
                "Keep exactly one reviewed version per pack ID in an index revision.",
                pack_id,
            )
        seen.add(pack_id)
        manifest_hash = validate_string(
            entry["manifestSHA256"],
            SHA_PATTERN,
            "COMMUNITY_INDEX_INVALID_METADATA",
            "Manifest SHA-256",
            pack_id,
            maximum=64,
        )
        review = exact_fields(entry["review"], REVIEW_FIELDS, "Index review", pack_id)
        review_status = review["status"]
        if review_status not in REVIEW_STATUSES:
            fail(
                "COMMUNITY_INDEX_INVALID_METADATA",
                "The index review status is invalid.",
                "Use draft, pending, approved or rejected review status.",
                pack_id,
            )
        if review_status != "approved":
            fail(
                "COMMUNITY_INDEX_REVIEW_NOT_APPROVED",
                "The index entry review is not approved.",
                "Keep draft, pending or rejected entries outside the published reviewed index.",
                pack_id,
            )
        if not isinstance(review["version"], int) or isinstance(review["version"], bool) or review["version"] < 1:
            fail(
                "COMMUNITY_INDEX_INVALID_METADATA",
                "The index review version is invalid.",
                "Use a positive integer and increment it when review evidence changes.",
                pack_id,
            )
        reviewer_id = validate_string(
            review["reviewerID"],
            REVIEWER_PATTERN,
            "COMMUNITY_INDEX_INVALID_METADATA",
            "Reviewer ID",
            pack_id,
        )
        reviewed_hash = validate_string(
            review["reviewedManifestSHA256"],
            SHA_PATTERN,
            "COMMUNITY_INDEX_INVALID_METADATA",
            "Reviewed manifest SHA-256",
            pack_id,
            maximum=64,
        )
        if reviewed_hash != manifest_hash:
            fail(
                "COMMUNITY_INDEX_REVIEW_HASH_MISMATCH",
                "The review is not bound to the indexed manifest hash.",
                "Repeat review against the exact manifest and update both matching hashes.",
                pack_id,
            )

        pack_directory = safe_pack_directory(root, entry["packPath"], pack_id)
        manifest_path = pack_directory / "manifest.json"
        manifest_payload = regular_file_bytes(
            manifest_path,
            MAX_MANIFEST_BYTES,
            "COMMUNITY_INDEX_MANIFEST_MISSING",
            "COMMUNITY_INDEX_PAYLOAD_TOO_LARGE",
            "Reviewed manifest",
            pack_id,
        )
        actual_hash = hashlib.sha256(manifest_payload).hexdigest()
        if actual_hash != manifest_hash:
            fail(
                "COMMUNITY_INDEX_MANIFEST_HASH_MISMATCH",
                "The indexed manifest hash does not match the reviewed file.",
                "Re-audit the exact manifest and update the index only after review approval.",
                pack_id,
            )
        try:
            manifest = json.loads(manifest_payload)
        except (json.JSONDecodeError, UnicodeDecodeError):
            fail(
                "COMMUNITY_INDEX_PACK_NOT_READY",
                "The reviewed manifest is not valid JSON.",
                "Repair the content pack and pass strict validation before indexing it.",
                pack_id,
            )
        if not isinstance(manifest, dict) or manifest.get("id") != pack_id or manifest.get("version") != pack_version:
            fail(
                "COMMUNITY_INDEX_IDENTITY_MISMATCH",
                "Index identity does not match the reviewed manifest.",
                "Use the exact pack ID and version declared by the reviewed manifest.",
                pack_id,
            )

        receipt = authoritative_pack_audit(pack_directory, pack_id)
        if receipt.get("packID") != pack_id or receipt.get("version") != pack_version:
            fail(
                "COMMUNITY_INDEX_IDENTITY_MISMATCH",
                "The authoritative audit identity differs from the index entry.",
                "Rebuild the entry from the exact strict-v2 audit receipt.",
                pack_id,
            )
        approved.append(
            {
                "packID": pack_id,
                "version": pack_version,
                "manifestSHA256": manifest_hash,
                "reviewerID": reviewer_id,
                "reviewVersion": review["version"],
                "qualityCandidate": "READY_FOR_LAB",
                "mediaValidationBackend": receipt["mediaValidationBackend"],
            }
        )

    return {
        "status": "PASS",
        "schemaVersion": 1,
        "indexID": index_id,
        "version": version,
        "entryCount": len(approved),
        "entries": approved,
        "networkUsed": False,
        "executablePluginsAllowed": False,
    }


def failure_receipt(error: AuditFailure) -> dict[str, object]:
    receipt: dict[str, object] = {
        "status": "FAIL",
        "code": error.code,
        "message": error.message,
        "recoveryAction": error.recovery_action,
    }
    if error.entry_id is not None:
        receipt["entryID"] = error.entry_id
    return receipt


def render(receipt: dict[str, object], emits_json: bool) -> None:
    if emits_json:
        print(json.dumps(receipt, ensure_ascii=False, indent=2, sort_keys=True))
        return
    if receipt["status"] == "PASS":
        print(f"PASS  reviewed community index: {receipt['entryCount']} entries")
        print("      offline only; executable plugins are not allowed")
        return
    print(f"FAIL  [{receipt['code']}] {receipt['message']}")
    print(f"ACTION {receipt['recoveryAction']}")


def parse_arguments() -> argparse.Namespace:
    class SafeArgumentParser(argparse.ArgumentParser):
        def error(self, message: str) -> NoReturn:
            fail(
                "COMMUNITY_INDEX_INVALID_ARGUMENT",
                "The community-index command arguments are invalid.",
                "Use audit-community-pack-index.py [index] [--json] and retry.",
            )

    parser = SafeArgumentParser(
        description="Audit a reviewed Chengyin community pack index without network access."
    )
    parser.add_argument("index", nargs="?", default=str(DEFAULT_INDEX))
    parser.add_argument("--root", default=str(PROJECT_ROOT), help=argparse.SUPPRESS)
    parser.add_argument("--json", action="store_true")
    return parser.parse_args()


def main() -> int:
    emits_json = "--json" in sys.argv[1:]
    try:
        arguments = parse_arguments()
        receipt = audit(pathlib.Path(arguments.index), pathlib.Path(arguments.root))
    except AuditFailure as error:
        receipt = failure_receipt(error)
        render(receipt, emits_json)
        return 1
    except Exception:
        receipt = failure_receipt(
            AuditFailure(
                "COMMUNITY_INDEX_UNEXPECTED_ERROR",
                "The community index audit failed unexpectedly.",
                "Rerun the audit; if it repeats, attach this code and a privacy-minimal diagnostic to an Issue.",
            )
        )
        render(receipt, emits_json)
        return 1
    render(receipt, arguments.json)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
