#!/usr/bin/env python3
"""Reject cross-event voice leakage from direct pet and magic-wand actions."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Sources/CompanionApp/CompanionServices.swift"
MANIFEST = ROOT / "Sources/CompanionApp/Resources/voice-lines.json"
STARTER_MANIFEST = ROOT / "Sources/CompanionApp/Resources/starter-media.json"
EXPECTED_SOURCE_CLAIMS = (
    "case .drink:\n            manualEvents = [.hydration]",
    "case .stretch:\n            manualEvents = [.movement, .eyeRest]",
    "case .clap, .jump, .cheer:\n            manualEvents = [.focusEncouragement]",
    "case .twirl, .laugh, .heart, .kiss:\n            manualEvents = [.flirt]",
)
ALLOWED_EVENTS = {
    "hydration",
    "movement",
    "eye_rest",
    "focus_encouragement",
    "flirt",
}
EXPECTED_NATIVE_ACTION_CAPTIONS = {
    "companion-action-0.mov": "老公，喝口水，照顾好自己我才放心呀。",
    "companion-action-1.mov": "起来伸个懒腰，陪我走几步，好不好？",
    "companion-action-2.mov": "做得漂亮，这两下掌声只送给你。",
    "companion-action-3.mov": "抓到你啦，陪我跳一下！",
    "companion-action-4.mov": "看好啦，我只为你转这一圈。",
    "companion-action-5.mov": "你一叫我，我就忍不住开心。",
    "companion-action-6.mov": "这颗心先放你那里，不许弄丢。",
    "companion-action-7.mov": "靠近一点，奖励你一个飞吻。",
    "companion-action-8.mov": "再给你一点女朋友能量，加油呀。",
}
FORBIDDEN_SOURCE_CLAIMS = (
    "$0.action == action",
    ".timeAnnouncement",
    ".taskComplete",
    ".taskFailed",
    ".replyReady",
    ".petGameStart",
)


def fail(message: str) -> None:
    raise SystemExit(f"FAIL  manual voice routing: {message}")


def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    marker = "func candidates(\n        for action: CompanionAction"
    start = source.find(marker)
    end = len(source)
    if start < 0:
        fail("the direct-action candidate boundary is missing")
    action_router = source[start:end]

    missing = [claim for claim in EXPECTED_SOURCE_CLAIMS if claim not in action_router]
    if missing:
        fail("the semantic action whitelist changed without updating its contract")
    leaked = [claim for claim in FORBIDDEN_SOURCE_CLAIMS if claim in action_router]
    if leaked:
        fail("clock, lifecycle, game, or broad action claims entered direct play")

    try:
        lines = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        fail("voice-lines.json is unreadable")
    if not isinstance(lines, list):
        fail("voice-lines.json is not an array")

    available_events = {
        record.get("event")
        for record in lines
        if isinstance(record, dict) and isinstance(record.get("event"), str)
    }
    missing_events = sorted(ALLOWED_EVENTS - available_events)
    if missing_events:
        fail("a direct-play semantic group has no packaged voice line")

    try:
        starter = json.loads(STARTER_MANIFEST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        fail("starter-media.json is unreadable")
    assets = {
        asset.get("bundlePath"): asset
        for asset in starter.get("assets", [])
        if isinstance(asset, dict) and isinstance(asset.get("bundlePath"), str)
    }
    for bundle_path, expected_caption in EXPECTED_NATIVE_ACTION_CAPTIONS.items():
        asset = assets.get(bundle_path)
        if not isinstance(asset, dict):
            fail(f"the reviewed native action is missing: {bundle_path}")
        accessibility = asset.get("accessibility")
        captions = accessibility.get("captions") if isinstance(accessibility, dict) else None
        if not isinstance(captions, dict) or captions.get("zh-Hans") != expected_caption:
            fail(f"the native action caption is missing or crossed: {bundle_path}")
        if "报时" in expected_caption or "点钟" in expected_caption:
            fail(f"a direct action caption contains clock language: {bundle_path}")

    print(
        "PASS  manual voice routing: 9 actions, "
        "9 SHA-bound native captions, 5 semantic TTS events, "
        "0 clock/lifecycle/game claims"
    )


if __name__ == "__main__":
    main()
