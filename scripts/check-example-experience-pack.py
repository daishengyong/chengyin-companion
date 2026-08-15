#!/usr/bin/env python3
"""Guard the canonical pack as a complete, executable-free v2 learning example."""

from __future__ import annotations

import json
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_PACK = ROOT / "examples/packs/hello-workday"
GENERATOR = ROOT / "examples/packs/generate-hello-workday-media.sh"
EXPECTED_LOCALES = {"zh-Hans", "en-US"}
EXPECTED_ROLES = ["enter", "react", "exit"]
FORBIDDEN_SUFFIXES = {
    ".app", ".command", ".dylib", ".exe", ".js", ".py", ".sh", ".swift",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_object(path: pathlib.Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"{path.name} must contain an object")
    return value


def selected_pack(arguments: list[str]) -> pathlib.Path:
    if not arguments:
        return DEFAULT_PACK
    require(len(arguments) == 2 and arguments[0] == "--pack", "use --pack followed by one fixture directory")
    pack = pathlib.Path(arguments[1])
    require(pack.is_dir() and not pack.is_symlink(), "fixture pack must be a regular directory")
    return pack


def main(arguments: list[str]) -> int:
    pack = selected_pack(arguments)
    manifest = load_object(pack / "manifest.json")
    require(manifest.get("schemaVersion") == 2, "canonical example must use schema v2")
    require(set(manifest.get("locales", [])) == EXPECTED_LOCALES, "canonical locales drifted")

    assets = manifest.get("assets")
    experiences = manifest.get("experiences")
    contribution = manifest.get("contribution")
    require(isinstance(assets, list) and len(assets) >= 5, "canonical example lost its media set")
    require(isinstance(experiences, list) and len(experiences) >= 1, "canonical example has no experience")
    require(isinstance(contribution, dict), "canonical example lost contribution metadata")
    require(contribution.get("contractVersion") == 2, "canonical example is not strict v2")

    assets_by_id: dict[str, dict[str, object]] = {}
    for value in assets:
        require(isinstance(value, dict), "asset entries must be objects")
        asset_id = value.get("id")
        require(isinstance(asset_id, str), "asset ID is missing")
        require(asset_id not in assets_by_id, f"duplicate asset ID: {asset_id}")
        assets_by_id[asset_id] = value

        relative = value.get("path")
        require(isinstance(relative, str), f"asset path is missing: {asset_id}")
        asset_path = pack / relative
        require(asset_path.is_file() and not asset_path.is_symlink(), f"asset file is unsafe: {asset_id}")
        require(asset_path.suffix.lower() not in FORBIDDEN_SUFFIXES, f"executable asset is forbidden: {asset_id}")

    experience = next(
        (item for item in experiences if isinstance(item, dict) and item.get("id") == "ritual.shared-win"),
        None,
    )
    require(isinstance(experience, dict), "canonical shared-win ritual is missing")
    require(experience.get("kind") == "ritual", "shared-win must remain a ritual")
    require(experience.get("triggers") == ["taskCompleted"], "shared-win trigger drifted")
    require(set(experience.get("locales", [])) == EXPECTED_LOCALES, "shared-win locales drifted")
    require(experience.get("returnPolicy") == "previousMode", "shared-win must restore the prior mode")

    steps = experience.get("steps")
    require(isinstance(steps, list) and len(steps) == 3, "shared-win must retain three ordered beats")
    require([item.get("role") for item in steps] == EXPECTED_ROLES, "shared-win roles drifted")
    for step in steps:
        require(isinstance(step, dict), "experience step must be an object")
        asset_id = step.get("assetID")
        asset = assets_by_id.get(asset_id) if isinstance(asset_id, str) else None
        require(asset is not None and asset.get("kind") == "video", "every shared-win step must reference video")
        require(asset.get("triggers") == [], "experience media must not bypass sequence routing")
        require(asset.get("hasNativeAudio") is True, "example video must demonstrate native audio metadata")
        require(asset.get("width") == 640 and asset.get("height") == 360, "example video must stay 16:9")
        anchors = asset.get("cropAnchors")
        require(isinstance(anchors, dict), "example video lost presentation projections")
        require({"pet", "stage", "fullscreen"}.issubset(anchors), "example video lost a presentation projection")

    rights = contribution.get("rights")
    accessibility = contribution.get("accessibility")
    fallback = contribution.get("fallback")
    require(isinstance(rights, list), "rights metadata is missing")
    require(isinstance(accessibility, list), "accessibility metadata is missing")
    require(isinstance(fallback, dict), "fallback metadata is missing")
    require({item.get("assetID") for item in rights if isinstance(item, dict)} == set(assets_by_id), "rights coverage drifted")
    require({item.get("assetID") for item in accessibility if isinstance(item, dict)} == set(assets_by_id), "accessibility coverage drifted")
    fallback_assets = fallback.get("assets")
    require(isinstance(fallback_assets, list), "per-asset fallback is missing")
    require({item.get("assetID") for item in fallback_assets if isinstance(item, dict)} == set(assets_by_id), "fallback coverage drifted")

    for record in accessibility:
        if not isinstance(record, dict) or record.get("assetID") not in {
            step.get("assetID") for step in steps if isinstance(step, dict)
        }:
            continue
        for field in ("descriptions", "transcripts", "altText", "captions", "soundDescriptions"):
            localized = record.get(field)
            require(isinstance(localized, dict), f"video accessibility field is missing: {field}")
            require(set(localized) == EXPECTED_LOCALES, f"video {field} locales drifted")
        require(record.get("flashingLights") is False, "example video must remain non-flashing")
        require(record.get("suddenLoudAudio") is False, "example audio must remain softly introduced")

    locale_key_sets: list[set[str]] = []
    for locale in sorted(EXPECTED_LOCALES):
        localized = load_object(pack / "localization" / f"{locale}.json")
        locale_key_sets.append(set(localized))
    require(locale_key_sets[0] == locale_key_sets[1], "canonical localization keys drifted")

    require(GENERATOR.is_file() and not GENERATOR.is_symlink(), "media generator is missing")
    generator_source = GENERATOR.read_text(encoding="utf-8")
    for expected_name in ("shared-win-enter.mov", "shared-win-react.mov", "shared-win-exit.mov"):
        require(expected_name in generator_source, f"generator lost {expected_name}")
    require(not re.search(r"https?://", generator_source), "media generator must stay network-free")

    print("Canonical experience pack check: PASS (v2, 5 assets, 2 locales, 3 video beats)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except (AssertionError, OSError, UnicodeError, json.JSONDecodeError) as error:
        print(f"Canonical experience pack check: FAIL ({error})", file=sys.stderr)
        raise SystemExit(1)
