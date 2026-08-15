#!/usr/bin/env python3
"""Keep direct-play presentation policy wired into the App composition."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
VIEW_MODEL = ROOT / "Sources/CompanionApp/CompanionViewModel.swift"
CONTROLS = ROOT / "Sources/CompanionApp/CompanionPlayControls.swift"
CONTENT_VIEW = ROOT / "Sources/CompanionApp/ContentView.swift"
COMPANION_APP = ROOT / "Sources/CompanionApp/CompanionApp.swift"
PREFERENCES = ROOT / "Sources/CompanionApp/CompanionPresentationPreferences.swift"
PREFERENCE_STORE = ROOT / "Sources/CompanionApp/CompanionPreferenceStore.swift"
SESSION = ROOT / "Sources/CompanionContracts/CompanionPresentationSession.swift"
LIFECYCLE = ROOT / "Sources/CompanionContracts/CompanionPresentationLifecycle.swift"
PRESENTATION_RUNTIME = ROOT / "Sources/CompanionApp/CompanionPresentationRuntimeCoordinator.swift"
WINDOW_RUNTIME_AUDIT = ROOT / "scripts/direct-play-window-audit.swift"
DIRECT_PLAY_RUNTIME_AUDIT = ROOT / "scripts/audit-direct-play-runtime.py"
CATCH_GAME_AUDIT = ROOT / "scripts/catch-game-smoke.swift"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL  direct-play integration: {message}")


def main() -> None:
    view_model = VIEW_MODEL.read_text(encoding="utf-8")
    controls = CONTROLS.read_text(encoding="utf-8")
    content_view = CONTENT_VIEW.read_text(encoding="utf-8")
    companion_app = COMPANION_APP.read_text(encoding="utf-8")
    preferences = PREFERENCES.read_text(encoding="utf-8")
    preference_store = PREFERENCE_STORE.read_text(encoding="utf-8")
    session = SESSION.read_text(encoding="utf-8")
    lifecycle = LIFECYCLE.read_text(encoding="utf-8")
    presentation_runtime = PRESENTATION_RUNTIME.read_text(encoding="utf-8")
    microgame_completion = (
        ROOT / "Sources/CompanionContracts/CompanionMicrogameCompletionPolicy.swift"
    ).read_text(encoding="utf-8")
    microgame_completion_presentation = (
        ROOT / "Sources/CompanionApp/CompanionMicrogameCompletionPresentation.swift"
    ).read_text(encoding="utf-8")
    chemistry = (ROOT / "Sources/CompanionContracts/CompanionChemistryInteractionDirector.swift").read_text(
        encoding="utf-8"
    )
    drag_policy = (ROOT / "Sources/CompanionContracts/CompanionPetDragPolicy.swift").read_text(
        encoding="utf-8"
    )
    drag_presentation = (ROOT / "Sources/CompanionApp/CompanionPetDragPresentation.swift").read_text(
        encoding="utf-8"
    )
    window_runtime = WINDOW_RUNTIME_AUDIT.read_text(encoding="utf-8")
    direct_runtime = DIRECT_PLAY_RUNTIME_AUDIT.read_text(encoding="utf-8")
    catch_game = CATCH_GAME_AUDIT.read_text(encoding="utf-8")

    if "keepsHeadPresentation" in view_model:
        fail("a Codex-working shortcut can still suppress direct expansion")
    if view_model.count("presentationIntent: .petInteraction") < 3:
        fail("single, double, or long-press play is not bound to pet interaction")
    if view_model.count("presentationIntent: .gameReward") != 2:
        fail("the unified action and mini-scene reward handoffs are incomplete")
    for game in (
        "catchPet",
        "hideAndSeek",
        "gestureCombo",
        "heartTrace",
        "rhythm",
        "feed",
    ):
        if f"case .{game}:" not in microgame_completion:
            fail(f"the Core completion policy lost the {game} reward plan")
    for beat in (
        "cheer",
        "adaptiveAffection",
        "twirl",
        "heart",
        "jump",
        "kitchen",
    ):
        if f"case .{beat}:" not in microgame_completion_presentation:
            fail(f"the localized completion projection lost the {beat} reward handoff")
    for claim in (
        "presentationRuntime.beginContentSequence(",
        "presentationRuntime.beginAutomaticResponse(",
        "continuesIntoFallback: fallback != nil",
        "presentationPlan: userPresentationPlan(for: presentationIntent)",
    ):
        if claim not in view_model:
            fail("direct-play expansion or seamless fallback ownership is not wired")
    if "activeContentSequenceOverridesReturnPolicy" in view_model:
        fail("direct-play ownership regressed to an unverified App-layer boolean")
    for claim in (
        "public struct CompanionPresentationSession",
        "beginDirectUserPlan",
        "guard !directUserOwnsReturn else { return }",
        "continuesIntoFallback",
    ):
        if claim not in session:
            fail("the pure presentation-session contract is incomplete")
    for claim in (
        "public struct CompanionPresentationLifecycle",
        "beginAutomaticResponse",
        "beginContentSequence",
        "keepsMediaInPet",
        "session.directUserOwnsReturn",
    ):
        if claim not in lifecycle:
            fail("the shared click/palette/game/automatic lifecycle is incomplete")
    if "CompanionPresentationSession()" in view_model:
        fail("the App bypasses the shared presentation lifecycle")
    if "presentationLifecycle" in view_model or "userPresentationPolicy" in view_model:
        fail("the view model regained direct presentation-lifecycle ownership")
    for claim in (
        "struct CompanionPresentationRuntimeCoordinator",
        "private let userPolicy = CompanionUserPresentationPolicy()",
        "private var lifecycle = CompanionPresentationLifecycle()",
        "func beginDirectUserPlan(",
        "func beginAutomaticResponse(",
        "func beginContentSequence(",
        "func commitGameReward(",
        "func finish(",
        "func reset()",
    ):
        if claim not in presentation_runtime:
            fail("the focused presentation runtime coordinator is incomplete")
    reward_presentation = (ROOT / "Sources/CompanionApp/CompanionGameRewardPresentation.swift").read_text(encoding="utf-8")
    if view_model.count("commitGameRewardPresentation(") != 1:
        fail("game wins bypass the single fullscreen and exact-restoration commit")
    for claim in (
        "func commitGameRewardPresentation(",
        "presentationRuntime.commitGameReward(",
        "applyPresentationDirective(directive)",
    ):
        if claim not in reward_presentation:
            fail("the shared game-reward fullscreen commit is incomplete")

    palette_start = controls.find("struct ActionPlayMenu")
    palette_end = controls.find("private struct CompanionPlayPalette", palette_start)
    if palette_start < 0 or palette_end < 0:
        fail("the magic-wand palette boundary is missing")
    if "Menu {" in controls[palette_start:palette_end]:
        fail("the magic wand regressed to a screen-edge system menu")
    for claim in (
        "struct CompanionPlayPaletteOverlay",
        "viewModel.playPalettePresented = false",
        "NSApp.activate(ignoringOtherApps: true)",
        "NSApp.deactivate()",
        ".pickerStyle(.segmented)",
        "LazyVGrid(columns: columns",
        "let layout: CompanionPlayPaletteLayoutPlan",
        "count: layout.columnCount",
        "maxWidth: layout.maximumPaletteWidth",
        "maxHeight: layout.contentSize.height - 20",
        "layout.showsReturnHint",
        "layout.usesCompactFooter",
    ):
        if claim not in controls:
            fail("the bounded upward magic-wand palette lost its layout contract")
    if "ScrollView" in controls:
        fail("the magic-wand palette requires scrolling again")
    if "CompanionPlayPaletteLayout.plan(visibleFrame: presentationVisibleFrame)" not in content_view:
        fail("the SwiftUI palette no longer consumes the shared adaptive layout plan")
    window_policy = (ROOT / "Sources/CompanionContracts/CompanionWindowPolicy.swift").read_text(encoding="utf-8")
    if "CompanionPlayPaletteLayout.plan(" not in window_policy or "playPaletteContentSize" not in companion_app:
        fail("the palette window and SwiftUI root no longer share bounded geometry")
    microgame_window_policy = (
        ROOT / "Sources/CompanionContracts/CompanionMicrogameWindowPolicy.swift"
    ).read_text(encoding="utf-8")
    for claim in (
        "public static func catchPlacement(",
        "public static func hidePlacement(",
        "catchPointerClearance",
        "horizontalPeekExtent",
        "verticalPeekExtent",
    ):
        if claim not in microgame_window_policy:
            fail("catch or hide play lost bounded selected-display geometry")
    for claim in (
        "CompanionMicrogameWindowPolicy.catchPlacement(",
        "CompanionMicrogameWindowPolicy.hidePlacement(",
        "previousEdge: hideGameLastEdge",
    ):
        if claim not in view_model:
            fail("AppKit play bypasses the deterministic microgame window policy")
    for claim in (
        "configurationGeneration",
        "view.window ?? coordinator.window",
        "coordinator.configurationGeneration == generation",
        "attemptsRemaining: 3",
        "startPanelGeometryRecovery()",
        "repairPanelGeometryIfNeeded(",
        "CompanionWindowPolicy.geometryRecoveryFrame(",
        "panelGeometryGeneration == generation",
    ):
        if claim not in companion_app:
            fail("window replacement can still strand direct play in a pet-sized frame")
    if "discardPending(source: .proactiveCare)" not in view_model:
        fail("explicit play can still replay a stale time or care cue")
    for key, label in (
        ("play.category.games", "小游戏"),
        ("play.category.miniScenes", "迷你生活"),
        ("play.category.fantasy", "幻想场景"),
        ("play.category.actions", "互动动作"),
    ):
        if f'"{key}"' not in controls or f'"{label}"' not in controls:
            fail("a bounded magic-wand category is missing")
    if "当前是仅声音模式，点这里恢复动作画面" not in controls:
        fail("audio-only mode has no visible recovery action")
    palette_body_start = controls.find("private struct CompanionPlayPalette")
    palette_picker = controls.find("Picker(", palette_body_start)
    restore_video = controls.find(
        '"chengyin.play-palette-restore-video"',
        palette_body_start,
    )
    if not (palette_body_start < restore_video < palette_picker):
        fail("audio-only recovery is no longer compactly contained in the palette header")
    palette_button = controls.find("private func paletteButton(", palette_body_start)
    action_call = controls.find("action()", palette_button)
    dismiss_call = controls.find("dismiss()", palette_button)
    if not (palette_button < action_call < dismiss_call):
        fail("palette selection can shrink the pet before starting its visual response")
    if "playPalettePresented" not in content_view:
        fail("the avatar toolbar can disappear while its palette is open")
    if ".allowsHitTesting(compactHover || viewModel.playPalettePresented)" in content_view:
        fail("the avatar toolbar is still gated behind a hover race")
    if "viewModel.togglePlaybackMode()" in controls:
        fail("the playback icon can still change mode through one accidental click")
    if controls.count("viewModel.setPlaybackMode(") < 3:
        fail("explicit audiovisual/audio-only choices are incomplete")
    if "playbackSelectionContractVersion" not in preferences:
        fail("legacy one-click audio-only state has no migration marker")
    for claim in (
        "storedContractVersion < Self.playbackSelectionContractVersion",
        "? CompanionPlaybackMode.audioVisual",
        "markPlaybackSelectionCurrent()",
    ):
        if claim not in preference_store:
            fail("legacy ambiguous audio-only state is not migrated once")
    if "let savedPreferences = preferenceStore.load().snapshot" not in view_model:
        fail("App composition bypasses the focused preference migration receipt")
    for forbidden_recipe in (
        ".drink, .singleTap",
        ".stretch, .singleTap",
        ".workout, .doubleTap",
        ".timeCafe, .doubleTap",
    ):
        if forbidden_recipe in chemistry:
            fail("direct taps can still impersonate a scheduled-care or time cue")
    surprise = (ROOT / "Sources/CompanionContracts/CompanionDirectSurprisePolicy.swift").read_text(encoding="utf-8")
    for forbidden in (".drink", ".stretch", ".timeCafe"):
        if forbidden in surprise.split("forbidden", 1)[0]:
            fail("the direct surprise palette can impersonate scheduled care or time")

    for feedback in ("fling", "dock", "lift", "nudge", "settle"):
        if f"case {feedback}" not in drag_policy and f"case .{feedback}:" not in drag_presentation:
            fail(f"direct manipulation lost the {feedback} feedback path")
    for claim in (
        "public enum CompanionPetDragPolicy",
        "flingSpeedThreshold = 900.0",
        "movedDistanceThreshold = 24.0",
        "liftDistanceThreshold = 70.0",
        "guard value.isFinite else { return 0 }",
    ):
        if claim not in drag_policy:
            fail("the bounded Core drag policy is incomplete")
    for claim in (
        "CompanionPetDragPolicy.plan(",
        "CompanionPetDragPresentation.presentation(",
        "recordRelationshipMoment(dragPlan.relationshipMomentKey)",
        "schedulePoseReset(after: dragPlan.poseResetDelay)",
    ):
        if claim not in view_model:
            fail("drag and fling feedback bypasses the shared semantic plan")
    for claim in (
        "switch plan.feedback",
        "effect.pet.flingDock",
        "effect.pet.docked",
        "effect.pet.lift",
        "effect.pet.nudge",
        "effect.pet.settle",
    ):
        if claim not in drag_presentation:
            fail("the localized drag projection is incomplete")

    for claim in (
        'contract = "chengyin.direct-play-window/v1"',
        'status: "PENDING"',
        "(410...430).contains(bounds.height)",
        "paletteFullyVisible: true",
        "singleClickExpanded",
        "actionExpanded",
        "UI_DIRECT_PLAY_PALETTE_CLIPPED",
        "UI_DIRECT_PLAY_GUI_SESSION_LOCKED",
        "UI_DIRECT_PLAY_RESTORATION_FAILED",
    ):
        if claim not in window_runtime:
            fail("the real direct-play window receipt lost a required proof")
    for claim in (
        '"chengyin.direct-play-runtime/v1"',
        "def pending(",
        '"status": "PENDING"',
        'window_exit == 2 and window_receipt.get("status") == "PENDING"',
        "audit-local-runtime-identity.py",
        "direct-play-window-audit.swift",
        "catch-game-smoke.swift",
        "UI_DIRECT_PLAY_REWARD_FAILED",
        '"releaseState": "NOT_PUBLIC_RELEASE_READY"',
    ):
        if claim not in direct_runtime:
            fail("the path-safe live direct-play audit is incomplete")
    for claim in (
        "NSScreen.screens.map(\\.visibleFrame)",
        "fullscreenReward.width >= visible.width * 0.80",
        "fullscreenReward.height >= visible.height * 0.80",
        'restored["width"] * restored["height"] * 20',
    ):
        if claim not in catch_game + direct_runtime:
            fail("the game reward audit can mistake an ordinary window for fullscreen")
    if "/Users/" in window_runtime or "/Users/" in direct_runtime:
        fail("the direct-play audit embeds a private user path")

    print(
        "PASS  direct-play integration: 3 pet gestures, 6 Core-planned fullscreen rewards, "
        "4 non-scrolling in-window palette tabs, seamless media fallback, "
        "shared direct/automatic lifecycle, legacy audio-only recovery, "
        "reminder-free tap responses, bounded five-way drag feedback, "
        "path-safe live click/palette/reward receipts"
    )


if __name__ == "__main__":
    main()
