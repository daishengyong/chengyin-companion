#!/usr/bin/env python3
"""Bounded, offline credential-leak audit for Chengyin's public source scope.

This is a release hygiene guard, not a malware scanner or proof that a secret
never exists. It reads no environment values and never scans outside the
portable-source allowlist rooted at the selected directory.
"""

from __future__ import annotations

import hashlib
import json
import os
import pathlib
import re
import sys
from dataclasses import dataclass
from typing import Iterable, Optional


CONTRACT = "chengyin.public-source-secret-audit/v1"
RELEASE_STATE = "NOT_PUBLIC_RELEASE_READY"
MAX_FILES = 4096
MAX_TEXT_FILE_BYTES = 2 * 1024 * 1024
MAX_TEXT_BYTES = 64 * 1024 * 1024
MAX_FINDINGS = 64

ROOT_FILES = (
    ".gitignore",
    "AGENTS.md",
    "CODE_OF_CONDUCT.md",
    "CODE_OF_CONDUCT.zh-Hans.md",
    "CONTRIBUTING.md",
    "CONTRIBUTING.en.md",
    "GOVERNANCE.md",
    "GOVERNANCE.zh-Hans.md",
    "Info.plist",
    "Package.swift",
    "README.md",
    "README.en.md",
    "ROADMAP.md",
    "ROADMAP.zh-Hans.md",
    "SECURITY.md",
    "SECURITY.en.md",
    "SUPPORT.md",
    "SUPPORT.zh-Hans.md",
)
ROOT_DIRECTORIES = (
    ".github",
    "Schemas",
    "Skills",
    "Sources",
    "Tests",
    "Tools",
    "community",
    "docs",
    "examples",
    "packaging",
    "scripts",
)
PRIVATE_ROOTS = frozenset(
    {
        ".agents",
        ".ai-bridge",
        ".build",
        ".codex",
        ".git",
        ".swiftpm",
        "DerivedData",
        "dist",
        "generated",
        "local-entitlements",
        "pack-staging",
        "video-production",
    }
)
BINARY_SUFFIXES = frozenset(
    {
        ".aac",
        ".aiff",
        ".app",
        ".caf",
        ".chengyinpack",
        ".dmg",
        ".gif",
        ".heic",
        ".icns",
        ".jpeg",
        ".jpg",
        ".m4a",
        ".mov",
        ".mp3",
        ".mp4",
        ".pdf",
        ".png",
        ".wav",
        ".webp",
        ".zip",
    }
)
HIGH_RISK_NAMES = frozenset(
    {
        ".env",
        ".npmrc",
        ".pypirc",
        "credentials.json",
        "id_ed25519",
        "id_rsa",
        "service-account.json",
    }
)
HIGH_RISK_SUFFIXES = (
    ".mobileprovision",
    ".p12",
    ".p8",
    ".pem",
    ".private-key",
)


@dataclass(frozen=True)
class Finding:
    kind: str
    relative_path: str
    line: Optional[int] = None

    def receipt(self) -> dict[str, object]:
        value: dict[str, object] = {
            "kind": self.kind,
            "relativePath": safe_relative_path(self.relative_path),
        }
        if self.line is not None:
            value["line"] = self.line
        return value


class AuditFailure(Exception):
    def __init__(self, code: str, message: str, recovery: str):
        super().__init__(message)
        self.code = code
        self.message = message
        self.recovery = recovery


def fail(code: str, message: str, recovery: str) -> None:
    raise AuditFailure(code, message, recovery)


def safe_relative_path(value: str) -> str:
    normalized = value.replace("\\", "/").strip("/")
    components = normalized.split("/")
    private_markers = {"home", "private", "users", "var", "volumes"}
    if (
        not normalized
        or len(normalized) > 240
        or any(component.casefold() in private_markers for component in components)
        or re.fullmatch(r"[A-Za-z0-9._@+/-]+", normalized) is None
    ):
        digest = hashlib.sha256(value.encode("utf-8", errors="replace")).hexdigest()
        return f"opaque-{digest[:12]}"
    return normalized


