#!/usr/bin/env python3
"""Keep content-free microgame policy wired without hidden persistence."""

from __future__ import annotations

import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def fail(message: str) -> None:
    print(f"FAIL  microgame integration: {message}", file=sys.stderr)
    raise SystemExit(1)


def source(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file() or path.is_symlink():
        fail(f"required regular source is missing: {relative}")
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        fail(f"required source is unreadable UTF-8: {relative}")


core = source("Sources/CompanionContracts/CompanionMicrogameSession.swift")
completion_policy = source(
    "Sources/CompanionContracts/CompanionMicrogameCompletionPolicy.swift"
)
runtime = source(
    "Sources/CompanionApp/CompanionMicrogameRuntimeCoordinator.swift"
)
presentation = source(
    "Sources/CompanionApp/CompanionMicrogamePresentation.swift"
)
completion_presentation = source(
    "Sources/CompanionApp/CompanionMicrogameCompletionPresentation.swift"
)
view_model = source("Sources/CompanionApp/CompanionViewModel.swift")
content_view = source("Sources/CompanionApp/ContentView.swift")
preferences = source("Sources/CompanionApp/CompanionPresentationPreferences.swift")
diagnostics = source("Sources/CompanionApp/CompanionDiagnostics.swift")
backup = source("Sources/CompanionContracts/CompanionBackup.swift")
compatibility = source("docs/COMPATIBILITY.md")
doctor = source("scripts/doctor.sh")
ci = source(".github/workflows/ci.yml")
portable = source("scripts/run-portable-source-smoke.sh")

for claim in (
    "public struct CompanionMicrogameSession: Equatable, Sendable",
    "public mutating func start(",
    "public mutating func tick()",
    "public mutating func end()",
    "registerCatch",
    "registerHideFind",
    "registerComboGesture",
    "registerHeartPoint",
    "registerRhythmTap",
    "registerFeedSuccess",
):
    if claim not in core:
        fail(f"Core microgame contract lost {claim}")

if re.search(r"CompanionMicrogameSession\s*:\s*[^\n{]*Codable", core):
    fail("ephemeral microgame session became persistable")

for claim in (
    "public enum CompanionMicrogameCompletionMood",
    "public enum CompanionMicrogameRewardBeat",
    "public struct CompanionMicrogameRelationshipReward",
    "public struct CompanionMicrogameCompletionPlan",
    "public struct CompanionMicrogameCompletionPolicy",
    "public func plan(",
    "restoreImmediately: true",
    "relationshipReward: nil",
):
    if claim not in completion_policy:
        fail(f"Core microgame completion policy lost {claim}")

for forbidden in (
    "import AppKit",
    "import SwiftUI",
    "UserDefaults",
    "VoicePackPlayer",
    "NSHapticFeedbackManager",
    "NSWindow",
    "Task {",
):
    if forbidden in completion_policy:
        fail(f"Core completion policy gained a platform side effect: {forbidden}")

for claim in (
    "final class CompanionMicrogameRuntimeCoordinator: ObservableObject",
    "@Published private(set) var session = CompanionMicrogameSession()",
    "private var timelineTask: Task<Void, Never>?",
    "func begin(",
    "func startCountdown(",
    "func startRhythmTimeline(",
    "func end(",
    "CompanionMicrogameReturnContext",
):
    if claim not in runtime:
        fail(f"focused runtime coordinator lost {claim}")

for forbidden in (
    "import AppKit",
    "UserDefaults.",
    "VoicePackPlayer",
    "NSHapticFeedbackManager",
    "CompanionRelationshipState",
):
    if forbidden in runtime:
        fail(f"runtime coordinator gained presentation or persistence API: {forbidden}")

for claim in (
    "enum CompanionMicrogamePresentation",
    "static func hudText(for session: CompanionMicrogameSession)",
    "extension CompanionViewModel",
    "CompanionMicrogamePresentation.hudText(for: microgameSession)",
    "var activePetGameHUDText: String",
    "var petGameActive: Bool",
    '"game.hud.feed"',
    '"game.hud.rhythm"',
    '"game.hud.heart"',
    '"game.hud.comboSteps"',
    '"game.hud.hide"',
    '"game.hud.catch"',
):
    if claim not in presentation:
        fail(f"focused presentation projection lost {claim}")

for forbidden in (
    "import AppKit",
    "import SwiftUI",
    "UserDefaults",
    "VoicePackPlayer",
    "NSHapticFeedbackManager",
    "CGEvent",
    "NSWindow",
    "Task {",
    "microgameRuntime",
):
    if forbidden in presentation:
        fail(f"presentation projection gained a side effect: {forbidden}")

for claim in (
    "enum CompanionMicrogameCompletionPresenter",
    "static func presentation(",
    "for plan: CompanionMicrogameCompletionPlan",
    "allowsRomanticGestures: Bool",
    "case .adaptiveAffection",
    'text("status.game.catch.complete"',
    'text("status.game.feed.ended"',
):
    if claim not in completion_presentation:
        fail(f"completion presentation projection lost {claim}")

for forbidden in (
    "import AppKit",
    "import SwiftUI",
    "UserDefaults",
    "VoicePackPlayer",
    "NSHapticFeedbackManager",
    "NSWindow",
    "Task {",
    "microgameRuntime",
):
    if forbidden in completion_presentation:
        fail(f"completion presentation gained a side effect: {forbidden}")

for forbidden in (
    "var activePetGameHUDText",
    '"game.hud.feed"',
    '"game.hud.comboSteps"',
):
    if forbidden in view_model:
        fail(f"read-only HUD projection returned to the view model: {forbidden}")

if "private let microgameRuntime = CompanionMicrogameRuntimeCoordinator()" not in view_model:
    fail("App no longer owns one focused microgame runtime")
if "microgameRuntime.objectWillChange.sink" not in view_model:
    fail("App no longer observes focused runtime changes")
if "allowsWindowDrag: !viewModel.heartTraceGameActive" not in content_view:
    fail("heart tracing can move its own coordinate space instead of drawing")

for game in ("catchPet", "hideAndSeek", "gestureCombo", "heartTrace", "rhythm", "feed"):
    if f".{game},\n                returnMode:" not in view_model:
        fail(f"App runtime start path lost {game}")

for call in (
    "microgameRuntime.startCountdown",
    "microgameRuntime.startRhythmTimeline",
    "microgameRuntime.registerCatch",
    "microgameRuntime.registerHideFind",
    "microgameRuntime.registerComboGesture",
    "microgameRuntime.registerHeartPoint",
    "microgameRuntime.registerRhythmTap",
    "microgameRuntime.registerFeedSuccess",
    "microgameRuntime.end(expectedGame:",
):
    if call not in view_model:
        fail(f"App binding lost {call}")

for claim in (
    "private func finishMicrogame(",
    "CompanionMicrogameCompletionPolicy().plan(",
    "CompanionMicrogameCompletionPresenter.presentation(",
    "cleanUpMicrogamePresentation(game)",
):
    if claim not in view_model:
        fail(f"unified completion binding lost {claim}")

for duplicated_policy in (
    '"game.catch.won"',
    '"game.hide.won"',
    '"game.combo.won"',
    '"game.trace.won"',
    '"game.rhythm.won"',
    '"game.feed.won"',
    '"status.game.catch.complete"',
    '"status.game.feed.ended"',
):
    if duplicated_policy in view_model:
        fail(f"microgame completion policy returned to the view model: {duplicated_policy}")

for forbidden in (
    "@Published private var microgameSession",
    "microgameSession.start(",
    "microgameSession.tick()",
    "microgameSession.end()",
    "catchGameTask",
    "hideGameTask",
    "comboGameTask",
    "heartTraceGameTask",
    "rhythmGameTask",
    "feedGameTask",
    "catchGameReturnMode",
    "hideGameReturnMode",
    "comboGameReturnMode",
    "heartTraceGameReturnMode",
    "rhythmGameReturnMode",
    "feedGameReturnMode",
):
    if forbidden in view_model:
        fail(f"parallel runtime ownership returned to the view model: {forbidden}")

legacy_published = re.findall(
    r"@Published\s+(?:private\(set\)\s+)?var\s+"
    r"((?:catch|hide|combo|heartTrace|rhythm|feed)Game(?:Active|Score|Combo|Step|SecondsRemaining))\b",
    view_model,
)
if legacy_published:
    fail(f"parallel mutable game fields returned: {', '.join(sorted(legacy_published))}")

allowed_persisted_keys = {
    "chengyin.pet.catch-game.best-score",
    "chengyin.pet.hide-game.best-score",
}
observed_game_keys = set(
    re.findall(r'"(chengyin\.[^"]*(?:game|microgame)[^"]*)"', preferences)
)
if observed_game_keys != allowed_persisted_keys:
    fail("game persistence is not limited to the two compatible best-score keys")

for forbidden_surface, text in (
    ("diagnostics", diagnostics),
    ("portable backup", backup),
):
    if "microgameSession" in text or "CompanionMicrogameSession" in text:
        fail(f"ephemeral microgame session leaked into {forbidden_surface}")

for phrase in (
    "ephemeral Core session",
    "never enter backup or diagnostics",
    "Existing catch/hide best-score preference keys remain compatible",
):
    if phrase not in compatibility:
        fail(f"compatibility boundary lost: {phrase}")

for surface_name, text in (
    ("doctor", doctor),
    ("CI", ci),
    ("portable source smoke", portable),
):
    if "run-microgame-runtime-coordinator-smoke.sh" not in text:
        fail(f"runtime behavior smoke is not wired into {surface_name}")

print(
    "PASS  microgame integration: six Core-driven games, one focused cancellable "
    "runtime, one deterministic debt-free completion policy, side-effect-free localized "
    "presentation projections, exact return context, compatible best scores, no backup "
    "or diagnostic state"
)
