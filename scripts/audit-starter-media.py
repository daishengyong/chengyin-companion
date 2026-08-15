#!/usr/bin/env python3
"""Audit the exact built-in Starter resource contract without network access."""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import plistlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_RESOURCES = ROOT / "Sources" / "CompanionApp" / "Resources"
MANIFEST_NAME = "starter-media.json"
MAX_MANIFEST_BYTES = 2 * 1024 * 1024
MAX_ASSETS = 512
MAX_ASSET_BYTES = 512 * 1024 * 1024
ALLOWED_SUFFIXES = {".icns", ".json", ".mov", ".mp3", ".png", ".strings", ".wav"}
ROOT_KEYS = {
    "schemaVersion", "contract", "packID", "version", "distributionClass",
    "providerCredentialsRequiredAtBuild", "license", "licenseReview",
    "rightsConclusion", "accessibilityConclusion", "publicDistributionReady",
    "privacy", "fallback", "assets",
}
ASSET_KEYS = {
    "id", "path", "bundlePath", "kind", "bytes", "sha256",
    "provenance", "accessibility", "fallback",
}
PROVENANCE_KEYS = {
    "source", "author", "provider", "license", "authorizationBasis",
    "allowedUses", "attribution", "adultFictionStatus", "evidenceID", "review",
}
ACCESSIBILITY_KEYS = {"altText", "captions", "soundDescription", "review"}
REVIEW_KEYS = {"status", "reviewerID", "reviewedAt", "version"}
LOCALIZED_KEYS = {"zh-Hans", "en"}
PUBLIC_ALLOWED_USES = {
    "localUse", "backup", "freeRedistributionWithCore", "accessibilityAdaptation",
}
ALL_ALLOWED_USES = {
    "localUse", "backup", "internalDevelopment", "automatedTesting",
    "freeRedistributionWithCore", "accessibilityAdaptation",
}
AUTHORIZATION_BASES = {
    "owned", "licensed", "commissioned", "providerOutput", "publicDomain", None,
}
PRIVATE_MARKERS = ("/Users/", "/Volumes/", "file://", "\\Users\\")


class AuditFailure(Exception):
    def __init__(self, code: str, message: str, action: str):
        super().__init__(message)
        self.code = code
        self.message = message
        self.action = action


def fail(code: str, message: str, action: str) -> None:
    raise AuditFailure(code, message, action)


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def strings(value: object):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key, item in value.items():
            yield str(key)
            yield from strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)


def exact_keys(value: object, expected: set[str], label: str) -> dict[str, object]:
    if not isinstance(value, dict) or set(value) != expected:
        fail(
            "STARTER_MEDIA_CONTRACT_INVALID",
            f"The {label} has missing or unknown fields.",
            "Restore or regenerate the Starter manifest, then rerun the audit.",
        )
    return value


def valid_review(value: object, *, allow_not_applicable: bool = True) -> dict[str, object]:
    record = exact_keys(value, REVIEW_KEYS, "review record")
    statuses = {"pending", "approved", "rejected"}
    if allow_not_applicable:
        statuses.add("notApplicable")
    if record.get("status") not in statuses:
        fail("STARTER_MEDIA_CONTRACT_INVALID", "A review status is invalid.", "Restore a supported review status and retry.")
    if not isinstance(record.get("version"), int) or not 1 <= int(record["version"]) <= 1_000_000:
        fail("STARTER_MEDIA_CONTRACT_INVALID", "A review version is invalid.", "Use a positive bounded review version and retry.")
    for key in ("reviewerID", "reviewedAt"):
        if record.get(key) is not None and (not isinstance(record[key], str) or not record[key]):
            fail("STARTER_MEDIA_CONTRACT_INVALID", "A review identity or time is invalid.", "Use a non-empty value or null and retry.")
    return record


def localized(value: object, label: str) -> dict[str, object]:
    record = exact_keys(value, LOCALIZED_KEYS, label)
    if any(item is not None and (not isinstance(item, str) or not item.strip()) for item in record.values()):
        fail("STARTER_MEDIA_CONTRACT_INVALID", f"The {label} contains an invalid value.", "Use localized text or explicit null values and retry.")
    return record