def is_high_risk_name(path: pathlib.Path) -> bool:
    name = path.name.casefold()
    if name == ".env.example":
        return False
    return (
        name in HIGH_RISK_NAMES
        or name.startswith(".env.")
        or name.endswith(HIGH_RISK_SUFFIXES)
        or name.endswith(".key")
        or name.startswith("service-account-") and name.endswith(".json")
    )


def public_roots(root: pathlib.Path) -> Iterable[pathlib.Path]:
    for relative in ROOT_FILES:
        candidate = root / relative
        if candidate.exists() or candidate.is_symlink():
            yield candidate
    for relative in ROOT_DIRECTORIES:
        candidate = root / relative
        if candidate.exists() or candidate.is_symlink():
            yield candidate
    release = root / "release"
    for relative in ("README.md", "release-gates.json"):
        candidate = release / relative
        if candidate.exists() or candidate.is_symlink():
            yield candidate
    for relative in ("SOURCE-PACKAGE.json", "SOURCE-SHA256SUMS.txt"):
        candidate = root / relative
        if candidate.exists() or candidate.is_symlink():
            yield candidate


def iter_public_files(root: pathlib.Path) -> Iterable[pathlib.Path]:
    seen: set[pathlib.Path] = set()
    for public_root in public_roots(root):
        if public_root.is_symlink():
            fail(
                "SOURCE_SECRET_AUDIT_UNSAFE_PATH",
                "The public source scope contains a symbolic link.",
                "Replace public-source links with regular files or directories, then rerun the audit.",
            )
        if public_root.is_file():
            resolved = public_root.resolve()
            if resolved not in seen:
                seen.add(resolved)
                yield public_root
            continue
        if not public_root.is_dir():
            fail(
                "SOURCE_SECRET_AUDIT_UNSAFE_PATH",
                "A public source root is not a regular file or directory.",
                "Restore the public source allowlist, then rerun the audit.",
            )
        for directory, directory_names, file_names in os.walk(
            public_root,
            topdown=True,
            followlinks=False,
        ):
            directory_path = pathlib.Path(directory)
            safe_directories: list[str] = []
            for name in sorted(directory_names):
                candidate = directory_path / name
                if candidate.is_symlink():
                    fail(
                        "SOURCE_SECRET_AUDIT_UNSAFE_PATH",
                        "The public source scope contains a symbolic link.",
                        "Replace public-source links with regular files or directories, then rerun the audit.",
                    )
                if name not in PRIVATE_ROOTS and name != "__pycache__":
                    safe_directories.append(name)
            directory_names[:] = safe_directories
            for name in sorted(file_names):
                candidate = directory_path / name
                if candidate.is_symlink() or not candidate.is_file():
                    fail(
                        "SOURCE_SECRET_AUDIT_UNSAFE_PATH",
                        "The public source scope contains an unsafe file entry.",
                        "Replace public-source links and special files with regular files, then rerun the audit.",
                    )
                resolved = candidate.resolve()
                if resolved not in seen:
                    seen.add(resolved)
                    yield candidate


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def compiled_patterns() -> list[tuple[str, re.Pattern[str]]]:
    private_key_marker = "-----BEGIN " + "PRIVATE KEY-----"
    encrypted_key_marker = "-----BEGIN ENCRYPTED " + "PRIVATE KEY-----"
    github_classic = "gh" + "[pousr]_"
    github_fine_grained = "github" + "_pat_"
    openai_style = "s" + "k-"
    return [
        (
            "embedded-private-key",
            re.compile(re.escape(private_key_marker) + "|" + re.escape(encrypted_key_marker)),
        ),
        (
            "known-provider-token",
            re.compile(
                rf"(?:{github_classic}[A-Za-z0-9]{{20,}}|"
                rf"{github_fine_grained}[A-Za-z0-9_]{{20,}}|"
                rf"(?<![A-Za-z0-9]){openai_style}[A-Za-z0-9_-]{{20,}}|"
                r"AKIA[0-9A-Z]{16}|"
                r"AIza[0-9A-Za-z_-]{30,}|"
                r"xox[baprs]-[0-9A-Za-z-]{20,}|"
                r"sk_live_[0-9A-Za-z]{16,})"
            ),
        ),
        (
            "embedded-basic-auth",
            re.compile(r"https?://[^\s/:@]{1,64}:[^\s/@]{8,128}@", re.IGNORECASE),
        ),
    ]


