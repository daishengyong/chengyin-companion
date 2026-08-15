#!/usr/bin/env python3
"""Generate Chengyin's pre-recorded Volcengine Seed-TTS 2.0 voice pack."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]
MANIFEST = PROJECT_DIR / "Sources/CompanionApp/Resources/voice-lines.json"
OUTPUT_DIR = PROJECT_DIR / "Sources/CompanionApp/Resources/Audio"
DEFAULT_VOICE = "zh_female_meilinvyou_saturn_bigtts"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="replace existing clips")
    parser.add_argument("--limit", type=int, default=0, help="generate only N clips")
    parser.add_argument("--event", help="generate only one event category")
    parser.add_argument("--voice", default=DEFAULT_VOICE)
    return parser.parse_args()


def require_environment() -> tuple[str, str, str]:
    app_id = os.environ.get("VOLCENGINE_TTS2_APP_ID", "")
    token = os.environ.get("VOLCENGINE_TTS2_ACCESS_TOKEN", "")
    resource_id = os.environ.get("VOLCENGINE_TTS2_RESOURCE_ID", "seed-tts-2.0")
    if not app_id or not token:
        raise SystemExit(
            "Missing VOLCENGINE_TTS2_APP_ID or VOLCENGINE_TTS2_ACCESS_TOKEN. "
            "Keep credentials in your local environment; never add them to the project."
        )
    return app_id, token, resource_id


def main() -> int:
    args = parse_args()
    app_id, token, resource_id = require_environment()
    try:
        from doubao_speech import synthesize
    except ImportError:
        raise SystemExit(
            "Install the generator dependency first: python3 -m pip install doubao-speech"
        )

    lines = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if args.event:
        lines = [line for line in lines if line["event"] == args.event]
    if args.limit > 0:
        lines = lines[: args.limit]

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    generated = 0
    skipped = 0
    for index, line in enumerate(lines, start=1):
        output = OUTPUT_DIR / line["audioFile"]
        if output.exists() and output.stat().st_size > 1000 and not args.force:
            skipped += 1
            print(f"[{index}/{len(lines)}] skip {output.name}", flush=True)
            continue
        print(f"[{index}/{len(lines)}] generate {output.name}", flush=True)
        synthesize(
            line["text"],
            output,
            voice=args.voice,
            app_id=app_id,
            access_token=token,
            resource_id=resource_id,
            audio_format="mp3",
            sample_rate=24000,
            speed=0.94,
        )
        generated += 1

    print(
        f"Voice pack ready: generated={generated}, skipped={skipped}, total={len(lines)}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