def nullable_bounded_string(value: object, label: str, maximum: int) -> None:
    if value is not None and (
        not isinstance(value, str)
        or not value.strip()
        or len(value) > maximum
    ):
        fail(
            "STARTER_MEDIA_CONTRACT_INVALID",
            f"The {label} is invalid.",
            "Use a bounded non-empty string or explicit null and retry.",
        )


def safe_relative(value: object, label: str) -> str:
    if (
        not isinstance(value, str)
        or not value
        or len(value) > 240
        or not re.fullmatch(r"[A-Za-z0-9._/-]+", value)
        or "\\" in value
        or value.startswith("/")
    ):
        fail("STARTER_MEDIA_CONTRACT_INVALID", f"The {label} is unsafe.", "Use a normalized relative resource path and retry.")
    parts = pathlib.PurePosixPath(value).parts
    if any(part in {"", ".", ".."} or part.startswith(".") for part in parts):
        fail("STARTER_MEDIA_CONTRACT_INVALID", f"The {label} is unsafe.", "Use a normalized non-hidden resource path and retry.")
    return value


def source_inventory(resources: pathlib.Path) -> dict[str, pathlib.Path]:
    if not resources.is_dir() or resources.is_symlink():
        fail("STARTER_MEDIA_CONTRACT_INVALID", "The Starter resource root is missing or unsafe.", "Restore the resource directory and retry.")
    result: dict[str, pathlib.Path] = {}
    for path in resources.rglob("*"):
        if path.is_symlink():
            fail("STARTER_MEDIA_CONTRACT_INVALID", "The Starter resources contain a symbolic link.", "Replace it with an inventoried regular file and retry.")
        if not path.is_file() or path.name == MANIFEST_NAME:
            continue
        relative = path.relative_to(resources).as_posix()
        safe_relative(relative, "resource path")
        if path.suffix.lower() not in ALLOWED_SUFFIXES:
            fail("STARTER_MEDIA_INVENTORY_MISMATCH", "The Starter resources contain an undeclared file type.", "Move production archives and metadata outside the runtime resource tree.")
        result[relative] = path
    return result


def expected_kind(relative: str) -> str:
    suffix = pathlib.PurePosixPath(relative).suffix.lower()
    return {
        ".mov": "video",
        ".mp3": "speech",
        ".wav": "sound",
        ".png": "image",
        ".icns": "icon",
        ".strings": "localization",
        ".json": "data",
    }[suffix]


def expected_bundle_path(relative: str) -> str:
    parts = pathlib.PurePosixPath(relative).parts
    return (
        "/".join((parts[0].lower(), *parts[1:]))
        if parts and parts[0].endswith(".lproj")
        else parts[-1]
    )


def bundle_inventory(bundle: pathlib.Path) -> dict[str, pathlib.Path]:
    result: dict[str, pathlib.Path] = {}
    for path in bundle.rglob("*"):
        if path.is_symlink():
            fail("STARTER_MEDIA_BUNDLE_MISMATCH", "The packaged resources contain a symbolic link.", "Stop distribution, rebuild the app and rerun the audit.")
        if not path.is_file():
            continue
        relative = path.relative_to(bundle).as_posix()
        if any(part.startswith(".") for part in pathlib.PurePosixPath(relative).parts):
            fail("STARTER_MEDIA_BUNDLE_MISMATCH", "The packaged resources contain hidden metadata.", "Stop distribution, rebuild the app and rerun the audit.")
        result[relative] = path
    return result


def rights_ready(asset: dict[str, object]) -> bool:
    provenance = asset["provenance"]
    assert isinstance(provenance, dict)
    attribution = provenance["attribution"]
    review = provenance["review"]
    return bool(
        provenance["license"]
        and provenance["authorizationBasis"]
        and set(provenance["allowedUses"]) >= PUBLIC_ALLOWED_USES
        and isinstance(attribution, dict)
        and attribution.get("required") is not None
        and provenance["adultFictionStatus"] != "unverified"
        and isinstance(review, dict)
        and review.get("status") == "approved"
        and review.get("reviewerID")
        and review.get("reviewedAt")
    )