SENSITIVE_ASSIGNMENT = re.compile(
    r"(?im)^[ \t]*(?:export[ \t]+)?"
    r"(?:[\"']?[A-Za-z0-9_.-]*(?:api[_-]?key|access[_-]?token|auth[_-]?token|"
    r"client[_-]?secret|secret[_-]?access[_-]?key|password|passwd|private[_-]?key)"
    r"[\"']?)[ \t]*(?:=|:)[ \t]*[\"']?([^\s\"',;}]{12,})"
)
PLACEHOLDER_PARTS = (
    "${",
    "<",
    "changeme",
    "example",
    "placeholder",
    "process.env",
    "redacted",
    "replace_me",
    "replace_with_",
    "your_",
)


def scan_text(relative: str, text: str) -> list[Finding]:
    findings: list[Finding] = []
    for kind, pattern in compiled_patterns():
        for match in pattern.finditer(text):
            findings.append(Finding(kind, relative, line_number(text, match.start())))
    for match in SENSITIVE_ASSIGNMENT.finditer(text):
        value = match.group(1).casefold()
        if any(part in value for part in PLACEHOLDER_PARTS):
            continue
        if set(value) <= {"*", "x", "-", "_"}:
            continue
        findings.append(
            Finding(
                "credential-assignment",
                relative,
                line_number(text, match.start()),
            )
        )
    unique: dict[tuple[str, str, Optional[int]], Finding] = {}
    for finding in findings:
        unique[(finding.kind, finding.relative_path, finding.line)] = finding
    return sorted(
        unique.values(),
        key=lambda item: (item.relative_path, item.line or 0, item.kind),
    )


def audit(root: pathlib.Path) -> dict[str, object]:
    if root.is_symlink() or not root.is_dir():
        fail(
            "SOURCE_SECRET_AUDIT_INVALID_ARGUMENT",
            "The selected audit root is not a regular directory.",
            "Choose a repository or extracted source-package directory and retry.",
        )
    files_visited = 0
    text_files_scanned = 0
    binary_files_skipped = 0
    bytes_scanned = 0
    findings: list[Finding] = []
    for path in iter_public_files(root):
        files_visited += 1
        if files_visited > MAX_FILES:
            fail(
                "SOURCE_SECRET_AUDIT_RESOURCE_LIMIT",
                "The public source scope exceeds the bounded file count.",
                "Remove generated files from public roots or narrow them to the documented source allowlist.",
            )
        relative = path.relative_to(root).as_posix()
        if is_high_risk_name(path):
            findings.append(Finding("high-risk-credential-file", relative))
            continue
        if path.suffix.casefold() in BINARY_SUFFIXES:
            binary_files_skipped += 1
            continue
        try:
            size = path.stat().st_size
        except OSError:
            fail(
                "SOURCE_SECRET_AUDIT_UNREADABLE_FILE",
                "A public source file could not be inspected.",
                "Restore readable regular source files, then rerun the audit.",
            )
        if size > MAX_TEXT_FILE_BYTES:
            fail(
                "SOURCE_SECRET_AUDIT_RESOURCE_LIMIT",
                "A non-media public source file exceeds the bounded scan size.",
                "Remove generated or bundled payloads from public source roots, then rerun the audit.",
            )
        try:
            payload = path.read_bytes()
        except OSError:
            fail(
                "SOURCE_SECRET_AUDIT_UNREADABLE_FILE",
                "A public source file could not be inspected.",
                "Restore readable regular source files, then rerun the audit.",
            )
        bytes_scanned += len(payload)
        if bytes_scanned > MAX_TEXT_BYTES:
            fail(
                "SOURCE_SECRET_AUDIT_RESOURCE_LIMIT",
                "The public source text exceeds the bounded aggregate scan size.",
                "Remove generated files from public source roots, then rerun the audit.",
            )
        try:
            text = payload.decode("utf-8")
        except UnicodeDecodeError:
            fail(
                "SOURCE_SECRET_AUDIT_UNREADABLE_FILE",
                "A non-media public source file is not UTF-8 text.",
                "Move binary payloads to declared media locations or encode source as UTF-8, then retry.",
            )
        text_files_scanned += 1
        findings.extend(scan_text(relative, text))

    findings.sort(key=lambda item: (item.relative_path, item.line or 0, item.kind))
    limited = findings[:MAX_FINDINGS]
    status = "PASS" if not findings else "FAIL"
    return {
        "schemaVersion": 1,
        "contract": CONTRACT,
        "status": status,
        "code": None if not findings else "SOURCE_SECRET_AUDIT_FINDINGS",
        "message": (
            "The public source allowlist contains no detected credential material."
            if not findings
            else "The public source allowlist contains credential material that must be removed."
        ),
        "recoveryAction": (
            None
            if not findings
            else "Revoke any real credential, remove it from public source and history, then rerun this audit before packaging."
        ),
        "scanScope": "portable-source-public-allowlist",
        "filesVisited": files_visited,
        "textFilesScanned": text_files_scanned,
        "binaryFilesSkipped": binary_files_skipped,
        "bytesScanned": bytes_scanned,
        "findingCount": len(findings),
        "findingsTruncated": len(findings) > MAX_FINDINGS,
        "findings": [item.receipt() for item in limited],
        "networkRequired": False,
        "environmentValuesRead": False,
        "privateDirectoriesScanned": False,
        "contentExcerptsIncluded": False,
        "releaseState": RELEASE_STATE,
    }


