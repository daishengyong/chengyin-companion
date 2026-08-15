#!/usr/bin/env python3
"""Create or check the exact built-in Starter inventory without inferring rights."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import plistlib
import re
import sys
import tempfile


ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_RESOURCES = ROOT / "Sources" / "CompanionApp" / "Resources"
MANIFEST_NAME = "starter-media.json"
ALLOWED_SUFFIXES = {".icns", ".json", ".mov", ".mp3", ".png", ".strings", ".wav"}
PUBLIC_ALLOWED_USES = {
    "localUse",
    "backup",
    "freeRedistributionWithCore",
    "accessibilityAdaptation",
}

ACTION_LINES = {
    "0": ("成年伴侣角色举杯提醒喝水。", "An adult companion raises a glass as a hydration reminder."),
    "1": ("成年伴侣角色起身伸展。", "An adult companion stands and stretches."),
    "2": ("成年伴侣角色开心鼓掌。", "An adult companion applauds happily."),
    "3": ("成年伴侣角色兴奋地跳起。", "An adult companion jumps with excitement."),
    "4": ("成年伴侣角色轻快地转圈。", "An adult companion twirls playfully."),
    "5": ("成年伴侣角色开怀大笑。", "An adult companion laughs warmly."),
    "6": ("成年伴侣角色向镜头比心。", "An adult companion makes a heart gesture toward the viewer."),
    "7": ("成年伴侣角色向镜头送出飞吻。", "An adult companion blows a kiss toward the viewer."),
    "8": ("成年伴侣角色为工作中的用户加油。", "An adult companion offers an encouraging cheer."),
}

# These captions are declarations bound to the exact starter-media SHA-256
# inventory. They come from the accepted native-audiovisual review receipts;
# they do not claim a fresh ASR run during an offline build. Keeping them next
# to the bundled path prevents a direct click from being documented or routed
# as a clock/lifecycle reminder.
VIDEO_TRANSCRIPTS = {
    "companion-action-0.mov": (
        "老公，喝口水，照顾好自己我才放心呀。",
        "Have some water, honey. I feel better when you take care of yourself.",
    ),
    "companion-action-1.mov": (
        "起来伸个懒腰，陪我走几步，好不好？",
        "Stand up and stretch. Walk a few steps with me, okay?",
    ),
    "companion-action-2.mov": (
        "做得漂亮，这两下掌声只送给你。",
        "Beautifully done. This applause is just for you.",
    ),
    "companion-action-3.mov": (
        "抓到你啦，陪我跳一下！",
        "Got you! Jump with me!",
    ),
    "companion-action-4.mov": (
        "看好啦，我只为你转这一圈。",
        "Watch closely. This twirl is just for you.",
    ),
    "companion-action-5.mov": (
        "你一叫我，我就忍不住开心。",
        "Whenever you call me, I cannot help smiling.",
    ),
    "companion-action-6.mov": (
        "这颗心先放你那里，不许弄丢。",
        "Keep this heart for me. Do not lose it.",
    ),
    "companion-action-7.mov": (
        "靠近一点，奖励你一个飞吻。",
        "Come a little closer. Here is a kiss for you.",
    ),
    "companion-action-8.mov": (
        "再给你一点女朋友能量，加油呀。",
        "Here is a little more girlfriend energy. You have got this.",
    ),
    "companion-event-task_complete.mov": (
        "老公，任务完成啦，过来领你的奖励。",
        "Honey, the task is complete. Come claim your reward.",
    ),
    "companion-head-scene-kitchen.mov": (
        "来，张嘴，第一口给你。",
        "Come on, open up. The first bite is for you.",
    ),
    "companion-head-scene-bed.mov": (
        "别忙啦，过来，我给你留了位置。",
        "Stop working for a moment. Come here; I saved you a spot.",
    ),
    "companion-head-scene-workout.mov": (
        "别偷看，过来陪我练一组呀。",
        "Do not just peek. Come do a set with me.",
    ),
    "companion-head-scene-vanity.mov": (
        "等我一下，今晚漂亮给你看。",
        "Give me a moment. I am getting dressed up for you tonight.",
    ),
    "companion-scene-lunar-orbit.mov": (
        "地球太吵了，今晚陪我在月光里逃跑。",
        "Earth is too noisy. Escape into the moonlight with me tonight.",
    ),
    "companion-scene-undersea-room.mov": (
        "小声一点，整片海都在听我们说悄悄话。",
        "Keep your voice down. The whole ocean is listening to our secrets.",
    ),
    "companion-scene-time-cafe.mov": (
        "我把时间停住了，现在只准你看着我。",
        "I stopped time. Right now, you are only allowed to look at me.",
    ),
    "companion-scene-rain-portal.mov": (
        "下雨了，过来，我带你回家。",
        "It is raining. Come here; I will take you home.",
    ),
}

VISUAL_DESCRIPTIONS = {
    "companion-event-task_complete.mov": (
        "成年伴侣角色庆祝一次已确认完成的任务。",
        "An adult companion celebrates a confirmed completed task.",
    ),
    "companion-head-calm.mov": (
        "成年伴侣角色安静地陪在桌面一角。",
        "An adult companion rests calmly in a corner of the desktop.",
    ),
    "companion-head-curious.mov": (
        "成年伴侣角色好奇地看向用户。",
        "An adult companion looks toward the user with curiosity.",
    ),
    "companion-head-giggle.mov": (
        "成年伴侣角色俏皮地轻笑。",
        "An adult companion gives a playful giggle.",
    ),
    "companion-head-kiss.mov": (
        "成年伴侣角色送出轻松的飞吻。",
        "An adult companion gives a lighthearted blown kiss.",
    ),
    "companion-head-scene-bed.mov": (
        "成年伴侣角色在卧室场景中邀请用户结束工作休息。",
        "An adult companion in a bedroom scene invites the user to finish work and rest.",
    ),
    "companion-head-scene-kitchen.mov": (
        "成年伴侣角色在厨房品尝食物并与用户分享。",
        "An adult companion tastes food in a kitchen and shares the moment with the user.",
    ),
    "companion-head-scene-vanity.mov": (
        "成年伴侣角色在梳妆场景中整理造型。",
        "An adult companion gets ready at a vanity.",
    ),
    "companion-head-scene-workout.mov": (
        "成年伴侣角色在锻炼场景中邀请用户一起活动。",
        "An adult companion invites the user to join a workout.",
    ),
    "companion-idle-body.mov": (
        "成年伴侣角色以轻微自然动作安静待机。",
        "An adult companion idles with subtle natural movement.",
    ),
    "companion-master-landscape.mov": (
        "成年伴侣角色在横屏陪伴场景中自然活动。",
        "An adult companion moves naturally in a landscape companion scene.",
    ),
    "companion-scene-bedtime.mov": (
        "成年伴侣角色在晚间场景中提醒用户休息。",
        "An adult companion reminds the user to rest in an evening scene.",
    ),
    "companion-scene-lunar-orbit.mov": (
        "成年伴侣角色出现在月面轨道幻想场景。",
        "An adult companion appears in a lunar-orbit fantasy scene.",
    ),
    "companion-scene-moon-dance.mov": (
        "成年伴侣角色在月球幻想场景中跳舞。",
        "An adult companion dances in a moon fantasy scene.",
    ),
    "companion-scene-rain-portal.mov": (
        "成年伴侣角色在雨夜传送门场景中迎接用户。",
        "An adult companion welcomes the user in a rainy portal scene.",
    ),
    "companion-scene-time-cafe.mov": (
        "成年伴侣角色出现在时间静止的咖啡馆幻想场景。",
        "An adult companion appears in a time-frozen café fantasy scene.",
    ),
    "companion-scene-undersea-room.mov": (
        "成年伴侣角色出现在海底玻璃房幻想场景。",
        "An adult companion appears in an underwater glass-room fantasy scene.",
    ),
    "companion-action-states.png": (
        "成年伴侣角色动作状态参考图。",
        "A reference sheet of an adult companion's action states.",
    ),
    "companion-events-evening-alpha.png": (
        "成年伴侣角色的晚间透明背景状态图。",
        "A transparent-background evening pose for an adult companion.",
    ),
    "companion-events-satin-alpha.png": (
        "成年伴侣角色的缎面造型透明背景状态图。",
        "A transparent-background satin-look pose for an adult companion.",
    ),
    "companion-events-sport-alpha.png": (
        "成年伴侣角色的运动造型透明背景状态图。",
        "A transparent-background sport-look pose for an adult companion.",
    ),
    "companion-head-sprites-alpha.png": (
        "成年伴侣角色的迷你头像表情图集。",
        "A mini-avatar expression sheet for an adult companion.",
    ),
    "companion-live-sprites-alpha-v1.png": (
        "成年伴侣角色用于低动态待机的透明表情图集。",
        "A transparent expression sheet used for low-motion companion idling.",
    ),
    "companion-master-sheet.png": (
        "成年伴侣角色的全身造型参考图。",
        "A full-body visual reference sheet for an adult companion.",
    ),
    "dream-skin-wallpaper.png": (
        "应用使用的深色幻想背景图。",
        "A dark fantasy background used by the application.",
    ),
    "AppIcon.icns": (
        "澄音 Companion 应用图标。",
        "The Chengyin Companion application icon.",
    ),
}


class ManifestError(Exception):
    pass


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_id(path: str) -> str:
    value = re.sub(r"[^a-z0-9._-]+", "-", path.lower().replace("/", "."))
    return "starter." + value.strip(".-")


def review(status: str = "pending") -> dict[str, object]:
    return {"status": status, "reviewerID": None, "reviewedAt": None, "version": 1}


def nullable_localized(zh: str | None = None, en: str | None = None) -> dict[str, str | None]:
    return {"zh-Hans": zh, "en": en}


def kind_for(relative: str) -> str:
    suffix = pathlib.PurePosixPath(relative).suffix.lower()
    if suffix == ".mov":
        return "video"
    if suffix == ".mp3":
        return "speech"
    if suffix == ".wav":
        return "sound"
    if suffix == ".png":
        return "image"
    if suffix == ".icns":
        return "icon"
    if suffix == ".strings":
        return "localization"
    return "data"


def bundle_path_for(relative: str) -> str:
    parts = pathlib.PurePosixPath(relative).parts
    if parts and parts[0].endswith(".lproj"):
        return "/".join((parts[0].lower(), *parts[1:]))
    return pathlib.PurePosixPath(relative).name


def visual_description(relative: str) -> tuple[str | None, str | None]:
    name = pathlib.PurePosixPath(relative).name
    match = re.fullmatch(r"companion-action-([0-8])\.mov", name)
    if match:
        return ACTION_LINES[match.group(1)]
    return VISUAL_DESCRIPTIONS.get(name, (None, None))


def new_asset(
    relative: str,
    path: pathlib.Path,
    transcript: tuple[str | None, str | None] | None,
) -> dict[str, object]:
    kind = kind_for(relative)
    visual_zh, visual_en = visual_description(relative)
    source = {
        "video": "providerGeneratedVideo",
        "speech": "providerGeneratedSpeech",
        "sound": "repositoryExistingAudio",
        "image": "prototypeDerivative",
        "icon": "prototypeDerivative",
        "data": "repositoryAuthoredText",
        "localization": "repositoryAuthoredText",
    }[kind]
    provider = (
        "Volcengine Seedance" if kind == "video"
        else "Volcengine Seed-TTS 2.0" if kind == "speech"
        else None
    )
    adult_status = "unverified" if kind in {"video", "image", "icon"} else "notApplicable"
    if kind in {"data", "localization"}:
        accessibility_review = review("notApplicable")
    else:
        accessibility_review = review("pending")
    captions = transcript or (None, None)
    sound_description = (
        ("轻柔的心跳提示音。", "A soft heartbeat cue.")
        if kind == "sound"
        else (None, None)
    )
    fallback = (
        "staticSprite" if kind == "video"
        else "localizedText" if kind in {"speech", "sound"}
        else "systemSymbol" if kind in {"image", "icon"}
        else "builtInDefaults"
    )
    return {
        "id": safe_id(relative),
        "path": relative,
        "bundlePath": bundle_path_for(relative),
        "kind": kind,
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
        "provenance": {
            "source": source,
            "author": "Chengyin project" if kind in {"data", "localization"} else None,
            "provider": provider,
            "license": None,
            "authorizationBasis": None,
            "allowedUses": [],
            "attribution": {"required": None, "text": None},
            "adultFictionStatus": adult_status,
            "evidenceID": None,
            "review": review(),
        },
        "accessibility": {
            "altText": nullable_localized(visual_zh, visual_en),
            "captions": nullable_localized(*captions),
            "soundDescription": nullable_localized(*sound_description),
            "review": accessibility_review,
        },
        "fallback": fallback,
    }


def public_rights_ready(asset: dict[str, object]) -> bool:
    provenance = asset["provenance"]
    assert isinstance(provenance, dict)
    attribution = provenance.get("attribution")
    review_record = provenance.get("review")
    return bool(
        provenance.get("license")
        and provenance.get("authorizationBasis")
        and set(provenance.get("allowedUses", [])) >= PUBLIC_ALLOWED_USES
        and isinstance(attribution, dict)
        and attribution.get("required") is not None
        and provenance.get("adultFictionStatus") != "unverified"
        and isinstance(review_record, dict)
        and review_record.get("status") == "approved"
        and review_record.get("reviewerID")
        and review_record.get("reviewedAt")
    )


def accessibility_ready(asset: dict[str, object]) -> bool:
    kind = asset["kind"]
    accessibility = asset["accessibility"]
    assert isinstance(accessibility, dict)
    review_record = accessibility.get("review")
    if kind in {"data", "localization"}:
        return isinstance(review_record, dict) and review_record.get("status") == "notApplicable"
    if not (
        isinstance(review_record, dict)
        and review_record.get("status") == "approved"
        and review_record.get("reviewerID")
        and review_record.get("reviewedAt")
    ):
        return False
    if kind in {"video", "image", "icon"}:
        values = accessibility.get("altText")
    elif kind == "speech":
        values = accessibility.get("captions")
    else:
        values = accessibility.get("soundDescription")
    return isinstance(values, dict) and all(values.get(locale) for locale in ("zh-Hans", "en"))


def load_voice_transcripts(resources: pathlib.Path) -> dict[str, tuple[str | None, str | None]]:
    path = resources / "voice-lines.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    result: dict[str, tuple[str | None, str | None]] = {}
    for record in data:
        audio_file = record.get("audioFile")
        text = record.get("text")
        if isinstance(audio_file, str) and isinstance(text, str):
            result[f"Audio/{audio_file}"] = (text, None)
    return result


def load_existing(path: pathlib.Path) -> dict[str, object] | None:
    if not path.is_file():
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    return data if isinstance(data, dict) else None


def build_manifest(resources: pathlib.Path, existing: dict[str, object] | None) -> dict[str, object]:
    if not resources.is_dir() or resources.is_symlink():
        raise ManifestError("resources root is missing or unsafe")
    transcripts = load_voice_transcripts(resources)
    previous_assets = {
        item.get("path"): item
        for item in (existing or {}).get("assets", [])
        if isinstance(item, dict) and isinstance(item.get("path"), str)
    }
    paths: list[pathlib.Path] = []
    for path in resources.rglob("*"):
        if path.is_symlink():
            raise ManifestError("resources contain a symbolic link")
        if not path.is_file() or path.name == MANIFEST_NAME:
            continue
        relative = path.relative_to(resources).as_posix()
        if any(part.startswith(".") for part in pathlib.PurePosixPath(relative).parts):
            raise ManifestError("resources contain hidden metadata")
        if path.suffix.lower() not in ALLOWED_SUFFIXES:
            raise ManifestError(f"resources contain an undeclared file type: {relative}")
        paths.append(path)
    if not paths:
        raise ManifestError("resources contain no shippable assets")

    assets: list[dict[str, object]] = []
    bundle_paths: set[str] = set()
    for path in sorted(paths, key=lambda value: value.relative_to(resources).as_posix()):
        relative = path.relative_to(resources).as_posix()
        declared_transcript = transcripts.get(relative)
        if declared_transcript is None:
            declared_transcript = VIDEO_TRANSCRIPTS.get(
                pathlib.PurePosixPath(relative).name
            )
        fresh = new_asset(relative, path, declared_transcript)
        previous = previous_assets.get(relative)
        if isinstance(previous, dict) and previous.get("sha256") == fresh["sha256"]:
            for field in ("provenance", "accessibility", "fallback"):
                if field in previous:
                    fresh[field] = previous[field]
            if isinstance(previous.get("id"), str):
                fresh["id"] = previous["id"]
        if declared_transcript is not None:
            accessibility = fresh.get("accessibility")
            if isinstance(accessibility, dict):
                accessibility["captions"] = nullable_localized(
                    *declared_transcript
                )
        bundle_path = str(fresh["bundlePath"])
        if bundle_path.casefold() in bundle_paths:
            raise ManifestError(f"resources collide after bundle flattening: {bundle_path}")
        bundle_paths.add(bundle_path.casefold())
        assets.append(fresh)

    version_path = ROOT / "Info.plist"
    with version_path.open("rb") as stream:
        version = str(plistlib.load(stream)["CFBundleShortVersionString"])
    previous_license = (existing or {}).get("license")
    previous_license_review = (existing or {}).get("licenseReview")
    license_review = (
        previous_license_review
        if isinstance(previous_license_review, dict)
        else review()
    )
    rights_ready = all(public_rights_ready(asset) for asset in assets)
    accessibility_complete = all(accessibility_ready(asset) for asset in assets)
    license_ready = bool(
        previous_license
        and license_review.get("status") == "approved"
        and license_review.get("reviewerID")
        and license_review.get("reviewedAt")
    )
    public_ready = rights_ready and accessibility_complete and license_ready
    return {
        "schemaVersion": 1,
        "contract": "chengyin.starter-media/v1",
        "packID": "cc.chengyin.builtin-starter",
        "version": version,
        "distributionClass": "publicCandidate" if public_ready else "internalPreview",
        "providerCredentialsRequiredAtBuild": False,
        "license": previous_license if isinstance(previous_license, str) else None,
        "licenseReview": license_review,
        "rightsConclusion": "approved" if rights_ready else "pending",
        "accessibilityConclusion": "approved" if accessibility_complete else "pending",
        "publicDistributionReady": public_ready,
        "privacy": {
            "containsAPIKeys": False,
            "containsTaskContent": False,
            "containsPersonalPaths": False,
            "networkRequiredAtRuntime": False,
        },
        "fallback": {
            "strategy": "localizedTextStaticSpriteAndAudioOnly",
            "worksWithoutProvider": True,
        },
        "assets": assets,
    }


def encoded(manifest: dict[str, object]) -> bytes:
    return (json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--resources", type=pathlib.Path, default=DEFAULT_RESOURCES)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    resources = args.resources.resolve()
    manifest_path = resources / MANIFEST_NAME
    try:
        existing = load_existing(manifest_path)
        desired = encoded(build_manifest(resources, existing))
    except (OSError, ValueError, KeyError, json.JSONDecodeError, ManifestError) as error:
        print(f"FAIL  [STARTER_MEDIA_CONTRACT_INVALID] {error}", file=sys.stderr)
        print("ACTION  Restore a clean resource tree and rerun the Starter manifest tool.", file=sys.stderr)
        return 1
    if args.check:
        try:
            current = manifest_path.read_bytes()
        except OSError:
            print("FAIL  [STARTER_MEDIA_MANIFEST_MISSING] The Starter manifest is missing.", file=sys.stderr)
            print("ACTION  Run refresh-starter-media-manifest.py --write and review every pending field.", file=sys.stderr)
            return 1
        if current != desired:
            print("FAIL  [STARTER_MEDIA_INVENTORY_MISMATCH] The Starter manifest is stale.", file=sys.stderr)
            print("ACTION  Refresh the manifest; changed assets return to pending review.", file=sys.stderr)
            return 1
        print("Starter media manifest: CURRENT")
        return 0
    temporary_fd, temporary_name = tempfile.mkstemp(
        prefix=".starter-media.", suffix=".json", dir=resources
    )
    try:
        with os.fdopen(temporary_fd, "wb") as stream:
            stream.write(desired)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_name, manifest_path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)
    print(f"Starter media manifest: WROTE {len(desired)} bytes")
    print("Rights and accessibility remain pending unless explicit reviewed evidence is present.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