def accessibility_ready(asset: dict[str, object]) -> bool:
    kind = asset["kind"]
    accessibility = asset["accessibility"]
    assert isinstance(accessibility, dict)
    review = accessibility["review"]
    if kind in {"data", "localization"}:
        return isinstance(review, dict) and review.get("status") == "notApplicable"
    if not (
        isinstance(review, dict)
        and review.get("status") == "approved"
        and review.get("reviewerID")
        and review.get("reviewedAt")
    ):
        return False
    field = (
        "altText" if kind in {"video", "image", "icon"}
        else "captions" if kind == "speech"
        else "soundDescription"
    )
    values = accessibility[field]
    return isinstance(values, dict) and all(values.get(locale) for locale in LOCALIZED_KEYS)


def audit(
    resources: pathlib.Path,
    bundle: pathlib.Path | None,
    allow_swiftpm_metadata: bool = False,
) -> dict[str, object]:
    manifest_path = resources / MANIFEST_NAME
    if not manifest_path.is_file() or manifest_path.is_symlink():
        fail("STARTER_MEDIA_MANIFEST_MISSING", "The built-in Starter manifest is missing.", "Regenerate it and review every pending field before release.")
    if manifest_path.stat().st_size > MAX_MANIFEST_BYTES:
        fail("STARTER_MEDIA_CONTRACT_INVALID", "The Starter manifest exceeds its size limit.", "Restore a bounded manifest and retry.")
    try:
        raw = manifest_path.read_bytes()
        manifest = json.loads(raw.decode("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        fail("STARTER_MEDIA_CONTRACT_INVALID", "The Starter manifest is not valid UTF-8 JSON.", "Regenerate the manifest and retry.")
    manifest = exact_keys(manifest, ROOT_KEYS, "Starter manifest")
    if (
        manifest.get("schemaVersion") != 1
        or manifest.get("contract") != "chengyin.starter-media/v1"
        or manifest.get("packID") != "cc.chengyin.builtin-starter"
        or manifest.get("providerCredentialsRequiredAtBuild") is not False
    ):
        fail("STARTER_MEDIA_CONTRACT_INVALID", "The Starter package contract is invalid.", "Regenerate it with the current repository tool and retry.")
    if not isinstance(manifest.get("version"), str) or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", manifest["version"]):
        fail("STARTER_MEDIA_CONTRACT_INVALID", "The Starter version is invalid.", "Match the application version and retry.")
    try:
        with (ROOT / "Info.plist").open("rb") as stream:
            app_version = str(plistlib.load(stream)["CFBundleShortVersionString"])
    except (OSError, KeyError, plistlib.InvalidFileException):
        fail("STARTER_MEDIA_CONTRACT_INVALID", "The application version cannot be read.", "Restore Info.plist and retry.")
    if manifest["version"] != app_version:
        fail("STARTER_MEDIA_CONTRACT_INVALID", "The Starter and application versions do not match.", "Refresh the Starter manifest for the current application version.")
    if manifest.get("distributionClass") not in {"internalPreview", "publicCandidate"}:
        fail("STARTER_MEDIA_CONTRACT_INVALID", "The Starter distribution class is invalid.", "Use a supported distribution class and retry.")
    license_review = valid_review(manifest.get("licenseReview"), allow_not_applicable=False)
    nullable_bounded_string(manifest.get("license"), "package license declaration", 256)
    if manifest.get("rightsConclusion") not in {"pending", "approved"}:
        fail("STARTER_MEDIA_CONTRACT_INVALID", "The rights conclusion is invalid.", "Regenerate the derived rights conclusion and retry.")
    if manifest.get("accessibilityConclusion") not in {"pending", "approved"}:
        fail("STARTER_MEDIA_CONTRACT_INVALID", "The accessibility conclusion is invalid.", "Regenerate the derived accessibility conclusion and retry.")
    if not isinstance(manifest.get("publicDistributionReady"), bool):
        fail("STARTER_MEDIA_CONTRACT_INVALID", "The public-distribution flag is invalid.", "Use a derived boolean release flag and retry.")
    privacy = exact_keys(manifest.get("privacy"), {"containsAPIKeys", "containsTaskContent", "containsPersonalPaths", "networkRequiredAtRuntime"}, "privacy declaration")
    if any(value is not False for value in privacy.values()):
        fail("STARTER_MEDIA_CONTRACT_INVALID", "The built-in Starter violates its local-only privacy declaration.", "Remove secrets, task content, personal paths and network dependencies.")
    fallback = exact_keys(manifest.get("fallback"), {"strategy", "worksWithoutProvider"}, "fallback declaration")
    if fallback != {"strategy": "localizedTextStaticSpriteAndAudioOnly", "worksWithoutProvider": True}:
        fail("STARTER_MEDIA_CONTRACT_INVALID", "The provider-free Starter fallback is invalid.", "Restore the offline fallback declaration and retry.")
    if any(marker in text for text in strings(manifest) for marker in PRIVATE_MARKERS):
        fail("STARTER_MEDIA_PRIVATE_PATH_DISCLOSURE", "The Starter manifest exposes a private local path.", "Replace it with an opaque evidence identifier and retry.")

    assets = manifest.get("assets")
    if not isinstance(assets, list) or not 1 <= len(assets) <= MAX_ASSETS:
        fail("STARTER_MEDIA_CONTRACT_INVALID", "The Starter asset list is invalid.", "Restore a bounded non-empty asset list and retry.")
    source_files = source_inventory(resources)
    declared_paths: set[str] = set()
    declared_ids: set[str] = set()
    bundle_paths: set[str] = set()
    rights_count = 0
    accessibility_count = 0
    for item in assets:
        asset = exact_keys(item, ASSET_KEYS, "Starter asset")
        asset_id = asset.get("id")
        if not isinstance(asset_id, str) or not re.fullmatch(r"starter\.[a-z0-9][a-z0-9._-]*", asset_id):
            fail("STARTER_MEDIA_CONTRACT_INVALID", "A Starter asset ID is invalid.", "Use a stable lowercase Starter asset ID and retry.")
        relative = safe_relative(asset.get("path"), "asset path")
        bundle_path = safe_relative(asset.get("bundlePath"), "bundle path")
        if asset_id in declared_ids or relative in declared_paths or bundle_path.casefold() in bundle_paths:
            fail("STARTER_MEDIA_CONTRACT_INVALID", "The Starter manifest contains a duplicate ID or path.", "Assign unique source and flattened bundle paths, then retry.")
        declared_ids.add(asset_id)
        declared_paths.add(relative)
        bundle_paths.add(bundle_path.casefold())
        kind = asset.get("kind")
        if kind not in {"video", "speech", "sound", "image", "icon", "data", "localization"}:
            fail("STARTER_MEDIA_CONTRACT_INVALID", "A Starter asset kind is invalid.", "Use a supported resource kind and retry.")
        if kind != expected_kind(relative) or bundle_path != expected_bundle_path(relative):
            fail("STARTER_MEDIA_CONTRACT_INVALID", "A Starter kind or bundle path does not match its source path.", "Refresh the manifest with the current deterministic mapping and retry.")
        expected_path = source_files.get(relative)
        if expected_path is None:
            fail("STARTER_MEDIA_INVENTORY_MISMATCH", "A declared Starter asset is missing.", "Restore the file or refresh the manifest without carrying approval forward.")
        expected_bytes = expected_path.stat().st_size
        if (
            expected_bytes > MAX_ASSET_BYTES
            or isinstance(asset.get("bytes"), bool)
            or not isinstance(asset.get("bytes"), int)
            or asset.get("bytes") != expected_bytes
        ):
            fail("STARTER_MEDIA_INVENTORY_MISMATCH", "A Starter asset size does not match its declaration.", "Restore the reviewed file or refresh the manifest and repeat review.")
        if (
            not isinstance(asset.get("sha256"), str)
            or not re.fullmatch(r"[0-9a-f]{64}", asset["sha256"])
            or sha256(expected_path) != asset["sha256"]
        ):
            fail("STARTER_MEDIA_HASH_MISMATCH", "A Starter asset does not match its declared SHA-256.", "Restore the reviewed file or refresh the manifest; changed bytes return to pending review.")
        provenance = exact_keys(asset.get("provenance"), PROVENANCE_KEYS, "asset provenance")
        if provenance.get("source") not in {"providerGeneratedVideo", "providerGeneratedSpeech", "prototypeDerivative", "repositoryExistingAudio", "repositoryAuthoredText"}:
            fail("STARTER_MEDIA_CONTRACT_INVALID", "An asset source class is invalid.", "Use a supported explicit source class and retry.")
        nullable_bounded_string(provenance.get("author"), "asset author", 160)
        nullable_bounded_string(provenance.get("provider"), "asset provider", 160)
        nullable_bounded_string(provenance.get("license"), "asset license", 256)
        nullable_bounded_string(provenance.get("evidenceID"), "asset evidence ID", 160)
        if provenance.get("authorizationBasis") not in AUTHORIZATION_BASES:
            fail("STARTER_MEDIA_CONTRACT_INVALID", "An authorization basis is invalid.", "Use a supported authorization basis or explicit null and retry.")
        if (
            not isinstance(provenance.get("allowedUses"), list)
            or not all(isinstance(use, str) for use in provenance["allowedUses"])
            or not set(provenance["allowedUses"]) <= ALL_ALLOWED_USES
            or len(set(provenance["allowedUses"])) != len(provenance["allowedUses"])
        ):
            fail("STARTER_MEDIA_CONTRACT_INVALID", "An allowed-use declaration is invalid.", "Use unique enumerated allowed uses and retry.")
        attribution = exact_keys(provenance.get("attribution"), {"required", "text"}, "attribution declaration")
        if attribution.get("required") is not None and not isinstance(attribution["required"], bool):
            fail("STARTER_MEDIA_CONTRACT_INVALID", "An attribution requirement is invalid.", "Use true, false or explicit null and retry.")
        nullable_bounded_string(attribution.get("text"), "attribution text", 500)
        if provenance.get("adultFictionStatus") not in {"fictionalAdult", "verifiedAdult", "noPeople", "notApplicable", "unverified"}:
            fail("STARTER_MEDIA_CONTRACT_INVALID", "An adult or fictional status is invalid.", "Record an explicit supported status and retry.")
        valid_review(provenance.get("review"), allow_not_applicable=False)
        accessibility = exact_keys(asset.get("accessibility"), ACCESSIBILITY_KEYS, "asset accessibility")
        localized(accessibility.get("altText"), "alt text")
        localized(accessibility.get("captions"), "captions")
        localized(accessibility.get("soundDescription"), "sound description")
        valid_review(accessibility.get("review"))
        if asset.get("fallback") not in {"staticSprite", "localizedText", "systemSymbol", "builtInDefaults"}:
            fail("STARTER_MEDIA_CONTRACT_INVALID", "An asset fallback is invalid.", "Declare a supported provider-free fallback and retry.")
        rights_count += int(rights_ready(asset))
        accessibility_count += int(accessibility_ready(asset))

    if declared_paths != set(source_files):
        fail("STARTER_MEDIA_INVENTORY_MISMATCH", "The Starter manifest does not cover exactly the shippable resource tree.", "Refresh the manifest and review every newly inventoried asset.")
    if bundle is not None:
        if not bundle.is_dir() or bundle.is_symlink():
            fail("STARTER_MEDIA_BUNDLE_MISMATCH", "The packaged resource directory is missing or unsafe.", "Rebuild the application and retry.")
        packaged_files = bundle_inventory(bundle)
        expected_packaged_paths = {str(asset["bundlePath"]) for asset in assets} | {MANIFEST_NAME}
        if allow_swiftpm_metadata and "Info.plist" in packaged_files:
            try:
                with packaged_files["Info.plist"].open("rb") as stream:
                    swiftpm_metadata = plistlib.load(stream)
            except (OSError, plistlib.InvalidFileException):
                fail("STARTER_MEDIA_BUNDLE_MISMATCH", "The SwiftPM resource metadata is invalid.", "Clean the build products, rebuild and retry.")
            if swiftpm_metadata != {"CFBundleDevelopmentRegion": "zh-Hans"}:
                fail("STARTER_MEDIA_BUNDLE_MISMATCH", "The SwiftPM resource metadata is unexpected.", "Clean the build products, rebuild and retry.")
            expected_packaged_paths.add("Info.plist")
        if set(packaged_files) != expected_packaged_paths:
            fail("STARTER_MEDIA_BUNDLE_MISMATCH", "The packaged resource inventory contains missing or extra files.", "Stop distribution, rebuild from the explicit resource allowlist and rerun the audit.")
        for asset in assets:
            packaged = packaged_files[str(asset["bundlePath"])]
            if not packaged.is_file() or packaged.is_symlink() or sha256(packaged) != asset["sha256"]:
                fail("STARTER_MEDIA_BUNDLE_MISMATCH", "The packaged Starter resources do not match the source manifest.", "Stop distribution, rebuild the app and rerun the audit.")
        packaged_manifest = bundle / MANIFEST_NAME
        if not packaged_manifest.is_file() or packaged_manifest.read_bytes() != raw:
            fail("STARTER_MEDIA_BUNDLE_MISMATCH", "The packaged Starter manifest is missing or changed.", "Stop distribution, rebuild the app and rerun the audit.")

    rights_approved = rights_count == len(assets)
    accessibility_approved = accessibility_count == len(assets)
    license_approved = bool(
        manifest.get("license")
        and license_review.get("status") == "approved"
        and license_review.get("reviewerID")
        and license_review.get("reviewedAt")
    )
    public_ready = rights_approved and accessibility_approved and license_approved
    expected = {
        "rightsConclusion": "approved" if rights_approved else "pending",
        "accessibilityConclusion": "approved" if accessibility_approved else "pending",
        "publicDistributionReady": public_ready,
        "distributionClass": "publicCandidate" if public_ready else "internalPreview",
    }
    if any(manifest.get(key) != value for key, value in expected.items()):
        fail("STARTER_MEDIA_APPROVAL_MISMATCH", "The Starter manifest claims a release state not derived from its evidence.", "Regenerate derived conclusions; never set approval flags by hand.")
    return {
        "schemaVersion": "chengyin.starter-media-audit/v1",
        "status": "PASS" if public_ready else "PASS_WITH_PENDING",
        "contract": "chengyin.starter-media/v1",
        "assetCount": len(assets),
        "rightsApprovedAssetCount": rights_count,
        "accessibilityApprovedAssetCount": accessibility_count,
        "licenseApproved": license_approved,
        "providerCredentialsRequiredAtBuild": False,
        "publicDistributionReady": public_ready,
        "distributionState": "PUBLIC_CANDIDATE" if public_ready else "INTERNAL_PREVIEW_ONLY",
    }


def failure_receipt(error: AuditFailure) -> dict[str, object]:
    return {
        "schemaVersion": "chengyin.starter-media-audit/v1",
        "status": "FAIL",
        "code": error.code,
        "message": error.message,
        "recoveryAction": error.action,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--resources", type=pathlib.Path, default=DEFAULT_RESOURCES)
    parser.add_argument("--bundle", type=pathlib.Path)
    parser.add_argument("--allow-swiftpm-metadata", action="store_true")
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    try:
        receipt = audit(
            args.resources.resolve(),
            args.bundle.resolve() if args.bundle else None,
            args.allow_swiftpm_metadata,
        )
    except AuditFailure as error:
        receipt = failure_receipt(error)
        if args.json:
            print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
        else:
            print(f"FAIL  [{error.code}] {error.message}", file=sys.stderr)
            print(f"ACTION  {error.action}", file=sys.stderr)
        return 1
    except Exception:
        receipt = failure_receipt(AuditFailure(
            "STARTER_MEDIA_UNEXPECTED_ERROR",
            "The Starter audit stopped at a privacy-safe fallback boundary.",
            "Retry once; if it repeats, restore the manifest and resource tree from the repository.",
        ))
        print(json.dumps(receipt, ensure_ascii=False, sort_keys=True) if args.json else receipt["message"])
        return 1
    if args.strict and not receipt["publicDistributionReady"]:
        receipt = dict(receipt)
        receipt.update({
            "status": "NOT_READY",
            "code": "STARTER_MEDIA_RIGHTS_PENDING",
            "recoveryAction": "Complete owner-approved media licensing, per-asset rights and bilingual accessibility review; then refresh and rerun strict audit.",
        })
        if args.json:
            print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
        else:
            print("NOT_READY  [STARTER_MEDIA_RIGHTS_PENDING] Built-in Starter remains internal-preview only.")
            print(f"ACTION  {receipt['recoveryAction']}")
        return 3
    if args.json:
        print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
    else:
        print(f"Starter media audit: {receipt['status']} ({receipt['assetCount']} assets)")
        print(f"Distribution state: {receipt['distributionState']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