def failure_receipt(error: AuditFailure) -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "contract": CONTRACT,
        "status": "FAIL",
        "code": error.code,
        "message": error.message,
        "recoveryAction": error.recovery,
        "scanScope": "portable-source-public-allowlist",
        "filesVisited": 0,
        "textFilesScanned": 0,
        "binaryFilesSkipped": 0,
        "bytesScanned": 0,
        "findingCount": 0,
        "findingsTruncated": False,
        "findings": [],
        "networkRequired": False,
        "environmentValuesRead": False,
        "privateDirectoriesScanned": False,
        "contentExcerptsIncluded": False,
        "releaseState": RELEASE_STATE,
    }


def print_usage() -> None:
    print("Usage: python3 scripts/audit-public-source-secrets.py [--root <directory>] [--json]")


def main(argv: list[str]) -> int:
    root = pathlib.Path(__file__).resolve().parents[1]
    emits_json = "--json" in argv
    index = 0
    try:
        while index < len(argv):
            argument = argv[index]
            if argument in {"--help", "-h"}:
                print_usage()
                return 0
            if argument == "--json":
                emits_json = True
                index += 1
                continue
            if argument == "--root":
                if index + 1 >= len(argv) or argv[index + 1].startswith("-"):
                    fail(
                        "SOURCE_SECRET_AUDIT_INVALID_ARGUMENT",
                        "The root option requires a directory value.",
                        "Provide --root <repository-or-source-package-directory> and retry.",
                    )
                root = pathlib.Path(argv[index + 1]).expanduser().resolve()
                index += 2
                continue
            fail(
                "SOURCE_SECRET_AUDIT_UNKNOWN_OPTION",
                "The secret-audit command received an unknown option.",
                "Use --root, --json or --help and retry.",
            )
        receipt = audit(root)
    except AuditFailure as error:
        receipt = failure_receipt(error)
    except Exception:
        receipt = failure_receipt(
            AuditFailure(
                "SOURCE_SECRET_AUDIT_UNEXPECTED_ERROR",
                "The public source secret audit could not complete safely.",
                "Run scripts/doctor.sh, restore a complete checkout and retry.",
            )
        )
    if emits_json:
        print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
    elif receipt["status"] == "PASS":
        print(
            "PASS  public source credential hygiene: "
            f"{receipt['textFilesScanned']} text files, {receipt['bytesScanned']} bytes"
        )
    else:
        print(f"FAIL  [{receipt['code']}] {receipt['message']}", file=sys.stderr)
        print(f"ACTION  {receipt['recoveryAction']}", file=sys.stderr)
    return 0 if receipt["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
