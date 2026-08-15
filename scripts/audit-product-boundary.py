#!/usr/bin/env python3
"""Audit Chengyin's local-first, noncommercial public-product boundary.

The guard is intentionally narrower than a general source-code policy engine.
It rejects concrete payment, account, advertising and automatic-sharing
integrations from runtime source, and keeps superseded commercialization
research out of the public clone. It never reads credentials, calls a network
service, mutates /Applications or includes matching source excerpts in output.
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


CONTRACT = "chengyin.product-boundary/v1"
RELEASE_STATE = "NOT_PUBLIC_RELEASE_READY"
MAX_FILES = 4096
MAX_FILE_BYTES = 2 * 1024 * 1024
MAX_TOTAL_BYTES = 64 * 1024 * 1024
MAX_FINDINGS = 64

HISTORICAL_DOCUMENTS = (
    "COMMERCIAL-MASTER-PLAN.md",
    "COMMERCIAL-READINESS-AUDIT.md",
    "CONTENT-FACTORY-100M.md",
    "EXECUTION-ROADMAP.md",
    "GITHUB-GROWTH-AND-COMMERCE.md",
    "GLOBAL-COMMERCIAL-PLAN.md",
    "PAYMENT-DECISION-CN.md",
    "PRODUCT-STRATEGY.md",
    "UNIT-ECONOMICS-AND-METRICS.md",
)
PRIVATE_RESEARCH_DIRECTORY = pathlib.PurePosixPath(
    "video-production/research/commercialization"
)
REQUIRED_PUBLIC_DOCUMENTS = (
    "docs/PRODUCT-BOUNDARY.md",
    "docs/PRODUCT-BOUNDARY.zh-Hans.md",
)
PUBLIC_ENTRY_DOCUMENTS = (
    "AGENTS.md",
    "CONTRIBUTING.md",
    "CONTRIBUTING.en.md",
    "README.md",
    "README.en.md",
    "ROADMAP.md",
    "ROADMAP.zh-Hans.md",
)


@dataclass(frozen=True)
class Finding:
    category: str
    kind: str
    relative_path: str
    line: int

    def receipt(self) -> dict[str, object]:
        return {
            "category": self.category,
            "kind": self.kind,
            "relativePath": safe_relative_path(self.relative_path),
            "line": self.line,
        }


class BoundaryFailure(Exception):
    def __init__(self, code: str, message: str, recovery: str):
        super().__init__(message)
        self.code = code
        self.message = message
        self.recovery = recovery


def fail(code: str, message: str, recovery: str) -> None:
    raise BoundaryFailure(code, message, recovery)


def safe_relative_path(value: str) -> str:
    normalized = value.replace("\\", "/").strip("/")
    private_markers = {"home", "private", "users", "var", "volumes"}
    components = normalized.split("/")
    if (
        not normalized
        or len(normalized) > 240
        or any(component.casefold() in private_markers for component in components)
        or re.fullmatch(r"[A-Za-z0-9._@+/-]+", normalized) is None
    ):
        digest = hashlib.sha256(value.encode("utf-8", errors="replace")).hexdigest()
        return f"opaque-{digest[:12]}"
    return normalized


RUNTIME_PATTERNS: tuple[tuple[str, str, re.Pattern[str]], ...] = (
    (
        "monetization",
        "payment-framework-import",
        re.compile(r"(?m)^[ \t]*import[ \t]+(?:StoreKit|PassKit)[ \t]*$"),
    ),
    (
        "monetization",
        "payment-provider-symbol",
        re.compile(
            r"\b(?:Stripe|Paddle|LemonSqueezy|RevenueCat|Adapty|"
            r"SKPaymentQueue|PaymentIntent|CheckoutSession)\b"
        ),
    ),
    (
        "monetization",
        "purchase-operation",
        re.compile(r"\b(?:Product\.purchase|AppStore\.sync)[ \t]*(?:\(|\{)"),
    ),
    (
        "monetization",
        "entitlement-provider-implementation",
        re.compile(
            r"(?m)^[ \t]*(?:final[ \t]+)?(?:struct|class|actor)[ \t]+"
            r"[A-Za-z_][A-Za-z0-9_]*[^\n{]*:[^\n{]*ContentPackEntitlementChecking\b"
        ),
    ),
    (
        "monetization",
        "purchase-deep-link",
        re.compile(r"chengyin://(?:purchase|checkout|subscribe)[A-Za-z0-9?&=._/-]*"),
    ),
    (
        "forced-account",
        "authentication-framework-import",
        re.compile(r"(?m)^[ \t]*import[ \t]+AuthenticationServices[ \t]*$"),
    ),
    (
        "forced-account",
        "account-authentication-symbol",
        re.compile(
            r"\b(?:ASAuthorizationController|ASAuthorizationAppleIDProvider|"
            r"SignInWithApple|OAuthLoginView|RequiredAccountView)\b"
        ),
    ),
    (
        "advertising",
        "advertising-framework-import",
        re.compile(
            r"(?m)^[ \t]*import[ \t]+(?:AppTrackingTransparency|AdSupport|"
            r"GoogleMobileAds|FBAudienceNetwork)[ \t]*$"
        ),
    ),
    (
        "advertising",
        "advertising-runtime-symbol",
        re.compile(
            r"\b(?:GADBannerView|GADInterstitialAd|ASIdentifierManager|"
            r"ATTrackingManager|FBAdView)\b"
        ),
    ),
    (
        "automatic-sharing",
        "automatic-share-operation",
        re.compile(
            r"\b(?:NSSharingService|UIActivityViewController)\b[^\n]{0,240}"
            r"\b(?:perform|present|show)\b"
        ),
    ),
    (
        "automatic-sharing",
        "automatic-share-symbol",
        re.compile(r"\b(?:automaticSharing|autoShareEnabled|shareAutomatically)\b"),
    ),
)


def read_text(path: pathlib.Path, *, total: list[int]) -> str:
    if path.is_symlink() or not path.is_file():
        fail(
            "PRODUCT_BOUNDARY_UNSAFE_PATH",
            "A product-boundary input is not a regular file.",
            "Replace symbolic links or special entries with reviewed regular source files, then retry.",
        )
    size = path.stat().st_size
    if size > MAX_FILE_BYTES:
        fail(
            "PRODUCT_BOUNDARY_RESOURCE_LIMIT",
            "A product-boundary source file exceeds the bounded scan size.",
            "Remove generated payloads from source and keep public policy files reviewable, then retry.",
        )
    total[0] += size
    if total[0] > MAX_TOTAL_BYTES:
        fail(
            "PRODUCT_BOUNDARY_RESOURCE_LIMIT",
            "The product-boundary text scope exceeds the bounded aggregate size.",
            "Remove generated payloads from public source and retry.",
        )
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        fail(
            "PRODUCT_BOUNDARY_UNSAFE_PATH",
            "A product-boundary source file is unreadable UTF-8 text.",
            "Restore readable UTF-8 source files, then retry.",
        )


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def runtime_paths(root: pathlib.Path) -> Iterable[pathlib.Path]:
    for relative in ("Package.swift", "Info.plist"):
        path = root / relative
        if not path.exists():
            fail(
                "PRODUCT_BOUNDARY_REQUIRED_PATH_MISSING",
                "A required runtime boundary input is missing.",
                "Restore Package.swift, Info.plist and Sources from a complete checkout, then retry.",
            )
        yield path
    sources = root / "Sources"
    if sources.is_symlink() or not sources.is_dir():
        fail(
            "PRODUCT_BOUNDARY_REQUIRED_PATH_MISSING",
            "The runtime Sources directory is missing or unsafe.",
            "Restore a regular Sources directory from a complete checkout, then retry.",
        )
    for directory, directory_names, file_names in os.walk(
        sources, topdown=True, followlinks=False
    ):
        directory_path = pathlib.Path(directory)
        for name in directory_names:
            if (directory_path / name).is_symlink():
                fail(
                    "PRODUCT_BOUNDARY_UNSAFE_PATH",
                    "The runtime source scope contains a symbolic link.",
                    "Replace source links with reviewed regular directories, then retry.",
                )
        for name in sorted(file_names):
            if name.endswith(".swift"):
                yield directory_path / name


def public_document_paths(root: pathlib.Path) -> Iterable[pathlib.Path]:
    for relative in PUBLIC_ENTRY_DOCUMENTS:
        path = root / relative
        if path.exists() or path.is_symlink():
            yield path
    docs = root / "docs"
    if docs.is_symlink() or not docs.is_dir():
        fail(
            "PRODUCT_BOUNDARY_REQUIRED_PATH_MISSING",
            "The public documentation directory is missing or unsafe.",
            "Restore the docs directory and product-boundary documents, then retry.",
        )
    for directory, directory_names, file_names in os.walk(
        docs, topdown=True, followlinks=False
    ):
        directory_path = pathlib.Path(directory)
        for name in directory_names:
            if (directory_path / name).is_symlink():
                fail(
                    "PRODUCT_BOUNDARY_UNSAFE_PATH",
                    "The public documentation scope contains a symbolic link.",
                    "Replace documentation links with reviewed regular directories, then retry.",
                )
        for name in sorted(file_names):
            if name.endswith(".md"):
                yield directory_path / name


def scan_runtime(relative: str, text: str) -> list[Finding]:
    findings: list[Finding] = []
    for category, kind, pattern in RUNTIME_PATTERNS:
        for match in pattern.finditer(text):
            findings.append(
                Finding(category, kind, relative, line_number(text, match.start()))
            )
    return findings


def scan_public_document(relative: str, text: str) -> list[Finding]:
    findings: list[Finding] = []
    basename = pathlib.PurePosixPath(relative).name
    if basename in HISTORICAL_DOCUMENTS:
        findings.append(Finding("historical-research", "superseded-document", relative, 1))
    # The auditor is part of the public source and necessarily contains the
    # denylist as testable data. Do not treat that self-description as a link
    # from public product documentation.
    if relative == "scripts/audit-product-boundary.py":
        return findings
    for historical_name in HISTORICAL_DOCUMENTS:
        for match in re.finditer(re.escape(historical_name), text):
            findings.append(
                Finding(
                    "historical-research",
                    "superseded-document-reference",
                    relative,
                    line_number(text, match.start()),
                )
            )
    return findings


def receipt_base(scope: str) -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "contract": CONTRACT,
        "scope": scope,
        "policy": {
            "monetization": False,
            "forcedAccount": False,
            "advertising": False,
            "automaticSharing": False,
            "manualLocalExport": True,
        },
        "networkRequired": False,
        "environmentValuesRead": False,
        "applicationsDirectoryModified": False,
        "contentExcerptsIncluded": False,
        "releaseState": RELEASE_STATE,
    }


def audit(root: pathlib.Path, scope: str) -> dict[str, object]:
    if root.is_symlink() or not root.is_dir():
        fail(
            "PRODUCT_BOUNDARY_INVALID_ARGUMENT",
            "The selected product-boundary root is not a regular directory.",
            "Choose a repository or extracted source-package directory and retry.",
        )
    for relative in REQUIRED_PUBLIC_DOCUMENTS:
        path = root / relative
        if path.is_symlink() or not path.is_file():
            fail(
                "PRODUCT_BOUNDARY_REQUIRED_PATH_MISSING",
                "A required product-boundary document is missing or unsafe.",
                "Restore both localized PRODUCT-BOUNDARY documents, then retry.",
            )

    total = [0]
    runtime_count = 0
    public_count = 0
    findings: list[Finding] = []
    for path in runtime_paths(root):
        runtime_count += 1
        if runtime_count > MAX_FILES:
            fail(
                "PRODUCT_BOUNDARY_RESOURCE_LIMIT",
                "The runtime boundary exceeds the bounded file count.",
                "Remove generated source entries and retry.",
            )
        relative = path.relative_to(root).as_posix()
        findings.extend(scan_runtime(relative, read_text(path, total=total)))

    seen_public: set[pathlib.Path] = set()
    for path in public_document_paths(root):
        resolved = path.resolve()
        if resolved in seen_public:
            continue
        seen_public.add(resolved)
        public_count += 1
        if runtime_count + public_count > MAX_FILES:
            fail(
                "PRODUCT_BOUNDARY_RESOURCE_LIMIT",
                "The public product-boundary scope exceeds the bounded file count.",
                "Remove generated documentation entries and retry.",
            )
        relative = path.relative_to(root).as_posix()
        findings.extend(scan_public_document(relative, read_text(path, total=total)))

    private_research = root / PRIVATE_RESEARCH_DIRECTORY
    private_count = sum(
        (private_research / name).is_file() and not (private_research / name).is_symlink()
        for name in HISTORICAL_DOCUMENTS
    )
    if findings:
        historical_state = (
            "leaked"
            if any(item.category == "historical-research" for item in findings)
            else "unknown"
        )
    elif scope == "public":
        historical_state = "excluded"
    elif private_count == len(HISTORICAL_DOCUMENTS):
        historical_state = "private-working-copy"
    else:
        historical_state = "unknown"

    unique = {
        (item.category, item.kind, item.relative_path, item.line): item
        for item in findings
    }
    ordered = sorted(
        unique.values(),
        key=lambda item: (item.relative_path, item.line, item.category, item.kind),
    )
    runtime_findings = [item for item in ordered if item.category != "historical-research"]
    if runtime_findings:
        code = "PRODUCT_BOUNDARY_FORBIDDEN_RUNTIME"
        message = "Runtime source contains a forbidden product integration."
        recovery = "Remove the payment, forced-account, advertising or automatic-sharing integration and rerun the boundary audit."
    elif ordered:
        code = "PRODUCT_BOUNDARY_PUBLIC_DOC_LEAK"
        message = "Public source contains superseded commercialization research or a reference to it."
        recovery = "Move historical research to the private working-copy archive, update public links and rebuild the source candidate."
    else:
        code = None
        message = "The local-first noncommercial product boundary is intact."
        recovery = None

    result = receipt_base(scope)
    result.update(
        {
            "status": "PASS" if not ordered else "FAIL",
            "code": code,
            "message": message,
            "recoveryAction": recovery,
            "runtimeFilesScanned": runtime_count,
            "publicFilesScanned": public_count,
            "forbiddenFindingCount": len(ordered),
            "findingsTruncated": len(ordered) > MAX_FINDINGS,
            "findings": [item.receipt() for item in ordered[:MAX_FINDINGS]],
            "historicalResearchState": historical_state,
        }
    )
    return result


def failure_receipt(error: BoundaryFailure, scope: str) -> dict[str, object]:
    result = receipt_base(scope)
    result.update(
        {
            "status": "FAIL",
            "code": error.code,
            "message": error.message,
            "recoveryAction": error.recovery,
            "runtimeFilesScanned": 0,
            "publicFilesScanned": 0,
            "forbiddenFindingCount": 0,
            "findingsTruncated": False,
            "findings": [],
            "historicalResearchState": "unknown",
        }
    )
    return result


def print_usage() -> None:
    print(
        "Usage: python3 scripts/audit-product-boundary.py "
        "[--root <directory>] [--scope development|public] [--json]"
    )


def main(argv: list[str]) -> int:
    root = pathlib.Path(__file__).resolve().parents[1]
    scope = "development"
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
                        "PRODUCT_BOUNDARY_INVALID_ARGUMENT",
                        "The root option requires a directory value.",
                        "Provide --root <repository-or-source-package-directory> and retry.",
                    )
                root = pathlib.Path(argv[index + 1]).expanduser().resolve()
                index += 2
                continue
            if argument == "--scope":
                if index + 1 >= len(argv) or argv[index + 1] not in {
                    "development",
                    "public",
                }:
                    fail(
                        "PRODUCT_BOUNDARY_INVALID_ARGUMENT",
                        "The scope option requires development or public.",
                        "Provide --scope development or --scope public and retry.",
                    )
                scope = argv[index + 1]
                index += 2
                continue
            fail(
                "PRODUCT_BOUNDARY_UNKNOWN_OPTION",
                "The product-boundary command received an unknown option.",
                "Use --root, --scope, --json or --help and retry.",
            )
        result = audit(root, scope)
    except BoundaryFailure as error:
        result = failure_receipt(error, scope)
    except Exception:
        result = failure_receipt(
            BoundaryFailure(
                "PRODUCT_BOUNDARY_UNEXPECTED_ERROR",
                "The product-boundary audit could not complete safely.",
                "Run scripts/doctor.sh, restore a complete checkout and retry.",
            ),
            scope,
        )

    if emits_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    elif result["status"] == "PASS":
        print(
            "PASS  local-first product boundary: "
            f"{result['runtimeFilesScanned']} runtime files, "
            f"{result['publicFilesScanned']} public documents"
        )
    else:
        print(f"FAIL  [{result['code']}] {result['message']}", file=sys.stderr)
        print(f"ACTION  {result['recoveryAction']}", file=sys.stderr)
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
