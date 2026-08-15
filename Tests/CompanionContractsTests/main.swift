import CompanionContracts
import Darwin
import Foundation

private struct CheckFailure: Error {
    let message: String
}

private actor CheckReporter {
    private var passed = 0
    private var failed = 0

    func pass(_ name: String) {
        passed += 1
        print("PASS  \(name)")
    }

    func fail(_ name: String, _ error: Error) {
        failed += 1
        print("FAIL  \(name): \(error)")
    }

    func result() -> (passed: Int, failed: Int) {
        (passed, failed)
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
        throw CheckFailure(message: message)
    }
}

private func requireError(
    _ expected: CompanionEventValidationError,
    operation: () throws -> Void
) throws {
    do {
        try operation()
    } catch let error as CompanionEventValidationError {
        try require(error == expected, "Expected \(expected), received \(error)")
        return
    }
    throw CheckFailure(message: "Expected \(expected), but the operation succeeded")
}

private func requireRelationshipError(
    _ expected: CompanionRelationshipStateValidationError,
    operation: () throws -> Void
) throws {
    do {
        try operation()
    } catch let error as CompanionRelationshipStateValidationError {
        try require(error == expected, "Expected \(expected), received \(error)")
        return
    }
    throw CheckFailure(message: "Expected \(expected), but the operation succeeded")
}

private func requireWorkdayError(
    _ expected: CompanionWorkdayStateValidationError,
    operation: () throws -> Void
) throws {
    do {
        try operation()
    } catch let error as CompanionWorkdayStateValidationError {
        try require(error == expected, "Expected \(expected), received \(error)")
        return
    }
    throw CheckFailure(message: "Expected \(expected), but the operation succeeded")
}

private func requireLifestyleMemoryError(
    _ expected: CompanionLifestyleMemoryValidationError,
    operation: () throws -> Void
) throws {
    do {
        try operation()
    } catch let error as CompanionLifestyleMemoryValidationError {
        try require(error == expected, "Expected \(expected), received \(error)")
        return
    }
    throw CheckFailure(message: "Expected \(expected), but the operation succeeded")
}

@main
private struct CompanionContractChecks {
    static func main() async {
        let reporter = CheckReporter()

        await run("Task completion round-trip", reporter: reporter) {
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let event = CompanionEvent(
                eventId: "14F77E82-862D-48D4-82CB-F2938A28BC10",
                source: "codex",
                sourceVersion: "1.0",
                type: .taskCompleted,
                taskRef: "opaque-task-1",
                occurredAt: now,
                durationMs: 42_000,
                outcome: .success,
                metadata: ["completion_count": "1"]
            )
            let encoded = try CompanionEventCodec.encode(event, now: now)
            let decoded = try CompanionEventCodec.decode(encoded, now: now)
            try require(decoded == event, "Decoded event differs from the original")
        }

        await run("Private payload rejection", reporter: reporter) {
            let event = CompanionEvent(
                source: "codex",
                type: .taskCompleted,
                privacy: CompanionEventPrivacy(containsCode: true)
            )
            try requireError(.privatePayloadNotAllowed) {
                _ = try CompanionEventCodec.encode(event)
            }
        }

        await run("Protocol major version rejection", reporter: reporter) {
            let event = CompanionEvent(
                protocolVersion: "2.0",
                source: "codex",
                type: .taskCompleted
            )
            try requireError(.unsupportedProtocolVersion) {
                _ = try CompanionEventCodec.encode(event)
            }
        }

        await run("Invalid event ID rejection", reporter: reporter) {
            let event = CompanionEvent(
                eventId: "not-a-uuid",
                source: "codex",
                type: .taskCompleted
            )
            try requireError(.invalidEventId) {
                _ = try CompanionEventCodec.encode(event)
            }
        }

        await run("Oversized payload rejection", reporter: reporter) {
            let data = Data(repeating: 0x20, count: CompanionEventCodec.maximumPayloadBytes + 1)
            try requireError(.payloadTooLarge) {
                _ = try CompanionEventCodec.decode(data)
            }
        }

        await run("Metadata entry limit", reporter: reporter) {
            let metadata = Dictionary(
                uniqueKeysWithValues: (0...CompanionEventCodec.maximumMetadataEntries).map {
                    ("key_\($0)", "value")
                }
            )
            let event = CompanionEvent(
                source: "codex",
                type: .taskCompleted,
                metadata: metadata
            )
            try requireError(.tooManyMetadataEntries) {
                _ = try CompanionEventCodec.encode(event)
            }
        }

        await run("Event deduplication and eviction", reporter: reporter) {
            let deduplicator = CompanionEventDeduplicator(capacity: 2)
            try await requireAsync(await deduplicator.insertIfNew("event-1"), "First insert failed")
            try await requireAsync(!(await deduplicator.insertIfNew("event-1")), "Duplicate was accepted")
            try await requireAsync(await deduplicator.insertIfNew("event-2"), "Second insert failed")
            try await requireAsync(await deduplicator.insertIfNew("event-3"), "Third insert failed")
            try await requireAsync(await deduplicator.insertIfNew("event-1"), "Evicted ID was not accepted")
        }

        await run("Settings defaults and JSON round-trip", reporter: reporter) {
            let original = CompanionSettingsV1(
                personaId: "starter.c03",
                relationshipTone: .playfulSpark,
                locale: "zh-Hans",
                presentationMode: .stage,
                presentationAppearance: .cinematic,
                displayTarget: .specific("display-a"),
                soundEnabled: false,
                interactionEnabled: true,
                sharingPromptEnabled: false,
                playbackPreference: .audioOnly,
                reducedDynamicEffectsEnabled: true,
                remindersEnabled: false,
                careCadence: .lively,
                timeAnnouncementsEnabled: false,
                halfHourlyAnnouncementsEnabled: true,
                quietHoursEnabled: false,
                flirtyRemindersEnabled: true,
                codexCompletionAnnouncementsEnabled: false,
                usePetName: true,
                randomOutfitsEnabled: false,
                localContentPacksEnabled: false,
                learnedGestureIDs: ["singleTap", "drag"]
            )
            try require(CompanionSettingsV1().schemaVersion == 1, "Unexpected schema version")
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(CompanionSettingsV1.self, from: data)
            try require(decoded == original, "Decoded settings differ from the original")
        }

        await run("Legacy settings gain safe additive defaults", reporter: reporter) {
            let legacy = Data(
                #"{"schemaVersion":1,"personaId":"starter.c01","relationshipTone":"warm-support","locale":"en","presentationMode":"pet","soundEnabled":true,"interactionEnabled":true,"sharingPromptEnabled":false}"#.utf8
            )
            let decoded = try JSONDecoder().decode(CompanionSettingsV1.self, from: legacy)
            try require(decoded.playbackPreference == .audiovisual, "Playback default changed")
            try require(
                decoded.presentationAppearance == .transparent,
                "Legacy settings did not retain the transparent default"
            )
            try require(
                decoded.displayTarget == .followWindow,
                "Legacy settings did not follow the current window"
            )
            try require(
                !decoded.reducedDynamicEffectsEnabled,
                "Legacy settings unexpectedly enabled low-impact mode"
            )
            try require(decoded.remindersEnabled, "Care reminders were not safely enabled")
            try require(decoded.careCadence == .standard, "Care cadence default changed")
            try require(decoded.timeAnnouncementsEnabled, "Time announcements default changed")
            try require(!decoded.halfHourlyAnnouncementsEnabled, "Half-hour announcements should stay opt-in")
            try require(decoded.quietHoursEnabled, "Quiet hours were not restored safely")
            try require(!decoded.flirtyRemindersEnabled, "Flirty reminders should stay opt-in")
            try require(decoded.codexCompletionAnnouncementsEnabled, "Codex work companionship was lost")
            try require(!decoded.usePetName, "Pet names should stay opt-in")
            try require(decoded.randomOutfitsEnabled, "Starter variety default changed")
            try require(decoded.localContentPacksEnabled, "Local packs were not enabled for legacy settings")
            try require(decoded.learnedGestureIDs.isEmpty, "Legacy settings invented gesture progress")
        }

        await run("Low-impact policy disables video work", reporter: reporter) {
            let reduced = CompanionPerformancePolicy(
                reducedDynamicEffectsEnabled: true,
                systemReduceMotionEnabled: false,
                requestedPlayback: .audiovisual
            )
            try require(reduced.effectivePlayback == .audioOnly, "Reduced mode kept audiovisual playback")
            try require(!reduced.permitsLoopingVideo, "Reduced mode kept idle video loops")
            try require(!reduced.permitsVideoExperiences, "Reduced mode kept video experiences")
            try require(!reduced.usesAnimatedTransitions, "Reduced mode kept transitions")

            let systemReduced = CompanionPerformancePolicy(
                reducedDynamicEffectsEnabled: false,
                systemReduceMotionEnabled: true,
                requestedPlayback: .audiovisual
            )
            try require(systemReduced.permitsLoopingVideo, "System Reduce Motion unexpectedly disabled media")
            try require(!systemReduced.usesAnimatedTransitions, "System Reduce Motion kept transitions")
        }

        await run("Window policy projects all presentation sizes", reporter: reporter) {
            let visible = CGRect(x: 100, y: 50, width: 1_200, height: 760)
            try require(
                CompanionWindowPolicy.contentSize(for: .pet, visibleFrame: visible)
                    == CGSize(width: 132, height: 146),
                "Pet content size changed"
            )
            try require(
                CompanionWindowPolicy.contentSize(for: .stage, visibleFrame: visible)
                    == CGSize(width: 560, height: 520),
                "Stage content size changed"
            )
            try require(
                CompanionWindowPolicy.contentSize(for: .fullscreen, visibleFrame: visible)
                    == visible.size,
                "Fullscreen did not use the active visible frame"
            )
            try require(
                CompanionWindowPolicy.playPaletteContentSize(visibleFrame: visible)
                    == CGSize(width: 600, height: 420),
                "Play palette lost its complete upward-opening canvas"
            )
            let standardPalette = CompanionPlayPaletteLayout.plan(
                visibleFrame: visible
            )
            try require(
                standardPalette.columnCount == 3
                    && !standardPalette.isCompact
                    && standardPalette.showsReturnHint
                    && !standardPalette.usesCompactFooter,
                "Standard play palette lost its complete three-column layout"
            )
            let constrained = CGRect(x: 0, y: 0, width: 540, height: 440)
            let constrainedPalette = CompanionPlayPaletteLayout.plan(
                visibleFrame: constrained
            )
            try require(
                CompanionWindowPolicy.playPaletteContentSize(
                    visibleFrame: constrained
                ) == CGSize(width: 540, height: 420),
                "Play palette escaped a constrained visible frame"
            )
            try require(
                constrainedPalette.contentSize == CGSize(width: 540, height: 420)
                    && constrainedPalette.columnCount == 3
                    && constrainedPalette.isCompact
                    && !constrainedPalette.showsReturnHint
                    && constrainedPalette.usesCompactFooter,
                "Constrained play palette did not switch to its no-scroll compact layout"
            )
            let narrow = CompanionPlayPaletteLayout.plan(
                visibleFrame: CGRect(x: 0, y: 0, width: 240, height: 320)
            )
            try require(
                narrow.columnCount == 2
                    && narrow.minimumButtonWidth >= 44
                    && narrow.maximumPaletteWidth <= 220,
                "Narrow play palette did not preserve bounded two-column controls"
            )
            let invalid = CompanionPlayPaletteLayout.plan(
                visibleFrame: CGRect(
                    x: 0,
                    y: 0,
                    width: CGFloat.nan,
                    height: 0
                )
            )
            try require(
                invalid.contentSize == CGSize(width: 600, height: 420),
                "Invalid palette geometry did not use the safe display fallback"
            )

            let stalePetFrame = CGRect(
                x: 800,
                y: 80,
                width: 132,
                height: 146
            )
            let recoveredStage = CompanionWindowPolicy.geometryRecoveryFrame(
                currentFrame: stalePetFrame,
                targetFrameSize: CGSize(width: 560, height: 520),
                mode: .stage,
                visibleFrame: visible
            )
            try require(
                recoveredStage == CGRect(
                    x: 372,
                    y: 80,
                    width: 560,
                    height: 520
                ),
                "A dropped pet-to-stage resize did not preserve its visible anchor"
            )
            let recoveredPalette = CompanionWindowPolicy.geometryRecoveryFrame(
                currentFrame: stalePetFrame,
                targetFrameSize: CGSize(width: 600, height: 420),
                mode: .pet,
                visibleFrame: visible
            )
            try require(
                recoveredPalette == CGRect(
                    x: 332,
                    y: 80,
                    width: 600,
                    height: 420
                ),
                "A clipped magic-wand palette did not recover upward in one canvas"
            )
            let recoveredReward = CompanionWindowPolicy.geometryRecoveryFrame(
                currentFrame: stalePetFrame,
                targetFrameSize: visible.size,
                mode: .fullscreen,
                visibleFrame: visible
            )
            try require(
                recoveredReward == visible,
                "A dropped game reward resize did not recover to the visible display"
            )
            try require(
                CompanionWindowPolicy.geometryRecoveryFrame(
                    currentFrame: recoveredStage!,
                    targetFrameSize: recoveredStage!.size,
                    mode: .stage,
                    visibleFrame: visible
                ) == nil,
                "Geometry recovery disturbed an already-correct stage"
            )
        }

        await run("Direct surprises never impersonate clock or care reminders", reporter: reporter) {
            let policy = CompanionDirectSurprisePolicy()
            let forbidden: Set<CompanionDirectedPetMoment> = [
                .drink, .stretch, .timeCafe
            ]
            for tone in CompanionRelationshipTone.allCases {
                for daypart in CompanionDaypart.allCases {
                    let candidates = policy.candidates(
                        daypart: daypart,
                        relationshipTone: tone
                    )
                    try require(!candidates.isEmpty, "Direct surprise had no visual candidate")
                    try require(
                        forbidden.isDisjoint(with: candidates),
                        "Direct surprise leaked a clock or scheduled-care moment"
                    )
                }
            }
        }

        await run("Window policy restores pet safely after display changes", reporter: reporter) {
            let visible = CGRect(x: -1_920, y: 40, width: 1_920, height: 1_040)
            let size = CGSize(width: 560, height: 520)
            let restored = CompanionWindowPolicy.initialOrigin(
                for: .stage,
                visibleFrame: visible,
                windowFrameSize: size,
                savedPetOrigin: CGPoint(x: 9_999, y: -9_999)
            )
            try require(restored.x == -568, "Restored X was not clamped to the active display")
            try require(restored.y == 48, "Restored Y was not clamped to the active display")

            let fullscreen = CompanionWindowPolicy.initialOrigin(
                for: .fullscreen,
                visibleFrame: visible,
                windowFrameSize: visible.size,
                savedPetOrigin: CGPoint(x: 10, y: 10)
            )
            try require(
                fullscreen.x == visible.origin.x && fullscreen.y == visible.origin.y,
                "Fullscreen reused a stale pet origin"
            )
        }

        await run("Window policy contains oversized and invalid geometry", reporter: reporter) {
            let tiny = CGRect(x: 300, y: 200, width: 320, height: 240)
            let oversized = CompanionWindowPolicy.clampedPetOrigin(
                CGPoint(x: CGFloat.infinity, y: CGFloat.nan),
                visibleFrame: tiny,
                windowFrameSize: CGSize(width: 560, height: 520)
            )
            try require(
                oversized.x == tiny.origin.x && oversized.y == tiny.origin.y,
                "Oversized window escaped the visible-frame origin"
            )

            let fallbackSize = CompanionWindowPolicy.contentSize(
                for: .fullscreen,
                visibleFrame: CGRect(x: 0, y: 0, width: 0, height: 0)
            )
            try require(
                fallbackSize == CompanionWindowPolicy.fallbackVisibleFrame.size,
                "Invalid display geometry did not use the safe fallback"
            )
        }

        await run("Window policy docking is deterministic and bounded", reporter: reporter) {
            let visible = CGRect(x: 0, y: 0, width: 1_000, height: 800)
            let result = CompanionWindowPolicy.dockedPetOrigin(
                CGPoint(x: 900, y: 300),
                visibleFrame: visible,
                windowFrameSize: CGSize(width: 132, height: 146)
            )
            try require(result.edge == .right, "Nearest right edge was not selected")
            try require(result.origin.x == 860, "Right docking inset changed")
            try require(result.origin.y == 300, "Docking changed the unrelated axis")

            let undocked = CompanionWindowPolicy.dockedPetOrigin(
                CGPoint(x: 400, y: 300),
                visibleFrame: visible,
                windowFrameSize: CGSize(width: 132, height: 146)
            )
            try require(undocked.edge == nil, "Central window unexpectedly docked")
            try require(
                undocked.origin.x == 400 && undocked.origin.y == 300,
                "Central window moved"
            )
        }

        await run("Presentation surfaces resolve accessibility fallbacks", reporter: reporter) {
            let transparent = CompanionPresentationSurfacePolicy.plan(
                mode: .pet,
                requestedAppearance: .transparent,
                systemReduceTransparencyEnabled: false,
                systemIncreaseContrastEnabled: false
            )
            try require(transparent.backgroundOpacity == 0, "Transparent mode gained a backdrop")
            try require(!transparent.showsWindowShadow, "Transparent pet gained a window shadow")

            let cinematic = CompanionPresentationSurfacePolicy.plan(
                mode: .stage,
                requestedAppearance: .cinematic,
                systemReduceTransparencyEnabled: false,
                systemIncreaseContrastEnabled: false
            )
            try require(cinematic.resolvedAppearance == .cinematic, "Cinematic mode changed")
            try require(cinematic.usesTranslucentMaterial, "Cinematic material was lost")

            let accessible = CompanionPresentationSurfacePolicy.plan(
                mode: .fullscreen,
                requestedAppearance: .cinematic,
                systemReduceTransparencyEnabled: true,
                systemIncreaseContrastEnabled: true
            )
            try require(accessible.resolvedAppearance == .dim, "Transparency reduction did not fall back")
            try require(!accessible.usesTranslucentMaterial, "Fallback retained translucent material")
            try require(accessible.backgroundOpacity > cinematic.backgroundOpacity, "Contrast was not increased")
            try require(accessible.cornerRadius == 0, "Fullscreen surface gained rounded corners")
        }

        await run("Locale policy normalizes bounded system tags", reporter: reporter) {
            try require(
                CompanionLocaleResolutionPolicy.normalizedTag(" ZH_hant_TW ")
                    == "zh-hant-tw",
                "System locale separators or casing were not normalized"
            )
            try require(
                CompanionLocaleResolutionPolicy.normalizedTag("en--US") == nil,
                "Malformed locale tag was accepted"
            )
            try require(
                CompanionLocaleResolutionPolicy.normalizedTag(
                    String(repeating: "a", count: 129)
                ) == nil,
                "Oversized locale tag escaped the bounded parser"
            )
        }

        await run("Locale policy ranks exact and generic declarations", reporter: reporter) {
            try require(
                CompanionLocaleResolutionPolicy.bestMatch(
                    preferred: "en-US",
                    available: ["en-GB", "en", "en-US"]
                ) == "en-US",
                "Exact regional declaration did not win"
            )
            try require(
                CompanionLocaleResolutionPolicy.bestMatch(
                    preferred: "en-US",
                    available: ["en-GB", "en"]
                ) == "en",
                "Generic language declaration did not outrank a conflicting region"
            )
        }

        await run("Locale policy separates media eligibility from copy fallback", reporter: reporter) {
            let available = ["zh-Hans", "en-US"]
            try require(
                CompanionLocaleResolutionPolicy.bestCompatibleMatch(
                    preferred: "en_GB",
                    available: available
                ) == "en-US",
                "Strict media matching lost a compatible English declaration"
            )
            try require(
                CompanionLocaleResolutionPolicy.bestCompatibleMatch(
                    preferred: "zh-TW",
                    available: available
                ) == nil,
                "Strict media matching crossed an incompatible Chinese script"
            )
            try require(
                CompanionLocaleResolutionPolicy.bestMatch(
                    preferred: "zh-TW",
                    available: available,
                    fallbackOrder: ["en-US", "zh-Hans"]
                ) == "en-US",
                "Accessibility copy lost its declared fallback order"
            )
            let oversized = Array(repeating: "fr-FR", count: 64) + ["en-US"]
            try require(
                CompanionLocaleResolutionPolicy.bestCompatibleMatch(
                    preferred: "en-US",
                    available: oversized
                ) == nil,
                "Strict media matching escaped its bounded candidate window"
            )
        }

        await run("Locale policy keeps Chinese scripts distinct", reporter: reporter) {
            let traditional = CompanionLocaleResolutionPolicy.compatibilityScore(
                candidate: "zh-Hant",
                preferred: "zh-TW"
            )
            let generic = CompanionLocaleResolutionPolicy.compatibilityScore(
                candidate: "zh",
                preferred: "zh-TW"
            )
            try require(traditional != nil && generic != nil, "Compatible Chinese tags were rejected")
            try require(traditional! > generic!, "Matching script did not outrank generic Chinese")
            try require(
                CompanionLocaleResolutionPolicy.compatibilityScore(
                    candidate: "zh-Hans",
                    preferred: "zh-TW"
                ) == nil,
                "Simplified Chinese matched a Traditional Chinese region"
            )
        }

        await run("Locale policy applies declared fallback deterministically", reporter: reporter) {
            try require(
                CompanionLocaleResolutionPolicy.bestMatch(
                    preferred: "fr-FR",
                    available: ["zh-Hans", "en"],
                    fallbackOrder: ["en", "zh-Hans"]
                ) == "en",
                "Declared locale fallback order was ignored"
            )
            let beyondBound = Array(repeating: "bad--tag", count: 64) + ["en"]
            try require(
                CompanionLocaleResolutionPolicy.bestMatch(
                    preferred: "en-US",
                    available: beyondBound
                ) == nil,
                "Locale matching exceeded its bounded candidate set"
            )
        }

        await run("Display policy selects requested and current screens", reporter: reporter) {
            let main = CompanionDisplayDescriptor(
                identifier: "display-main",
                visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
                isMain: true
            )
            let side = CompanionDisplayDescriptor(
                identifier: "display-side",
                visibleFrame: CGRect(x: -1_920, y: 40, width: 1_920, height: 1_040),
                isMain: false
            )
            let selected = CompanionDisplaySelectionPolicy.resolve(
                target: .specific("display-side"),
                currentDisplayIdentifier: "display-main",
                displays: [main, side]
            )
            try require(selected.descriptor == side, "Specific display was not selected")
            try require(selected.resolution == .selectedSpecific, "Specific resolution changed")

            let followed = CompanionDisplaySelectionPolicy.resolve(
                target: .followWindow,
                currentDisplayIdentifier: "display-side",
                displays: [main, side]
            )
            try require(followed.descriptor == side, "Current display was not followed")
            try require(followed.resolution == .followedCurrent, "Follow resolution changed")

            let selectedMain = CompanionDisplaySelectionPolicy.resolve(
                target: .main,
                currentDisplayIdentifier: "display-side",
                displays: [side, main]
            )
            try require(selectedMain.descriptor == main, "Main display was not selected")
        }

        await run("Display policy recovers disconnected and invalid screens", reporter: reporter) {
            let current = CompanionDisplayDescriptor(
                identifier: "display-current",
                visibleFrame: CGRect(x: 200, y: 100, width: 1_280, height: 720),
                isMain: false
            )
            let recovered = CompanionDisplaySelectionPolicy.resolve(
                target: .specific("display-disconnected"),
                currentDisplayIdentifier: current.identifier,
                displays: [current]
            )
            try require(recovered.descriptor == current, "Disconnected display did not recover to current")
            try require(recovered.resolution == .recoveredToCurrent, "Recovery source changed")

            let fallback = CompanionDisplaySelectionPolicy.resolve(
                target: CompanionDisplayTarget(mode: .specific, identifier: " bad display "),
                currentDisplayIdentifier: nil,
                displays: [
                    CompanionDisplayDescriptor(
                        identifier: "invalid/path",
                        visibleFrame: .zero,
                        isMain: true
                    )
                ]
            )
            try require(fallback.resolution == .usedFallback, "Invalid display facts escaped fallback")
            try require(
                fallback.descriptor.visibleFrame == CompanionWindowPolicy.fallbackVisibleFrame,
                "Fallback geometry changed"
            )
        }

        await run("Presentation projection applies declared focal crops", reporter: reporter) {
            let projection = CompanionPresentationProjection.resolve(
                mode: .pet,
                cropAnchors: [
                    "pet": CompanionMediaCropAnchor(x: 0.5, y: 0.5, scale: 2)
                ],
                reducedDynamicEffectsEnabled: false
            )
            try require(projection.permitsVideo, "Valid projection disabled video")
            try require(projection.source == .declared, "Declared crop lost provenance")
            try require(projection.resolvedAnchorKey == "pet", "Pet crop key was not selected")
            try require(projection.gravity == .aspectFit, "Focal crop must begin from the full frame")
            try require(
                projection.playerLayerFrame(in: CGRect(x: 0, y: 0, width: 100, height: 100))
                    == CGRect(x: -50, y: -50, width: 200, height: 200),
                "Focal crop did not keep the declared point centred"
            )
        }

        await run("Presentation projection preserves v1 crop aliases", reporter: reporter) {
            let anchors = [
                "partial": CompanionMediaCropAnchor(x: 0.4, y: 0.45, scale: 1.2),
                "full": CompanionMediaCropAnchor(x: 0.5, y: 0.5, scale: 1)
            ]
            let stage = CompanionPresentationProjection.resolve(
                mode: .stage,
                cropAnchors: anchors,
                reducedDynamicEffectsEnabled: false
            )
            let fullscreen = CompanionPresentationProjection.resolve(
                mode: .fullscreen,
                cropAnchors: anchors,
                reducedDynamicEffectsEnabled: false
            )
            try require(stage.source == .legacyAlias, "v1 partial crop was not preserved")
            try require(stage.resolvedAnchorKey == "partial", "Wrong stage alias selected")
            try require(fullscreen.source == .legacyAlias, "v1 full crop was not preserved")
            try require(fullscreen.resolvedAnchorKey == "full", "Wrong fullscreen alias selected")
        }

        await run("Presentation focal tracks interpolate deterministically", reporter: reporter) {
            let track = CompanionMediaFocalTrack(
                keyframes: [
                    .init(timeMs: 0, x: 0.45, y: 0.45, scale: 2),
                    .init(timeMs: 1_000, x: 0.55, y: 0.55, scale: 2),
                    .init(timeMs: 2_000, x: 0.45, y: 0.45, scale: 2)
                ]
            )
            let safeArea = CompanionMediaSafeArea(
                x: 0.35,
                y: 0.35,
                width: 0.30,
                height: 0.30
            )
            let projection = CompanionPresentationProjection.resolve(
                mode: .pet,
                cropAnchors: [:],
                focalTracks: ["pet": track],
                safeAreas: ["pet": safeArea],
                reducedDynamicEffectsEnabled: false
            )
            try require(projection.source == .declaredTrack, "Focal track lost provenance")
            try require(projection.hasDynamicFocalTrack, "Focal track was not retained")
            try require(projection.safeArea == safeArea, "Safe area was not retained")
            let midpoint = projection.resolvedAnchor(atMilliseconds: 500)
            try require(
                midpoint == CompanionMediaCropAnchor(x: 0.5, y: 0.5, scale: 2),
                "Linear focal interpolation changed"
            )
            try require(
                track.keyframes.allSatisfy { safeArea.isVisible(through: $0.anchor) },
                "Accepted safe area is not visible across the focal track"
            )
        }

        await run("Presentation projection clamps edge crops without blank gutters", reporter: reporter) {
            let viewport = CGRect(x: 0, y: 0, width: 100, height: 100)
            let topLeft = CompanionPresentationProjection.resolve(
                mode: .pet,
                cropAnchors: [
                    "pet": CompanionMediaCropAnchor(x: 0.05, y: 0.05, scale: 3)
                ],
                reducedDynamicEffectsEnabled: false
            )
            let bottomRight = CompanionPresentationProjection.resolve(
                mode: .pet,
                cropAnchors: [
                    "pet": CompanionMediaCropAnchor(x: 0.95, y: 0.95, scale: 3)
                ],
                reducedDynamicEffectsEnabled: false
            )
            try require(
                topLeft.playerLayerFrame(in: viewport)
                    == CGRect(x: 0, y: -200, width: 300, height: 300),
                "Top-left crop exposed a blank gutter"
            )
            try require(
                bottomRight.playerLayerFrame(in: viewport)
                    == CGRect(x: -200, y: 0, width: 300, height: 300),
                "Bottom-right crop exposed a blank gutter"
            )
        }

        await run("Presentation safe areas reject invisible crop envelopes", reporter: reporter) {
            let anchor = CompanionMediaCropAnchor(x: 0.5, y: 0.5, scale: 2)
            let visible = CompanionMediaSafeArea(x: 0.3, y: 0.3, width: 0.4, height: 0.4)
            let clipped = CompanionMediaSafeArea(x: 0.05, y: 0.05, width: 0.2, height: 0.2)
            try require(visible.isVisible(through: anchor), "Visible safe area was rejected")
            try require(!clipped.isVisible(through: anchor), "Clipped safe area was accepted")
        }

        await run("Presentation projection contains invalid metadata", reporter: reporter) {
            let projection = CompanionPresentationProjection.resolve(
                mode: .pet,
                cropAnchors: [
                    "pet": CompanionMediaCropAnchor(x: .nan, y: 2, scale: 99)
                ],
                reducedDynamicEffectsEnabled: false
            )
            try require(projection.source == .modeDefault, "Invalid crop did not use the safe default")
            try require(projection.anchor == nil, "Invalid crop reached the player layer")
            try require(projection.gravity == .aspectFill, "Pet fallback no longer fills its viewport")
            let viewport = CGRect(x: 4, y: 6, width: 120, height: 90)
            try require(
                projection.playerLayerFrame(in: viewport) == viewport,
                "Default projection unexpectedly changed viewport geometry"
            )
        }

        await run("Presentation projection enforces reduced dynamic fallback", reporter: reporter) {
            let projection = CompanionPresentationProjection.resolve(
                mode: .fullscreen,
                cropAnchors: [
                    "fullscreen": CompanionMediaCropAnchor(x: 0.5, y: 0.5, scale: 1)
                ],
                reducedDynamicEffectsEnabled: true
            )
            try require(!projection.permitsVideo, "Reduced dynamic mode retained video playback")
            try require(
                projection.rendering == .staticFallback,
                "Reduced dynamic mode did not choose the static renderer"
            )
            try require(
                projection.source == .reducedDynamicFallback,
                "Reduced dynamic fallback lost its diagnostic source"
            )
            try require(projection.anchor == nil, "Reduced dynamic fallback kept crop work")
        }

        await run("Projection authoring receipt is portable and path-free", reporter: reporter) {
            let receipt = CompanionProjectionAuthoringReceipt(
                packID: "cc.chengyin.example.editor",
                assetID: "editor-video",
                generatedForAppVersion: "0.19.29",
                focalTracks: [
                    "pet": [
                        .init(timeMs: 0, x: 0.5, y: 0.5, scale: 2),
                        .init(timeMs: 4_000, x: 0.55, y: 0.5, scale: 2)
                    ]
                ],
                safeAreas: [
                    "pet": .init(x: 0.3, y: 0.3, width: 0.35, height: 0.35)
                ]
            )
            try receipt.validate(durationMs: 4_000)
            let data = try JSONEncoder().encode(receipt)
            let decoded = try JSONDecoder().decode(
                CompanionProjectionAuthoringReceipt.self,
                from: data
            )
            try require(decoded == receipt, "Authoring receipt changed during round-trip")
            let serialized = String(decoding: data, as: UTF8.self)
            try require(
                !serialized.contains("/Users/")
                    && !serialized.contains("/Volumes/")
                    && !serialized.contains("file://"),
                "Authoring receipt can disclose a local media path"
            )
        }

        await run("Projection authoring receipt rejects clipped envelopes", reporter: reporter) {
            let receipt = CompanionProjectionAuthoringReceipt(
                packID: "cc.chengyin.example.editor",
                assetID: "editor-video",
                generatedForAppVersion: "0.19.29",
                focalTracks: [
                    "pet": [
                        .init(timeMs: 0, x: 0.5, y: 0.5, scale: 2),
                        .init(timeMs: 4_000, x: 0.5, y: 0.5, scale: 2)
                    ]
                ],
                safeAreas: [
                    "pet": .init(x: 0.02, y: 0.02, width: 0.2, height: 0.2)
                ]
            )
            do {
                try receipt.validate(durationMs: 4_000)
                throw CheckFailure(message: "Clipped authoring safe area was accepted")
            } catch let error as CompanionProjectionAuthoringError {
                try require(
                    error == .safeAreaNotVisible("pet"),
                    "Unexpected authoring error: \(error)"
                )
            }
        }

        await run("Gesture learning is ordered, bounded and resettable", reporter: reporter) {
            var learning = CompanionGestureLearningState(
                learnedIDs: ["drag", "singleTap", "singleTap", "futureGesture"]
            )
            try require(learning.completedCount == 2, "Known lessons were not deduplicated")
            try require(learning.totalCount == 4, "Unexpected gesture lesson count")
            try require(
                learning.learnedIDs == ["singleTap", "drag"],
                "Persisted lessons are not stable and ordered"
            )
            try require(learning.nextLesson == .doubleTap, "Progressive lesson order changed")
            try require(!learning.markLearned(.singleTap), "Duplicate learning was accepted")
            try require(learning.markLearned(.doubleTap), "New lesson was not learned")
            try require(learning.nextLesson == .longPress, "Next lesson did not advance")
            learning.reset()
            try require(learning.completedCount == 0, "Reset retained learned gestures")
            try require(learning.nextLesson == .singleTap, "Reset did not restart the coach")
        }

        await run("Runtime readiness distinguishes healthy, paused and attention", reporter: reporter) {
            let healthy = CompanionRuntimeReadiness.evaluate(
                CompanionRuntimeReadinessFacts(
                    hasBuildIdentity: true,
                    bundledVideoCount: 26,
                    declaredVoiceLineCount: 159,
                    availableVoiceLineCount: 159,
                    starterContractPresent: true,
                    starterPublicDistributionReady: true,
                    eventBridgeReady: true,
                    localContentPacksEnabled: true,
                    microphoneUsageDeclared: false
                )
            )
            try require(healthy.count == 6, "Readiness component count changed")
            try require(
                !CompanionRuntimeReadiness.needsAttention(healthy),
                "Healthy runtime was marked for attention"
            )

            let paused = CompanionRuntimeReadiness.evaluate(
                CompanionRuntimeReadinessFacts(
                    hasBuildIdentity: true,
                    bundledVideoCount: 1,
                    declaredVoiceLineCount: 1,
                    availableVoiceLineCount: 1,
                    starterContractPresent: true,
                    starterPublicDistributionReady: false,
                    eventBridgeReady: true,
                    localContentPacksEnabled: false,
                    microphoneUsageDeclared: false
                )
            )
            try require(
                paused.first(where: { $0.component == .contentLibrary })?.level == .paused,
                "Starter recovery mode was not represented as paused"
            )
            try require(
                paused.first(where: { $0.component == .starterContract })?.level == .paused,
                "Internal-preview Starter contract was not represented as paused"
            )
            try require(
                !CompanionRuntimeReadiness.needsAttention(paused),
                "User-selected Starter recovery mode was treated as a failure"
            )

            let unhealthy = CompanionRuntimeReadiness.evaluate(
                CompanionRuntimeReadinessFacts(
                    hasBuildIdentity: false,
                    bundledVideoCount: 0,
                    declaredVoiceLineCount: 4,
                    availableVoiceLineCount: 3,
                    starterContractPresent: false,
                    starterPublicDistributionReady: false,
                    eventBridgeReady: false,
                    localContentPacksEnabled: true,
                    microphoneUsageDeclared: true
                )
            )
            try require(
                CompanionRuntimeReadiness.needsAttention(unhealthy),
                "Missing local capabilities were not surfaced"
            )
            try require(
                unhealthy.filter { $0.level == .attention }.count == 5,
                "Unexpected readiness attention policy"
            )
        }

        await run("Runtime repair policy is bounded and non-destructive", reporter: reporter) {
            let recoverable = CompanionRuntimeReadiness.evaluate(
                CompanionRuntimeReadinessFacts(
                    hasBuildIdentity: true,
                    bundledVideoCount: 26,
                    declaredVoiceLineCount: 159,
                    availableVoiceLineCount: 159,
                    starterContractPresent: true,
                    starterPublicDistributionReady: false,
                    eventBridgeReady: false,
                    localContentPacksEnabled: true,
                    contentLibraryHealthy: false,
                    microphoneUsageDeclared: false
                )
            )
            try require(
                CompanionRuntimeReadiness.safeRecoveryActions(recoverable)
                    == [.repairEventBridge, .recoverContentLibrary],
                "Safe recovery actions changed order or scope"
            )
            try require(
                !CompanionRuntimeReadiness.hasManualAttention(recoverable),
                "Recoverable local state was incorrectly made an owner gate"
            )

            let manual = CompanionRuntimeReadiness.evaluate(
                CompanionRuntimeReadinessFacts(
                    hasBuildIdentity: false,
                    bundledVideoCount: 0,
                    declaredVoiceLineCount: 1,
                    availableVoiceLineCount: 0,
                    starterContractPresent: false,
                    starterPublicDistributionReady: false,
                    eventBridgeReady: true,
                    localContentPacksEnabled: false,
                    contentLibraryHealthy: true,
                    microphoneUsageDeclared: true
                )
            )
            try require(
                CompanionRuntimeReadiness.safeRecoveryActions(manual).isEmpty,
                "A binary, media, rights, or privacy gate became self-repairable"
            )
            try require(
                CompanionRuntimeReadiness.hasManualAttention(manual),
                "Manual attention was hidden behind an empty repair plan"
            )
        }

        await run("Relationship progress is positive-only and tone-capped", reporter: reporter) {
            var state = CompanionRelationshipStateV1(toneCap: .romanceLite)
            state.recordPositiveMoment(4)
            state.recordPositiveMoment(0)
            try require(state.bondMoments == 4, "Positive moments were not accumulated")

            _ = state.increaseChemistry(by: Int.max)
            try require(state.chemistryLevel == 3, "Chemistry did not clamp to 0...3")
            state.setToneCap(.calmPeer)
            try require(state.chemistryLevel == 1, "Tone cap did not lower session chemistry")
            state.resetSessionChemistry()
            try require(state.chemistryLevel == 0, "Session chemistry did not reset")

            try require(
                state.advanceSurprise(by: Int.max),
                "Surprise guarantee did not clamp safely"
            )
            try require(state.isSurpriseGuaranteed, "Surprise guarantee was not exposed")
            state.consumeDeliveredSurprise()
            try require(state.surpriseProgress == 0, "Delivered surprise was not consumed")

            let firstUnlock = try state.unlockMemento("memento.first-task")
            try require(firstUnlock, "Memento was not unlocked")
            let duplicateUnlock = try state.unlockMemento("memento.first-task")
            try require(
                !duplicateUnlock,
                "Duplicate memento was accepted"
            )
            try state.rememberAsset(
                "starter.pack@1.0.0:scene.complete.01",
                at: Date(timeIntervalSince1970: 1_800_000_000)
            )
            try require(
                state.recentAssetIDs.first == "starter.pack@1.0.0:scene.complete.01",
                "Runtime-qualified asset ID was rejected"
            )
            try requireRelationshipError(.invalidPersistentIdentifier) {
                _ = try state.unlockMemento("/private/project")
            }
            try requireRelationshipError(.invalidPersistentIdentifier) {
                try state.rememberAsset("starter.pack@1.0.0:secret prompt")
            }
        }

        await run("Relationship playback memory is bounded", reporter: reporter) {
            var state = CompanionRelationshipStateV1()
            let base = Date(timeIntervalSince1970: 1_800_000_000)
            for index in 0..<70 {
                try state.rememberAsset(
                    "asset.\(index)",
                    at: base.addingTimeInterval(TimeInterval(index))
                )
            }

            try require(
                state.recentAssetIDs.count
                    == CompanionRelationshipStateV1.maximumRecentAssetCount,
                "Recent anti-repeat memory is not bounded"
            )
            try require(state.recentAssetIDs.first == "asset.69", "Recent order is incorrect")
            try require(
                state.lastPlayedAtByAssetID.count
                    == CompanionRelationshipStateV1.maximumPlaybackRecordCount,
                "Cooldown history is not bounded"
            )
            try require(
                state.lastPlayedAt(forAssetID: "asset.69")
                    == base.addingTimeInterval(69),
                "Latest playback date was not recorded"
            )
            try require(
                state.lastPlayedAt(forAssetID: "asset.0") == nil,
                "Old playback history was not evicted"
            )
        }

        await run("Relationship state v1 JSON round-trip", reporter: reporter) {
            let playedAt = Date(timeIntervalSince1970: 1_800_000_000)
            var original = CompanionRelationshipStateV1(
                bondMoments: 12,
                chemistryLevel: 2,
                toneCap: .romanceLite,
                surpriseProgress: 6
            )
            _ = try original.unlockMemento("memento.first-focus")
            try original.rememberAsset("starter.scene.complete.01", at: playedAt)

            let data = try CompanionRelationshipStateCodec.encode(original)
            let decoded = try CompanionRelationshipStateCodec.decode(data)
            try require(decoded == original, "Relationship state changed during round-trip")

            let serialized = String(decoding: data, as: UTF8.self)
            try require(!serialized.contains("prompt"), "Schema can persist prompt data")
            try require(!serialized.contains("\"code\""), "Schema can persist code data")
            try require(!serialized.contains("\"path\""), "Schema can persist path data")
            try require(!serialized.contains("\"title\""), "Schema can persist task titles")
        }

        await run("Legacy relationship state migration", reporter: reporter) {
            let legacy = Data(
                """
                {
                  "bondMoments": 9,
                  "chemistry": 99,
                  "tone": "calm-peer",
                  "surpriseProgress": 99,
                  "mementos": ["memento.first-task", "/private/path", "memento.first-task"],
                  "recentAssets": ["scene.safe", "secret prompt"],
                  "lastPlayedAtByAssetID": {
                    "scene.safe": "2027-01-15T08:00:00Z",
                    "/private/path": "2027-01-15T08:00:01Z"
                  }
                }
                """.utf8
            )

            let migrated = try CompanionRelationshipStateCodec.decode(legacy)
            try require(migrated.schemaVersion == 1, "Legacy schema did not migrate")
            try require(migrated.bondMoments == 9, "Legacy bond moments were lost")
            try require(migrated.chemistryLevel == 1, "Migrated chemistry ignored tone cap")
            try require(
                migrated.surpriseProgress
                    == CompanionRelationshipStateV1.surpriseGuaranteeThreshold,
                "Migrated surprise progress was not clamped"
            )
            try require(
                migrated.unlockedMementoIDs == ["memento.first-task"],
                "Unsafe or duplicate legacy mementos survived migration"
            )
            try require(
                migrated.recentAssetIDs == ["scene.safe"],
                "Unsafe legacy asset identifiers survived migration"
            )
            try require(
                Set(migrated.lastPlayedAtByAssetID.keys) == ["scene.safe"],
                "Unsafe legacy playback history survived migration"
            )
        }

        await run("Unknown relationship schema rejection", reporter: reporter) {
            let future = Data(#"{"schemaVersion":99}"#.utf8)
            try requireRelationshipError(.unsupportedSchema) {
                _ = try CompanionRelationshipStateCodec.decode(future)
            }
        }

        await run("Relationship migration keeps rollback data", reporter: reporter) {
            let suiteName = "cc.chengyin.relationship-migration.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                throw CheckFailure(message: "Could not create isolated UserDefaults")
            }
            defaults.removePersistentDomain(forName: suiteName)
            defer {
                defaults.removePersistentDomain(forName: suiteName)
            }

            let legacy = Data(
                #"{"bondMoments":7,"chemistry":2,"tone":"romance-lite"}"#.utf8
            )
            defaults.set(legacy, forKey: CompanionRelationshipStateStore.defaultStorageKey)

            let migrated = CompanionRelationshipStateStore(userDefaults: defaults).load()
            try require(migrated.schemaVersion == 1, "Store did not migrate legacy state")
            try require(migrated.bondMoments == 7, "Store migration lost permanent progress")
            try require(migrated.chemistryLevel == 0, "Store migration retained old session state")
            try require(
                defaults.data(forKey: CompanionRelationshipStateStore.defaultBackupKey) == legacy,
                "Pre-migration state was not retained for rollback"
            )
            guard let current = defaults.data(
                forKey: CompanionRelationshipStateStore.defaultStorageKey
            ) else {
                throw CheckFailure(message: "Migrated state was not persisted")
            }
            let decodedCurrent = try CompanionRelationshipStateCodec.decode(current)
            try require(
                decodedCurrent.schemaVersion == 1,
                "Migrated primary state is not readable"
            )
        }

        await run("Relationship store rollback and session reset", reporter: reporter) {
            let suiteName = "cc.chengyin.relationship-tests.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                throw CheckFailure(message: "Could not create isolated UserDefaults")
            }
            defaults.removePersistentDomain(forName: suiteName)
            defer {
                defaults.removePersistentDomain(forName: suiteName)
            }

            let store = CompanionRelationshipStateStore(userDefaults: defaults)
            let first = try store.update { state in
                state.recordPositiveMoment(4)
                state.setToneCap(.romanceLite)
                _ = state.increaseChemistry(by: 3)
                _ = try state.unlockMemento("memento.first")
                try state.rememberAsset(
                    "scene.first",
                    at: Date(timeIntervalSince1970: 1_800_000_000)
                )
            }
            try require(first.chemistryLevel == 3, "Session chemistry was not retained in memory")
            try require(store.load().chemistryLevel == 3, "Cached session chemistry was lost")

            _ = try store.update { state in
                state.recordPositiveMoment(5)
                _ = try state.unlockMemento("memento.second")
                try state.rememberAsset(
                    "scene.second",
                    at: Date(timeIntervalSince1970: 1_800_000_010)
                )
            }

            defaults.set(Data("corrupt-primary".utf8), forKey: CompanionRelationshipStateStore.defaultStorageKey)
            let recoveredStore = CompanionRelationshipStateStore(userDefaults: defaults)
            let recovered = recoveredStore.load()
            try require(recovered.bondMoments == 4, "Last valid backup was not recovered")
            try require(
                recovered.unlockedMementoIDs == ["memento.first"],
                "Backup mementos were not recovered"
            )
            try require(recovered.chemistryLevel == 0, "Chemistry survived a new session")

            try recoveredStore.save(CompanionRelationshipStateV1(bondMoments: 0))
            let preserved = recoveredStore.load()
            try require(preserved.bondMoments == 4, "Permanent bond progress decreased")
            try require(
                preserved.unlockedMementoIDs.contains("memento.first"),
                "Permanent memento progress decreased"
            )
        }

        await run("Relationship store safe default fallback", reporter: reporter) {
            let suiteName = "cc.chengyin.relationship-fallback.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                throw CheckFailure(message: "Could not create isolated UserDefaults")
            }
            defaults.removePersistentDomain(forName: suiteName)
            defer {
                defaults.removePersistentDomain(forName: suiteName)
            }
            defaults.set(Data("bad-primary".utf8), forKey: CompanionRelationshipStateStore.defaultStorageKey)
            defaults.set(Data("bad-backup".utf8), forKey: CompanionRelationshipStateStore.defaultBackupKey)

            let state = CompanionRelationshipStateStore(userDefaults: defaults).load()
            try require(state == CompanionRelationshipStateV1(), "Corruption did not fall back safely")
        }

        await run("Explicit relationship forgetting cannot be rolled back", reporter: reporter) {
            let suiteName = "cc.chengyin.relationship-forget.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                throw CheckFailure(message: "Could not create isolated UserDefaults")
            }
            defaults.removePersistentDomain(forName: suiteName)
            defer { defaults.removePersistentDomain(forName: suiteName) }

            let store = CompanionRelationshipStateStore(userDefaults: defaults)
            _ = try store.update { state in
                state.setToneCap(.romanceLite)
                state.recordPositiveMoment(12)
                _ = state.advanceSurprise(by: 6)
                _ = try state.unlockMemento("memento.shared-workday")
                try state.rememberAsset(
                    "starter.pack@1.0.0:scene.complete.01",
                    at: Date(timeIntervalSince1970: 1_800_000_000)
                )
            }
            let forgotten = try store.forgetAllMemory()
            try require(forgotten.bondMoments == 0, "Bond moments survived explicit forgetting")
            try require(forgotten.surpriseProgress == 0, "Surprise progress survived forgetting")
            try require(forgotten.unlockedMementoIDs.isEmpty, "Mementos survived forgetting")
            try require(forgotten.recentAssetIDs.isEmpty, "Recent media survived forgetting")
            try require(forgotten.lastPlayedAtByAssetID.isEmpty, "Playback dates survived forgetting")
            try require(forgotten.toneCap == .romanceLite, "A user preference was erased with memory")
            try require(
                defaults.data(forKey: CompanionRelationshipStateStore.defaultBackupKey) == nil,
                "Explicit forgetting kept a rollback copy"
            )

            defaults.set(
                Data("corrupt-after-forgetting".utf8),
                forKey: CompanionRelationshipStateStore.defaultStorageKey
            )
            let recovered = CompanionRelationshipStateStore(userDefaults: defaults).load()
            try require(recovered.bondMoments == 0, "Deleted relationship memory was resurrected")
            try require(recovered.unlockedMementoIDs.isEmpty, "Deleted mementos were resurrected")
        }

        await run("Relationship memory can be forgotten by field", reporter: reporter) {
            let suiteName = "cc.chengyin.relationship-field-forget.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                throw CheckFailure(message: "Could not create isolated UserDefaults")
            }
            defaults.removePersistentDomain(forName: suiteName)
            defer { defaults.removePersistentDomain(forName: suiteName) }

            let store = CompanionRelationshipStateStore(userDefaults: defaults)
            _ = try store.update { state in
                state.setToneCap(.playfulSpark)
                state.recordPositiveMoment(7)
                _ = state.advanceSurprise(by: 5)
                _ = try state.unlockMemento("memento.field-control")
                try state.rememberAsset(
                    "starter.pack@1.0.0:scene.field-control",
                    at: Date(timeIntervalSince1970: 1_800_000_100)
                )
            }
            let filtered = try store.forgetMemory([
                .playbackHistory,
                .surpriseProgress
            ])
            try require(filtered.bondMoments == 7, "Unselected shared progress was erased")
            try require(
                filtered.unlockedMementoIDs == ["memento.field-control"],
                "Unselected mementos were erased"
            )
            try require(filtered.toneCap == .playfulSpark, "Tone preference was erased")
            try require(filtered.surpriseProgress == 0, "Selected surprise progress survived")
            try require(filtered.recentAssetIDs.isEmpty, "Selected recent media survived")
            try require(filtered.lastPlayedAtByAssetID.isEmpty, "Selected playback dates survived")
            try require(
                defaults.data(forKey: CompanionRelationshipStateStore.defaultBackupKey) == nil,
                "Field deletion kept an older rollback copy"
            )

            _ = try store.update { state in
                state.recordPositiveMoment()
            }
            defaults.set(
                Data("corrupt-after-field-forgetting".utf8),
                forKey: CompanionRelationshipStateStore.defaultStorageKey
            )
            let recovered = CompanionRelationshipStateStore(userDefaults: defaults).load()
            try require(recovered.recentAssetIDs.isEmpty, "Playback history was resurrected")
            try require(recovered.surpriseProgress == 0, "Surprise progress was resurrected")
        }

        await run("Workday state is privacy-minimal and round-trips", reporter: reporter) {
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            var original = CompanionWorkdayStateV1(dayIdentifier: "2027-01-15")
            original.recordStarted(at: now)
            original.recordResponseReady(at: now.addingTimeInterval(5))
            original.recordCompletion(
                duration: 12 * 60,
                recoveredAfterFailure: false,
                at: now.addingTimeInterval(12 * 60)
            )

            let data = try CompanionWorkdayStateCodec.encode(original)
            let decoded = try CompanionWorkdayStateCodec.decode(data)
            try require(decoded == original, "Workday state changed during round-trip")
            let serialized = String(decoding: data, as: UTF8.self)
            for forbidden in ["prompt", "code", "path", "title", "taskRef"] {
                try require(
                    !serialized.localizedCaseInsensitiveContains(forbidden),
                    "Workday schema leaked or exposed \(forbidden)"
                )
            }

            try requireWorkdayError(.invalidDayIdentifier) {
                _ = try CompanionWorkdayStateCodec.encode(
                    CompanionWorkdayStateV1(dayIdentifier: "15 January 2027")
                )
            }
        }

        await run("Work director creates a continuous recovery arc", reporter: reporter) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let start = Date(timeIntervalSince1970: 1_800_000_000)
            var director = CompanionWorkDirector(
                workdayState: CompanionWorkdayStateV1(dayIdentifier: "2027-01-15"),
                calendar: calendar
            )

            let started = director.consume(
                type: .taskStarted,
                eventID: "start-1",
                taskRef: "opaque-1",
                duration: 0,
                occurredAt: start
            )
            try require(started == .focusStarted, "Task start did not begin the work arc")
            let duplicateStart = director.consume(
                type: .taskStarted,
                eventID: "start-duplicate",
                taskRef: "opaque-1",
                duration: 0,
                occurredAt: start.addingTimeInterval(1)
            )
            try require(
                duplicateStart == .focusProgress(elapsed: 1),
                "Duplicate task start replayed the beginning cue"
            )
            try require(
                director.workdayState.startedCount == 1,
                "Duplicate task start inflated the daily memory"
            )

            _ = director.consume(
                type: .taskFailed,
                eventID: "failed-1",
                taskRef: "opaque-1",
                duration: 11 * 60,
                occurredAt: start.addingTimeInterval(11 * 60)
            )
            let completion = director.consume(
                type: .taskCompleted,
                eventID: "complete-1",
                taskRef: "opaque-2",
                duration: 4 * 60,
                occurredAt: start.addingTimeInterval(15 * 60)
            )
            guard case let .completed(context) = completion else {
                throw CheckFailure(message: "Recovery completion was not recognized")
            }
            try require(context.recoveredAfterFailure, "Failure recovery was not remembered")
            try require(context.tier == .signature, "Recovery did not receive signature treatment")
            try require(director.workdayState.failedCount == 1, "Failure was not counted")
            try require(director.workdayState.completedCount == 1, "Completion was not counted")
            try require(
                director.workdayState.recoveredCompletionCount == 1,
                "Recovered completion was not persisted"
            )
            try require(
                director.workdayState.focusedDurationSeconds == 15 * 60,
                "Focused duration did not include both terminal work arcs"
            )
        }

        await run("Workday trust policy rejects false completion claims", reporter: reporter) {
            try require(
                CompanionWorkdaySignalSourcePolicy.origin(
                    source: "codex-skill",
                    sourceVersion: "terminal-events-v1"
                ) == .companionTerminalEmitter,
                "Bundled terminal emitter was not classified"
            )
            try require(
                CompanionWorkdaySignalSourcePolicy.origin(
                    source: "codex-app-server",
                    sourceVersion: "turn-events-v1"
                ) == .codexAppServerTurn,
                "App Server adapter was not classified"
            )
            try require(
                CompanionWorkdaySignalSourcePolicy.origin(
                    source: "codex-skill",
                    sourceVersion: nil
                ) == .explicitProtocol,
                "A producer with a missing contract version was trusted"
            )
            try require(
                CompanionWorkdaySignalTrustPolicy.effectiveType(
                    requestedType: .taskCompleted,
                    outcome: .success,
                    origin: .companionTerminalEmitter
                ) == .taskCompleted,
                "Bundled successful completion was not trusted"
            )
            for outcome in [
                CompanionEventOutcome?.none,
                .some(.unknown)
            ] {
                try require(
                    CompanionWorkdaySignalTrustPolicy.effectiveType(
                        requestedType: .taskCompleted,
                        outcome: outcome,
                        origin: .companionTerminalEmitter
                    ) == .responseReady,
                    "Ambiguous completion was allowed to celebrate"
                )
            }
            try require(
                CompanionWorkdaySignalTrustPolicy.effectiveType(
                    requestedType: .taskCompleted,
                    outcome: .success,
                    origin: .explicitProtocol
                ) == .responseReady,
                "An arbitrary local event source was allowed to celebrate"
            )
            try require(
                CompanionWorkdaySignalTrustPolicy.effectiveType(
                    requestedType: .taskCompleted,
                    outcome: .success,
                    origin: .legacyTurnBoundary
                ) == .responseReady,
                "Legacy turn boundary was allowed to celebrate"
            )
            try require(
                CompanionWorkdaySignalTrustPolicy.effectiveType(
                    requestedType: .taskCompleted,
                    outcome: .failure,
                    origin: .companionTerminalEmitter
                ) == .taskFailed,
                "Explicit failure did not retain its terminal meaning"
            )
            try require(
                CompanionWorkdaySignalTrustPolicy.effectiveType(
                    requestedType: .taskCompleted,
                    outcome: .cancelled,
                    origin: .companionTerminalEmitter
                ) == .taskCancelled,
                "Explicit cancellation did not retain its terminal meaning"
            )
            try require(
                CompanionWorkdaySignalTrustPolicy.effectiveType(
                    requestedType: .taskFailed,
                    outcome: .failure,
                    origin: .codexAppServerTurn
                ) == .taskFailed,
                "App Server failure lost its documented terminal meaning"
            )
            try require(
                CompanionWorkdaySignalTrustPolicy.effectiveType(
                    requestedType: .taskFailed,
                    outcome: .failure,
                    origin: .explicitProtocol
                ) == .responseReady,
                "An unregistered producer was allowed to claim failure"
            )
        }

        await run("Workday presentation policy preserves occupied attention", reporter: reporter) {
            let occupied = CompanionWorkdayPresentationContext(
                allowsPassivePresenceUpdate: false,
                hasActiveWork: true,
                completionReplyWindowActive: false
            )
            let focused = CompanionWorkdayExperiencePolicy.plan(
                for: .focusProgress(elapsed: 75),
                context: occupied
            )
            try require(focused.visual == .working, "Work indicator lost active work")
            try require(focused.mood == nil, "Focus event overwrote an occupied mood")
            try require(focused.status == nil, "Focus event overwrote an occupied status")
            try require(
                focused.contentCue == nil,
                "Progress heartbeat created an occupied audiovisual cue"
            )

            let available = CompanionWorkdayPresentationContext(
                allowsPassivePresenceUpdate: true,
                hasActiveWork: true,
                completionReplyWindowActive: false
            )
            try require(
                CompanionWorkdayExperiencePolicy.plan(
                    for: .focusStarted,
                    context: available
                ).contentCue == .taskStarted,
                "Task start did not expose its declarative content cue"
            )
            try require(
                CompanionWorkdayExperiencePolicy.plan(
                    for: .focusProgress(elapsed: 75),
                    context: available
                ).contentCue == nil,
                "Progress heartbeat became an interruptive content cue"
            )
            try require(
                CompanionWorkdayExperiencePolicy.plan(
                    for: .longRunning(elapsed: 12 * 60),
                    context: available
                ).contentCue == .taskLongRunning,
                "Long-running work lost its declarative content cue"
            )
            try require(
                CompanionWorkdayExperiencePolicy.plan(
                    for: .cancelled,
                    context: CompanionWorkdayPresentationContext(
                        allowsPassivePresenceUpdate: true,
                        hasActiveWork: false,
                        completionReplyWindowActive: false
                    )
                ).contentCue == .taskCancelled,
                "Cancellation lost its declarative content cue"
            )

            let disconnected = CompanionWorkdayExperiencePolicy.plan(
                for: .integrationDisconnected,
                context: occupied
            )
            try require(
                disconnected.mood == nil && disconnected.status == nil,
                "Integration health interrupted foreground play"
            )

            let completion = CompanionCompletionContext(
                duration: 12 * 60,
                completionCountToday: 3,
                recoveredAfterFailure: true,
                tier: .signature
            )
            let completed = CompanionWorkdayExperiencePolicy.plan(
                for: .completed(completion),
                context: occupied
            )
            try require(completed.visual == .completed, "Completion lost visual truth")
            try require(
                completed.event == .taskComplete(completion),
                "Trusted completion did not reach the experience director"
            )
            try require(
                completed.relationshipReward == CompanionWorkdayRelationshipReward(
                    bond: 3,
                    chemistry: 1,
                    milestones: [
                        .longFocus,
                        .threeCompletions,
                        .recoveredAfterFailure,
                    ]
                ),
                "Completion milestones drifted from the shared work arc"
            )

            let firstCompletion = CompanionCompletionContext(
                duration: 0,
                completionCountToday: 1,
                recoveredAfterFailure: false,
                tier: .quiet
            )
            let firstPlan = CompanionWorkdayExperiencePolicy.plan(
                for: .completed(firstCompletion),
                context: occupied
            )
            try require(
                firstPlan.relationshipReward?.milestones == [.firstCompletion],
                "First-completion memento was not deterministic"
            )
        }

        await run("Task completion celebration is tiered and romance-capped", reporter: reporter) {
            let quiet = CompanionTaskCompletionPolicy.celebration(
                tier: .quiet,
                recoveredAfterFailure: false,
                allowsRomanticGestures: true,
                variation: 42
            )
            try require(
                quiet == CompanionTaskCompletionCelebrationPlan(
                    copy: .quiet,
                    rewardBeat: .clap
                ),
                "Quiet completion changed its bounded celebration"
            )

            let warm = CompanionTaskCompletionPolicy.celebration(
                tier: .warm,
                recoveredAfterFailure: false,
                allowsRomanticGestures: false,
                variation: 99
            )
            try require(warm.copy == .warm, "Warm completion lost its copy intent")
            try require(warm.rewardBeat == .cheer, "Warm completion lost its cheer")

            let playful = Set((0..<3).map {
                CompanionTaskCompletionPolicy.celebration(
                    tier: .playful,
                    recoveredAfterFailure: false,
                    allowsRomanticGestures: false,
                    variation: UInt64($0)
                ).rewardBeat
            })
            try require(
                playful == Set([.jump, .twirl, .clap]),
                "Playful completion variation became incomplete"
            )

            let romanticSignature = Set((0..<3).map {
                CompanionTaskCompletionPolicy.celebration(
                    tier: .signature,
                    recoveredAfterFailure: false,
                    allowsRomanticGestures: true,
                    variation: UInt64($0)
                ).rewardBeat
            })
            try require(
                romanticSignature == Set([.heart, .kiss, .twirl]),
                "Romantic signature completion lost an allowed reward"
            )

            let cappedSignature = Set((0..<3).map {
                CompanionTaskCompletionPolicy.celebration(
                    tier: .signature,
                    recoveredAfterFailure: false,
                    allowsRomanticGestures: false,
                    variation: UInt64($0)
                ).rewardBeat
            })
            try require(
                cappedSignature == Set([.jump, .cheer, .twirl]),
                "Relationship-tone ceiling allowed a romantic reward"
            )
            try require(
                cappedSignature.isDisjoint(with: [.heart, .kiss]),
                "Capped completion retained a romantic reward"
            )

            let recovered = CompanionTaskCompletionPolicy.celebration(
                tier: .signature,
                recoveredAfterFailure: true,
                allowsRomanticGestures: false,
                variation: 0
            )
            try require(
                recovered.copy == .recovered,
                "Recovery completion did not preserve its supportive copy intent"
            )
        }

        await run("Task completion replies are bounded and privacy-minimal", reporter: reporter) {
            let expectedSafe: [
                CompanionCompletionReplyGesture: CompanionTaskCompletionRewardBeat
            ] = [
                .singleTap: .clap,
                .doubleTap: .twirl,
                .longPress: .heart,
                .drag: .twirl,
            ]
            let expectedRomantic: [
                CompanionCompletionReplyGesture: CompanionTaskCompletionRewardBeat
            ] = [
                .singleTap: .heart,
                .doubleTap: .kiss,
                .longPress: .kiss,
                .drag: .twirl,
            ]

            for gesture in CompanionCompletionReplyGesture.allCases {
                let safe = CompanionTaskCompletionPolicy.reply(
                    to: gesture,
                    allowsRomanticGestures: false
                )
                let romantic = CompanionTaskCompletionPolicy.reply(
                    to: gesture,
                    allowsRomanticGestures: true
                )
                try require(
                    safe.relationshipKey == "reply.\(gesture.rawValue)",
                    "Reply key no longer matches its bounded gesture"
                )
                try require(
                    safe.relationshipKey.utf8.count <= 24,
                    "Reply key exceeded its bounded diagnostic shape"
                )
                try require(
                    safe.bond == 2 && romantic.bond == 2,
                    "Reply relationship reward changed by tone"
                )
                try require(
                    safe.chemistry == (gesture == .longPress ? 2 : 1),
                    "Reply chemistry drifted from the gesture contract"
                )
                try require(
                    safe.rewardBeat == expectedSafe[gesture],
                    "Safe reply ignored the relationship-tone ceiling"
                )
                try require(
                    romantic.rewardBeat == expectedRomantic[gesture],
                    "Romantic reply lost its intended reward"
                )
                for forbidden in ["prompt", "code", "path", "title", "task"] {
                    try require(
                        !safe.relationshipKey.localizedCaseInsensitiveContains(forbidden),
                        "Reply key leaked work-content vocabulary"
                    )
                }
            }
        }

        await run("Pet drag feedback priority covers every direct outcome", reporter: reporter) {
            let fling = CompanionPetDragPolicy.plan(
                for: CompanionPetDragInput(
                    translationX: 0,
                    translationY: 100,
                    velocityX: 901,
                    velocityY: 0,
                    windowMoveObserved: true,
                    dockEdge: .right
                )
            )
            try require(fling.feedback == .fling, "A fast docked release stopped being a fling")
            try require(fling.dockEdge == .right, "Fling lost its landing edge")
            try require(fling.pose.rotation == 13, "Fling direction changed")
            try require(
                fling.relationshipMomentKey == "interaction.fling",
                "Fling relationship event became ambiguous"
            )

            let dock = CompanionPetDragPolicy.plan(
                for: CompanionPetDragInput(
                    translationX: 0,
                    translationY: 100,
                    velocityX: 100,
                    velocityY: 0,
                    windowMoveObserved: true,
                    dockEdge: .left
                )
            )
            try require(dock.feedback == .dock, "A slow edge landing stopped being a dock")
            try require(dock.pose.x == -5 && dock.pose.rotation == -5, "Left dock pose drifted")
            try require(dock.poseResetDelay == 1.15, "Dock feedback became too brief")

            let lift = CompanionPetDragPolicy.plan(
                for: CompanionPetDragInput(
                    translationX: 0,
                    translationY: 71,
                    velocityX: 0,
                    velocityY: 0,
                    windowMoveObserved: false,
                    dockEdge: nil
                )
            )
            try require(lift.feedback == .lift, "Upward release lost lift feedback")

            let nudge = CompanionPetDragPolicy.plan(
                for: CompanionPetDragInput(
                    translationX: 10,
                    translationY: 0,
                    velocityX: 0,
                    velocityY: 0,
                    windowMoveObserved: false,
                    dockEdge: nil
                )
            )
            try require(nudge.feedback == .nudge, "Short drag no longer feels like a nudge")

            let settle = CompanionPetDragPolicy.plan(
                for: CompanionPetDragInput(
                    translationX: 25,
                    translationY: 0,
                    velocityX: 0,
                    velocityY: 0,
                    windowMoveObserved: false,
                    dockEdge: nil
                )
            )
            try require(settle.feedback == .settle, "Moved pet no longer settles")
            try require(
                settle.relationshipMomentKey == "interaction.drag",
                "Non-fling drag relationship event changed"
            )
        }

        await run("Pet drag feedback normalizes malformed pointer geometry", reporter: reporter) {
            let malformed = CompanionPetDragPolicy.plan(
                for: CompanionPetDragInput(
                    translationX: .nan,
                    translationY: .infinity,
                    velocityX: -.infinity,
                    velocityY: .nan,
                    windowMoveObserved: false,
                    dockEdge: nil
                )
            )
            try require(malformed.feedback == .nudge, "Malformed input escaped to a dramatic gesture")
            for value in [
                malformed.pose.x,
                malformed.pose.y,
                malformed.pose.rotation,
                malformed.pose.scale,
                malformed.poseResetDelay,
            ] {
                try require(value.isFinite, "Malformed drag produced non-finite presentation geometry")
            }

            let extreme = CompanionPetDragPolicy.plan(
                for: CompanionPetDragInput(
                    translationX: .greatestFiniteMagnitude,
                    translationY: -.greatestFiniteMagnitude,
                    velocityX: -.greatestFiniteMagnitude,
                    velocityY: .greatestFiniteMagnitude,
                    windowMoveObserved: true,
                    dockEdge: .top
                )
            )
            try require(extreme.feedback == .fling, "Extreme finite velocity lost deterministic classification")
            try require(abs(extreme.pose.x) <= 12, "Extreme drag escaped horizontal pose bounds")
            try require(abs(extreme.pose.rotation) <= 13, "Extreme drag escaped rotation bounds")
            try require(extreme.pose.scale <= 1.06, "Extreme drag escaped scale bounds")
        }

        await run("Workday state rolls over without carrying yesterday's score", reporter: reporter) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let firstDay = Date(timeIntervalSince1970: 1_800_000_000)
            var state = CompanionWorkdayStateV1(dayIdentifier: "2027-01-15")
            state.recordCompletion(
                duration: 45 * 60,
                recoveredAfterFailure: false,
                at: firstDay
            )
            var director = CompanionWorkDirector(workdayState: state, calendar: calendar)
            _ = director.refreshDay(at: firstDay.addingTimeInterval(24 * 60 * 60))
            try require(
                director.workdayState.dayIdentifier == "2027-01-16",
                "Workday did not advance to the injected local day"
            )
            try require(
                director.workdayState.completedCount == 0,
                "Yesterday's completion count became a streak or penalty"
            )
            try require(
                director.workdayState.focusedDurationSeconds == 0,
                "Yesterday's duration leaked into the new day"
            )
        }

        await run("Workday store recovers the last valid snapshot", reporter: reporter) {
            let suiteName = "cc.chengyin.workday-tests.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                throw CheckFailure(message: "Could not create isolated UserDefaults")
            }
            defaults.removePersistentDomain(forName: suiteName)
            defer { defaults.removePersistentDomain(forName: suiteName) }

            let store = CompanionWorkdayStateStore(userDefaults: defaults)
            var first = CompanionWorkdayStateV1(dayIdentifier: "2027-01-15")
            first.recordStarted(at: Date(timeIntervalSince1970: 1_800_000_000))
            try store.save(first)

            var second = first
            second.recordCompletion(
                duration: 10 * 60,
                recoveredAfterFailure: false,
                at: Date(timeIntervalSince1970: 1_800_000_600)
            )
            try store.save(second)
            let primary = CompanionWorkdayStateStore(userDefaults: defaults)
                .loadWithRecovery(dayIdentifier: "2027-01-15")
            try require(
                primary.recoverySource == .primary
                    && primary.state.completedCount == 1,
                "Valid primary workday recovery was not reported"
            )
            defaults.set(
                Data("corrupt-primary".utf8),
                forKey: CompanionWorkdayStateStore.defaultStorageKey
            )

            let recovered = CompanionWorkdayStateStore(userDefaults: defaults)
                .loadWithRecovery(dayIdentifier: "2027-01-15")
            try require(
                recovered.recoverySource == .backup,
                "Workday backup recovery was not reported"
            )
            try require(recovered.state.startedCount == 1, "Workday backup was not recovered")
            try require(recovered.state.completedCount == 0, "Corrupt primary was trusted")
        }

        await run("Explicit workday forgetting clears rollback data", reporter: reporter) {
            let suiteName = "cc.chengyin.workday-forget.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                throw CheckFailure(message: "Could not create isolated UserDefaults")
            }
            defaults.removePersistentDomain(forName: suiteName)
            defer { defaults.removePersistentDomain(forName: suiteName) }

            let store = CompanionWorkdayStateStore(userDefaults: defaults)
            var state = CompanionWorkdayStateV1(dayIdentifier: "2027-01-15")
            state.recordCompletion(
                duration: 12 * 60,
                recoveredAfterFailure: true,
                at: Date(timeIntervalSince1970: 1_800_000_000)
            )
            try store.save(state)
            let forgotten = try store.reset(dayIdentifier: "2027-01-15")
            try require(forgotten.completedCount == 0, "Explicit reset kept completions")
            try require(
                defaults.data(forKey: CompanionWorkdayStateStore.defaultBackupKey) == nil,
                "Explicit reset kept a rollback copy of deleted memory"
            )
            defaults.set(
                Data("corrupt-after-reset".utf8),
                forKey: CompanionWorkdayStateStore.defaultStorageKey
            )
            let recovered = CompanionWorkdayStateStore(userDefaults: defaults)
                .loadWithRecovery(dayIdentifier: "2027-01-15")
            try require(
                recovered.recoverySource == .safeDefault,
                "Corrupt reset state did not report safe-default recovery"
            )
            try require(
                recovered.state.completedCount == 0,
                "Deleted workday memory was resurrected after corruption"
            )
        }

        await run("Care-rhythm memory is bounded and privacy-minimal", reporter: reporter) {
            let base = Date(timeIntervalSince1970: 1_800_000_000)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            var state = CompanionLifestyleMemoryV1(
                activityAnchor: base.addingTimeInterval(-60 * 60),
                dayIdentifier: CompanionLifestyleMemoryV1.dayIdentifier(
                    for: base,
                    calendar: calendar
                )
            )
            state.recordReminder(.hydration, at: base, calendar: calendar)
            state.setPausedUntil(base.addingTimeInterval(60 * 60), at: base)
            let encoded = try CompanionLifestyleMemoryCodec.encode(state)
            let decoded = try CompanionLifestyleMemoryCodec.decode(encoded)
            try require(decoded == state, "Care-rhythm memory changed during round-trip")
            try require(
                encoded.count <= CompanionLifestyleMemoryV1.maximumPayloadBytes,
                "Care-rhythm memory exceeded its payload bound"
            )
            let visible = String(decoding: encoded, as: UTF8.self).lowercased()
            for forbidden in ["/users/", "prompt", "task", "source code", "repository"] {
                try require(!visible.contains(forbidden), "Care memory exposed \(forbidden)")
            }
        }

        await run("Care-rhythm recovery rejects stale and future state", reporter: reporter) {
            let base = Date(timeIntervalSince1970: 1_800_000_000)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            var state = CompanionLifestyleMemoryV1(
                activityAnchor: base.addingTimeInterval(-19 * 60 * 60),
                lastReminder: CompanionLifestyleReminderOccurrence(
                    kind: .hydration,
                    date: base.addingTimeInterval(60)
                ),
                lastReminderByKind: [
                    .hydration: base.addingTimeInterval(-8 * 24 * 60 * 60)
                ],
                dailyCounts: [.hydration: 9],
                dayIdentifier: "2020-01-01",
                pausedUntil: base.addingTimeInterval(8 * 24 * 60 * 60)
            )
            state.normalize(at: base, calendar: calendar)
            try require(state.activityAnchor == base, "Stale activity anchor survived")
            try require(state.lastReminder == nil, "Future reminder survived")
            try require(state.lastReminderByKind.isEmpty, "Stale kind cooldown survived")
            try require(state.dailyCounts.isEmpty, "Yesterday's care counts survived")
            try require(state.pausedUntil == nil, "Unbounded pause survived")
            try require(
                state.randomSeed()
                    == (UInt64(state.dayIdentifier.filter(\.isNumber)) ?? 0),
                "Care seed no longer follows the recovered local day"
            )
        }

        await run("Care-rhythm store migrates and projects legacy state", reporter: reporter) {
            let suiteName = "cc.chengyin.care-migrate.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                throw CheckFailure(message: "Could not create isolated UserDefaults")
            }
            defaults.removePersistentDomain(forName: suiteName)
            defer { defaults.removePersistentDomain(forName: suiteName) }

            let base = Date(timeIntervalSince1970: 1_800_000_000)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let day = CompanionLifestyleMemoryV1.dayIdentifier(for: base, calendar: calendar)
            defaults.set(
                base.addingTimeInterval(-60 * 60),
                forKey: CompanionLifestyleMemoryStore.LegacyKey.activityAnchor
            )
            defaults.set(
                base.addingTimeInterval(-10 * 60),
                forKey: CompanionLifestyleMemoryStore.LegacyKey.lastReminderAt
            )
            defaults.set(
                CompanionLifestyleReminderKind.hydration.rawValue,
                forKey: CompanionLifestyleMemoryStore.LegacyKey.lastReminderKind
            )
            defaults.set(
                [CompanionLifestyleReminderKind.hydration.rawValue: 2],
                forKey: CompanionLifestyleMemoryStore.LegacyKey.dailyCounts
            )
            defaults.set(day, forKey: CompanionLifestyleMemoryStore.LegacyKey.dailyDay)

            let result = CompanionLifestyleMemoryStore(userDefaults: defaults)
                .load(at: base, calendar: calendar)
            try require(
                result.recoverySource == .legacyProjection,
                "Legacy care memory did not report migration"
            )
            try require(result.state.dailyCounts[.hydration] == 2, "Legacy count was lost")
            try require(result.state.lastReminder?.kind == .hydration, "Legacy kind was lost")
            let primary = defaults.data(
                forKey: CompanionLifestyleMemoryStore.defaultStorageKey
            )
            try require(primary != nil, "Migration did not publish a canonical payload")
            _ = try CompanionLifestyleMemoryCodec.decode(primary!)
            try require(
                defaults.object(
                    forKey: CompanionLifestyleMemoryStore.LegacyKey.activityAnchor
                ) != nil,
                "Migration removed downgrade-compatible state"
            )
        }

        await run("Care-rhythm store recovers the last valid snapshot", reporter: reporter) {
            let suiteName = "cc.chengyin.care-backup.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                throw CheckFailure(message: "Could not create isolated UserDefaults")
            }
            defaults.removePersistentDomain(forName: suiteName)
            defer { defaults.removePersistentDomain(forName: suiteName) }

            let base = Date(timeIntervalSince1970: 1_800_000_000)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let store = CompanionLifestyleMemoryStore(userDefaults: defaults)
            _ = store.load(at: base, calendar: calendar)
            _ = try store.update(at: base, calendar: calendar) { state in
                state.recordReminder(.hydration, at: base, calendar: calendar)
            }
            _ = try store.update(
                at: base.addingTimeInterval(60),
                calendar: calendar
            ) { state in
                state.recordReminder(
                    .sedentaryMovement,
                    at: base.addingTimeInterval(60),
                    calendar: calendar
                )
            }
            defaults.set(
                Data("corrupt-primary".utf8),
                forKey: CompanionLifestyleMemoryStore.defaultStorageKey
            )

            let recovered = CompanionLifestyleMemoryStore(userDefaults: defaults)
                .load(at: base.addingTimeInterval(120), calendar: calendar)
            try require(recovered.recoverySource == .backup, "Care backup was not used")
            try require(
                recovered.state.dailyCounts[.hydration] == 1,
                "Last valid care snapshot was not recovered"
            )
            try require(
                recovered.state.dailyCounts[.sedentaryMovement] == nil,
                "Corrupt primary care state was trusted"
            )
        }

        await run("Explicit care-memory deletion clears rollback history", reporter: reporter) {
            let suiteName = "cc.chengyin.care-forget.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                throw CheckFailure(message: "Could not create isolated UserDefaults")
            }
            defaults.removePersistentDomain(forName: suiteName)
            defer { defaults.removePersistentDomain(forName: suiteName) }

            let base = Date(timeIntervalSince1970: 1_800_000_000)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let store = CompanionLifestyleMemoryStore(userDefaults: defaults)
            _ = store.load(at: base, calendar: calendar)
            _ = try store.update(at: base, calendar: calendar) { state in
                state.recordReminder(.eyeRest, at: base, calendar: calendar)
            }
            _ = try store.update(
                at: base.addingTimeInterval(60),
                calendar: calendar
            ) { state in
                state.recordReminder(
                    .focusEncouragement,
                    at: base.addingTimeInterval(60),
                    calendar: calendar
                )
            }
            let reset = try store.reset(at: base.addingTimeInterval(120), calendar: calendar)
            try require(reset.dailyCounts.isEmpty, "Explicit care reset kept counts")
            try require(reset.lastReminder == nil, "Explicit care reset kept last reminder")
            try require(
                defaults.data(forKey: CompanionLifestyleMemoryStore.defaultBackupKey) == nil,
                "Explicit care reset kept a rollback copy"
            )
            defaults.set(
                Data("corrupt-after-reset".utf8),
                forKey: CompanionLifestyleMemoryStore.defaultStorageKey
            )
            let recovered = CompanionLifestyleMemoryStore(userDefaults: defaults)
                .load(at: base.addingTimeInterval(180), calendar: calendar)
            try require(
                recovered.state.dailyCounts.isEmpty && recovered.state.lastReminder == nil,
                "Deleted care memory was resurrected"
            )
        }

        await run("Care-rhythm codec rejects unsupported and invalid state", reporter: reporter) {
            try requireLifestyleMemoryError(.unsupportedSchema) {
                _ = try CompanionLifestyleMemoryCodec.decode(
                    Data(#"{"schemaVersion":2}"#.utf8)
                )
            }
            try requireLifestyleMemoryError(.invalidDailyCount) {
                _ = try CompanionLifestyleMemoryCodec.encode(
                    CompanionLifestyleMemoryV1(
                        dailyCounts: [.hydration: -1],
                        dayIdentifier: "2027-01-15"
                    )
                )
            }
        }

        await run("Attention budget keeps turn boundaries subtle", reporter: reporter) {
            let base = Date(timeIntervalSince1970: 1_800_000_000)
            var budget = CompanionAttentionBudget(
                policy: CompanionAttentionPolicy(
                    responseReadyCooldown: 2 * 60,
                    responseReadyLimitPerHour: 2,
                    proactiveLimitPerHour: 3
                )
            )
            let available = CompanionAttentionContext(
                now: base,
                isPresentationBusy: false,
                isQuietHours: false
            )
            try require(
                budget.decide(for: .responseReady, context: available) == .present,
                "First response-ready cue was not presented"
            )
            try require(
                budget.decide(
                    for: .responseReady,
                    context: CompanionAttentionContext(
                        now: base.addingTimeInterval(30),
                        isPresentationBusy: false,
                        isQuietHours: false
                    )
                ) == .ambientOnly(reason: .sameKindCooldown),
                "Rapid turn boundary caused another full interruption"
            )
            try require(
                budget.decide(
                    for: .responseReady,
                    context: CompanionAttentionContext(
                        now: base.addingTimeInterval(3 * 60),
                        isPresentationBusy: true,
                        isQuietHours: false
                    )
                ) == .ambientOnly(reason: .presentationBusy),
                "Busy presentation was interrupted by a turn boundary"
            )
            try require(
                budget.decide(
                    for: .responseReady,
                    context: CompanionAttentionContext(
                        now: base.addingTimeInterval(3 * 60),
                        isPresentationBusy: false,
                        isQuietHours: true
                    )
                ) == .ambientOnly(reason: .quietHours),
                "Quiet hours played a full turn-boundary response"
            )
        }

        await run("Attention budget never loses trusted terminal events", reporter: reporter) {
            let base = Date(timeIntervalSince1970: 1_800_000_000)
            var budget = CompanionAttentionBudget(
                policy: CompanionAttentionPolicy(
                    responseReadyCooldown: 3_600,
                    responseReadyLimitPerHour: 0,
                    proactiveLimitPerHour: 0
                )
            )
            let blockedContext = CompanionAttentionContext(
                now: base,
                isPresentationBusy: true,
                isQuietHours: true
            )
            try require(
                budget.decide(for: .taskTerminal, context: blockedContext) == .present,
                "Trusted terminal event was suppressed by the proactive budget"
            )
            try require(
                budget.decide(for: .userInitiated, context: blockedContext) == .present,
                "Direct user interaction was suppressed by the proactive budget"
            )
        }

        await run("Direct play grants a bounded post-interaction silence", reporter: reporter) {
            let base = Date(timeIntervalSince1970: 1_800_000_000)
            var budget = CompanionAttentionBudget(
                policy: CompanionAttentionPolicy(
                    postUserInteractionSilence: 45,
                    responseReadyCooldown: 0,
                    responseReadyLimitPerHour: 4,
                    proactiveLimitPerHour: 4
                )
            )
            let available: (Date) -> CompanionAttentionContext = { date in
                CompanionAttentionContext(
                    now: date,
                    isPresentationBusy: false,
                    isQuietHours: false
                )
            }
            try require(
                budget.decide(for: .userInitiated, context: available(base)) == .present,
                "Direct play did not start its local attention grace"
            )
            let insideGrace = available(base.addingTimeInterval(12))
            try require(
                budget.decide(for: .lifestyleCare, context: insideGrace)
                    == .suppress(reason: .recentUserInteraction),
                "Scheduled care spoke immediately after direct play"
            )
            try require(
                budget.decide(for: .responseReady, context: insideGrace)
                    == .ambientOnly(reason: .recentUserInteraction),
                "A response-ready cue replaced the direct-play response"
            )
            try require(
                budget.decide(for: .taskTerminal, context: insideGrace) == .present,
                "The post-interaction grace lost a trusted terminal event"
            )
            try require(
                budget.decide(
                    for: .lifestyleCare,
                    context: available(base.addingTimeInterval(46))
                ) == .present,
                "Scheduled care did not recover after the bounded grace"
            )
        }

        await run("Experience director queues terminals without interrupting play", reporter: reporter) {
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            var director = CompanionExperienceDirector()
            let playing = CompanionExperienceContext(
                now: now,
                isDirectInteractionActive: true,
                isGameplayActive: false,
                isMediaPlaybackActive: false,
                isSpeaking: false,
                isQuietHours: false
            )
            try require(
                director.decide(
                    for: .trustedTaskTerminal,
                    context: playing
                ) == .enqueue(reason: .presentationBusy),
                "Trusted terminal event interrupted direct play"
            )

            let idle = CompanionExperienceContext(
                now: now.addingTimeInterval(5),
                isDirectInteractionActive: false,
                isGameplayActive: false,
                isMediaPlaybackActive: false,
                isSpeaking: false,
                isQuietHours: true
            )
            try require(
                director.decide(
                    for: .trustedTaskTerminal,
                    context: idle
                ) == .present,
                "Queued terminal event was lost after the stage became idle"
            )
        }

        await run("Experience director keeps care and response cues subordinate", reporter: reporter) {
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            var director = CompanionExperienceDirector()
            let busy = CompanionExperienceContext(
                now: now,
                isDirectInteractionActive: false,
                isGameplayActive: true,
                isMediaPlaybackActive: false,
                isSpeaking: false,
                isQuietHours: false
            )
            try require(
                director.decide(
                    for: .proactiveCare,
                    context: busy
                ) == .deferUntilNextEvaluation(reason: .presentationBusy),
                "Proactive care interrupted gameplay"
            )
            try require(
                director.decide(
                    for: .responseReady,
                    context: busy
                ) == .ambientOnly(reason: .presentationBusy),
                "Response-ready cue interrupted gameplay"
            )
            try require(
                director.decide(
                    for: .userInitiated,
                    context: busy
                ) == .present,
                "Direct user play was delayed by the companion"
            )
        }

        await run("Experience director maps direct-play grace consistently", reporter: reporter) {
            let base = Date(timeIntervalSince1970: 1_800_000_000)
            var director = CompanionExperienceDirector(
                attentionPolicy: CompanionAttentionPolicy(
                    postUserInteractionSilence: 45,
                    responseReadyCooldown: 0,
                    responseReadyLimitPerHour: 4,
                    proactiveLimitPerHour: 4
                )
            )
            func context(_ seconds: TimeInterval) -> CompanionExperienceContext {
                CompanionExperienceContext(
                    now: base.addingTimeInterval(seconds),
                    isDirectInteractionActive: false,
                    isGameplayActive: false,
                    isMediaPlaybackActive: false,
                    isSpeaking: false,
                    isQuietHours: false
                )
            }
            try require(
                director.decide(for: .userInitiated, context: context(0)) == .present,
                "Director did not register explicit local play"
            )
            try require(
                director.decide(for: .proactiveCare, context: context(20))
                    == .deferUntilNextEvaluation(reason: .recentUserInteraction),
                "Director did not defer care during direct-play grace"
            )
            try require(
                director.decide(for: .responseReady, context: context(20))
                    == .ambientOnly(reason: .recentUserInteraction),
                "Director did not keep response-ready subtle during direct-play grace"
            )
            try require(
                director.decide(for: .trustedTaskTerminal, context: context(20)) == .present,
                "Director suppressed a trusted terminal during direct-play grace"
            )
        }

        await run("Experience director shares one proactive hourly budget", reporter: reporter) {
            let base = Date(timeIntervalSince1970: 1_800_000_000)
            var director = CompanionExperienceDirector(
                attentionPolicy: CompanionAttentionPolicy(
                    responseReadyCooldown: 0,
                    responseReadyLimitPerHour: 4,
                    proactiveLimitPerHour: 1
                )
            )
            let first = CompanionExperienceContext(
                now: base,
                isDirectInteractionActive: false,
                isGameplayActive: false,
                isMediaPlaybackActive: false,
                isSpeaking: false,
                isQuietHours: false
            )
            try require(
                director.decide(for: .proactiveCare, context: first) == .present,
                "First proactive care cue was not presented"
            )
            let second = CompanionExperienceContext(
                now: base.addingTimeInterval(10 * 60),
                isDirectInteractionActive: false,
                isGameplayActive: false,
                isMediaPlaybackActive: false,
                isSpeaking: false,
                isQuietHours: false
            )
            try require(
                director.decide(
                    for: .responseReady,
                    context: second
                ) == .ambientOnly(reason: .hourlyBudgetReached),
                "Care and Codex cues did not share one interruption budget"
            )
        }

        await run("Experience director decision matrix is exhaustive", reporter: reporter) {
            let now = Date(timeIntervalSince1970: 1_800_100_000)
            let contexts: [(String, CompanionExperienceContext)] = [
                (
                    "idle",
                    CompanionExperienceContext(
                        now: now,
                        isDirectInteractionActive: false,
                        isGameplayActive: false,
                        isMediaPlaybackActive: false,
                        isSpeaking: false,
                        isQuietHours: false
                    )
                ),
                (
                    "direct interaction",
                    CompanionExperienceContext(
                        now: now,
                        isDirectInteractionActive: true,
                        isGameplayActive: false,
                        isMediaPlaybackActive: false,
                        isSpeaking: false,
                        isQuietHours: false
                    )
                ),
                (
                    "gameplay",
                    CompanionExperienceContext(
                        now: now,
                        isDirectInteractionActive: false,
                        isGameplayActive: true,
                        isMediaPlaybackActive: false,
                        isSpeaking: false,
                        isQuietHours: false
                    )
                ),
                (
                    "media",
                    CompanionExperienceContext(
                        now: now,
                        isDirectInteractionActive: false,
                        isGameplayActive: false,
                        isMediaPlaybackActive: true,
                        isSpeaking: false,
                        isQuietHours: false
                    )
                ),
                (
                    "speech",
                    CompanionExperienceContext(
                        now: now,
                        isDirectInteractionActive: false,
                        isGameplayActive: false,
                        isMediaPlaybackActive: false,
                        isSpeaking: true,
                        isQuietHours: false
                    )
                ),
                (
                    "quiet hours",
                    CompanionExperienceContext(
                        now: now,
                        isDirectInteractionActive: false,
                        isGameplayActive: false,
                        isMediaPlaybackActive: false,
                        isSpeaking: false,
                        isQuietHours: true
                    )
                )
            ]
            let sources: [CompanionExperienceSource] = [
                .userInitiated,
                .trustedTaskTerminal,
                .responseReady,
                .proactiveCare,
                .ambientPresence
            ]

            func expected(
                source: CompanionExperienceSource,
                contextName: String
            ) -> CompanionExperienceDecision {
                let busy = [
                    "direct interaction",
                    "gameplay",
                    "media",
                    "speech"
                ].contains(contextName)
                switch source {
                case .userInitiated:
                    return .present
                case .trustedTaskTerminal:
                    return busy
                        ? .enqueue(reason: .presentationBusy)
                        : .present
                case .responseReady:
                    if contextName == "quiet hours" {
                        return .ambientOnly(reason: .quietHours)
                    }
                    return busy
                        ? .ambientOnly(reason: .presentationBusy)
                        : .present
                case .proactiveCare, .ambientPresence:
                    if contextName == "quiet hours" {
                        return .deferUntilNextEvaluation(reason: .quietHours)
                    }
                    return busy
                        ? .deferUntilNextEvaluation(reason: .presentationBusy)
                        : .present
                }
            }

            for source in sources {
                for (contextName, context) in contexts {
                    var director = CompanionExperienceDirector()
                    let actual = director.decide(for: source, context: context)
                    try require(
                        actual == expected(source: source, contextName: contextName),
                        "Unexpected \(source.rawValue) decision in \(contextName): \(actual)"
                    )
                }
            }
        }

        await run("Direct pet and magic-wand play expands then returns", reporter: reporter) {
            let policy = CompanionUserPresentationPolicy()
            let pet = policy.plan(
                for: .petInteraction,
                currentMode: .pet,
                audiovisualEnabled: true
            )
            try require(pet.targetMode == .stage, "Pet interaction did not open the stage")
            try require(pet.returnMode == .pet, "Pet interaction lost its return mode")

            let wand = policy.plan(
                for: .magicWand,
                currentMode: .pet,
                audiovisualEnabled: true
            )
            try require(wand == pet, "Magic-wand play diverged from pet expansion")

            let alreadyExpanded = policy.plan(
                for: .magicWand,
                currentMode: .stage,
                audiovisualEnabled: true
            )
            try require(
                alreadyExpanded == .unchanged,
                "Magic-wand play replaced an already expanded user mode"
            )
        }

        await run("Game rewards expand fully while audio-only stays still", reporter: reporter) {
            let policy = CompanionUserPresentationPolicy()
            let reward = policy.plan(
                for: .gameReward,
                currentMode: .stage,
                audiovisualEnabled: true
            )
            try require(reward.targetMode == .fullscreen, "Game reward was not promoted")
            try require(reward.returnMode == .stage, "Game reward lost the game stage")

            let audioOnly = policy.plan(
                for: .gameReward,
                currentMode: .pet,
                audiovisualEnabled: false
            )
            try require(
                audioOnly == .unchanged,
                "Audio-only mode unexpectedly changed the window"
            )
        }

        await run("Direct presentation session survives rapid play and fallback", reporter: reporter) {
            let policy = CompanionUserPresentationPolicy()
            var session = CompanionPresentationSession()

            let first = policy.plan(
                for: .petInteraction,
                currentMode: .pet,
                audiovisualEnabled: true
            )
            try require(
                session.beginDirectUserPlan(first) == .stage,
                "First pet interaction did not request the stage"
            )
            try require(
                session.returnMode == .pet && session.directUserOwnsReturn,
                "First pet interaction did not own its pet restoration"
            )

            let rapidSecond = policy.plan(
                for: .magicWand,
                currentMode: .stage,
                audiovisualEnabled: true
            )
            try require(
                session.beginDirectUserPlan(rapidSecond) == nil,
                "Already-expanded rapid play requested a redundant transition"
            )
            session.setAutomaticReturnMode(nil)
            try require(
                session.returnMode == .pet && session.directUserOwnsReturn,
                "Pack return policy overrode direct-play restoration"
            )

            try require(
                session.finish(continuesIntoFallback: true) == nil,
                "Failed media collapsed before its local fallback"
            )
            try require(
                session.returnMode == .pet,
                "Fallback handoff discarded the original pet mode"
            )
            try require(
                session.finish() == .pet,
                "Fallback completion did not restore the pet"
            )
            try require(
                session.returnMode == nil && session.returnOwner == nil,
                "Completed presentation session retained stale state"
            )
        }

        await run("Game reward presentation restores the exact pre-game mode", reporter: reporter) {
            let policy = CompanionUserPresentationPolicy()
            var session = CompanionPresentationSession()
            let reward = policy.plan(
                for: .gameReward,
                currentMode: .stage,
                audiovisualEnabled: true
            )
            try require(
                session.beginDirectUserPlan(reward) == .fullscreen,
                "Game reward did not request fullscreen"
            )
            session.setDirectReturnMode(.pet)
            try require(
                session.finish() == .pet,
                "Explicit pre-game restoration was not honored"
            )
        }

        await run("Unified presentation lifecycle covers every audiovisual entrance", reporter: reporter) {
            let policy = CompanionUserPresentationPolicy()

            var direct = CompanionPresentationLifecycle()
            let petPlan = policy.plan(
                for: .petInteraction,
                currentMode: .pet,
                audiovisualEnabled: true
            )
            let petDirective = direct.beginDirectUserPlan(petPlan)
            try require(
                petDirective.targetMode == .stage
                    && petDirective.directUserOwnsReturn,
                "Pet click did not acquire a visible stage session"
            )
            try require(
                direct.finish(continuesIntoFallback: true) == nil,
                "Generated-media fallback collapsed the direct session"
            )
            try require(
                direct.finish() == .pet,
                "Direct visual fallback did not return to the pet"
            )

            var automatic = CompanionPresentationLifecycle()
            let automaticDirective = automatic.beginAutomaticResponse(
                currentMode: .pet
            )
            try require(
                automaticDirective.targetMode == .stage,
                "Automatic care/task response did not open the stage"
            )
            try require(
                automatic.finish() == .pet,
                "Automatic care/task response did not return to the pet"
            )

            var reward = CompanionPresentationLifecycle()
            let rewardPlan = policy.plan(
                for: .gameReward,
                currentMode: .pet,
                audiovisualEnabled: true
            )
            let rewardDirective = reward.beginDirectUserPlan(rewardPlan)
            try require(
                rewardDirective.targetMode == .fullscreen,
                "Game reward did not acquire fullscreen presentation"
            )
            reward.setDirectReturnMode(.stage)
            try require(
                reward.finish() == .stage,
                "Game reward did not restore its exact pre-game stage"
            )
        }

        await run("Content return policies cannot override direct visual ownership", reporter: reporter) {
            let policy = CompanionUserPresentationPolicy()

            var previous = CompanionPresentationLifecycle()
            let previousDirective = previous.beginContentSequence(
                returnPolicy: .previousMode,
                currentMode: .pet
            )
            try require(
                previousDirective.targetMode == .stage
                    && !previousDirective.keepsMediaInPet,
                "Previous-mode content did not open a pet into the stage"
            )
            try require(previous.finish() == .pet, "Previous mode was not restored")

            var keep = CompanionPresentationLifecycle()
            let keepDirective = keep.beginContentSequence(
                returnPolicy: .keepCurrentMode,
                currentMode: .pet
            )
            try require(
                keepDirective.targetMode == nil && keepDirective.keepsMediaInPet,
                "Keep-current content did not remain inside the pet"
            )
            try require(keep.finish() == nil, "Keep-current content invented a return")

            var remain = CompanionPresentationLifecycle()
            let remainDirective = remain.beginContentSequence(
                returnPolicy: .remainExpanded,
                currentMode: .pet
            )
            try require(
                remainDirective.targetMode == .stage,
                "Remain-expanded content did not visibly open the stage"
            )
            try require(remain.finish() == nil, "Remain-expanded content unexpectedly shrank")

            var direct = CompanionPresentationLifecycle()
            let directPlan = policy.plan(
                for: .magicWand,
                currentMode: .pet,
                audiovisualEnabled: true
            )
            let directDirective = direct.beginContentSequence(
                returnPolicy: .remainExpanded,
                currentMode: .pet,
                directPlan: directPlan
            )
            try require(
                directDirective.targetMode == .stage
                    && directDirective.directUserOwnsReturn,
                "Direct pack playback lost its visible owner"
            )
            try require(
                direct.finish() == .pet,
                "Pack remain-expanded policy overrode direct restoration"
            )
        }

        await run("First-session journey requires two ordered interactions", reporter: reporter) {
            var journey = CompanionFirstSessionJourney()
            try require(
                journey.handle(.begin).effect == .presentCoach
                    && journey.step == .singleTap,
                "Clean first session did not begin with one visible tap"
            )
            try require(
                journey.handle(.doubleTap).effect == .none
                    && journey.step == .singleTap,
                "Out-of-order double-click skipped the first interaction"
            )
            try require(
                journey.handle(.singleTap).effect == .acknowledgeInteraction
                    && journey.step == .doubleTap,
                "Single-click did not advance to double-click"
            )
            try require(
                journey.handle(.doubleTap).effect == .acknowledgeInteraction
                    && journey.step == .preference,
                "Double-click did not reach the single preference"
            )
        }

        await run("First-session launch migration preserves users and resumes clean setup", reporter: reporter) {
            let current = CompanionFirstSessionJourney.contractVersion
            try require(
                CompanionFirstSessionLaunchPolicy.disposition(
                    storedVersion: current,
                    hasExistingProfile: true
                ) == .alreadyCompleted,
                "Completed first session was shown again"
            )
            try require(
                CompanionFirstSessionLaunchPolicy.disposition(
                    storedVersion: -current,
                    hasExistingProfile: true
                ) == .startCleanInstallation,
                "Interrupted clean setup did not resume"
            )
            try require(
                CompanionFirstSessionLaunchPolicy.disposition(
                    storedVersion: 0,
                    hasExistingProfile: true
                ) == .preserveExistingInstallation,
                "Existing installation was interrupted after upgrade"
            )
            try require(
                CompanionFirstSessionLaunchPolicy.disposition(
                    storedVersion: 0,
                    hasExistingProfile: false
                ) == .startCleanInstallation,
                "Clean installation did not start the local guide"
            )
        }

        await run("First-session asks exactly one local preference", reporter: reporter) {
            var journey = CompanionFirstSessionJourney(step: .preference)
            let effect = journey.handle(.selectPreference(.gentleCare)).effect
            try require(
                effect == .applyPreferenceAndRunWorkArc(.gentleCare),
                "Preference did not start the local work arc"
            )
            try require(
                journey.preference == .gentleCare && journey.step == .workArc,
                "Preference was not retained in the journey"
            )
            try require(
                journey.handle(.selectPreference(.playfulBreaks)).effect == .none,
                "Journey accepted a second preference"
            )
        }

        await run("First-session completes only after the work arc", reporter: reporter) {
            var journey = CompanionFirstSessionJourney(step: .workArc)
            try require(journey.isActive, "Work arc was not an active guide step")
            try require(
                journey.handle(.workArcCompleted).effect == .complete
                    && journey.step == .complete
                    && !journey.isActive,
                "Trusted work-arc completion did not close the guide"
            )
            try require(
                journey.handle(.workArcCompleted).effect == .none,
                "Duplicate completion changed a completed journey"
            )
        }

        await run("First-session skip is final but replayable", reporter: reporter) {
            var journey = CompanionFirstSessionJourney(step: .doubleTap)
            try require(
                journey.handle(.skip).effect == .skipped
                    && journey.step == .complete,
                "Skip did not close the guide without a penalty"
            )
            try require(
                journey.handle(.replay).effect == .presentCoach
                    && journey.step == .singleTap
                    && journey.preference == nil,
                "Completed guide could not be replayed from the beginning"
            )
        }

        await run("Microgame session isolates one active game and expires safely", reporter: reporter) {
            var session = CompanionMicrogameSession()
            session.start(.catchPet)
            try require(session.activeGame == .catchPet, "Catch session did not start")
            try require(session.secondsRemaining == 20, "Catch duration changed")
            try require(
                session.registerHideFind(at: Date()) == .ignored,
                "Inactive hide input changed the catch session"
            )
            for _ in 0..<19 {
                try require(!session.tick(), "Catch session expired early")
            }
            try require(session.tick(), "Catch session did not expire at zero")
            session.end()
            try require(
                session.activeGame == nil
                    && session.score == 0
                    && session.secondsRemaining == 0,
                "Ended microgame retained ephemeral progress"
            )
        }

        await run("Catch and hide streak rules are deterministic", reporter: reporter) {
            let start = Date(timeIntervalSince1970: 1_800_000_000)
            var session = CompanionMicrogameSession()
            session.start(.catchPet)
            try require(session.registerCatch(at: start) == .advanced, "First catch failed")
            try require(
                session.registerCatch(at: start.addingTimeInterval(1.2)) == .advanced
                    && session.combo == 2,
                "Catch streak window changed"
            )
            _ = session.registerCatch(at: start.addingTimeInterval(4))
            try require(session.combo == 1, "Expired catch streak was retained")
            _ = session.registerCatch(at: start.addingTimeInterval(5))
            try require(
                session.registerCatch(at: start.addingTimeInterval(6)) == .completed,
                "Five catches did not complete"
            )

            session.start(.hideAndSeek)
            for index in 0..<CompanionMicrogameSession.hideTarget {
                let outcome = session.registerHideFind(
                    at: start.addingTimeInterval(Double(index))
                )
                try require(
                    outcome == (index == 4 ? .completed : .advanced),
                    "Hide progress diverged at step \(index + 1)"
                )
            }
            try require(session.combo == 5, "Hide streak did not accumulate")
        }

        await run("Gesture combo resets wrong order without hidden progress", reporter: reporter) {
            var session = CompanionMicrogameSession()
            session.start(.gestureCombo)
            try require(
                session.registerComboGesture(.hold) == .reset
                    && session.comboStep == 0,
                "Wrong first gesture did not reset"
            )
            try require(session.registerComboGesture(.tap) == .advanced, "Tap was rejected")
            try require(session.registerComboGesture(.hold) == .advanced, "Hold was rejected")
            try require(
                session.registerComboGesture(.fling) == .completed
                    && session.comboStep == CompanionMicrogameSession.comboTarget,
                "Valid combo did not complete"
            )
        }

        await run("Heart trace accepts only the visible bounded path", reporter: reporter) {
            var session = CompanionMicrogameSession()
            session.start(.heartTrace)
            let first = CompanionMicrogameSession.heartTraceGuide[0]
            try require(
                session.registerHeartPoint(
                    .init(x: first.x + 0.3, y: first.y)
                ) == .ignored,
                "Point outside heart tolerance advanced progress"
            )
            for (index, point) in CompanionMicrogameSession.heartTraceGuide.enumerated() {
                let outcome = session.registerHeartPoint(point)
                try require(
                    outcome == (index == CompanionMicrogameSession.heartTraceGuide.count - 1
                        ? .completed
                        : .advanced),
                    "Heart trace diverged at point \(index + 1)"
                )
            }
            session.resetHeartTrace()
            try require(session.heartTraceProgress == 0, "Heart reset kept progress")
        }

        await run("Rhythm input window and win policy are deterministic", reporter: reporter) {
            var session = CompanionMicrogameSession()
            session.start(.rhythm)
            let start = Date(timeIntervalSince1970: 1_800_000_000)
            try require(
                session.registerRhythmTap(at: start) == .missed,
                "Tap before a visible beat was accepted"
            )
            for beat in 1...6 {
                let time = start.addingTimeInterval(Double(beat))
                session.beginRhythmBeat(beat, at: time)
                try require(
                    session.registerRhythmTap(at: time.addingTimeInterval(0.2)) == .advanced,
                    "Visible beat \(beat) was missed"
                )
                try require(
                    session.registerRhythmTap(at: time.addingTimeInterval(0.21)) == .missed,
                    "Duplicate beat was counted twice"
                )
                session.closeRhythmBeat()
            }
            try require(session.score == 6, "Rhythm counted duplicate taps")
            try require(
                session.rhythmBestCombo == 1 && !session.rhythmDidWin,
                "Duplicate-tap misses incorrectly preserved a winning combo"
            )

            session.start(.rhythm)
            for beat in 1...6 {
                let time = start.addingTimeInterval(Double(beat))
                session.beginRhythmBeat(beat, at: time)
                _ = session.registerRhythmTap(at: time)
                session.closeRhythmBeat()
            }
            try require(
                session.rhythmDidWin && session.rhythmBestCombo == 6,
                "Six accurate beats did not satisfy the documented win rule"
            )
        }

        await run("Feed challenge completes exactly at three successes", reporter: reporter) {
            var session = CompanionMicrogameSession()
            session.start(.feed)
            try require(session.registerFeedSuccess() == .advanced, "First feed failed")
            try require(session.registerFeedSuccess() == .advanced, "Second feed failed")
            try require(
                session.registerFeedSuccess() == .completed
                    && session.score == CompanionMicrogameSession.feedTarget,
                "Third feed did not complete"
            )
        }

        await run("Microgame completion rewards cover every game without penalties", reporter: reporter) {
            let policy = CompanionMicrogameCompletionPolicy()
            let expectedBeats: [
                CompanionMicrogameKind: CompanionMicrogameRewardBeat
            ] = [
                .catchPet: .cheer,
                .hideAndSeek: .adaptiveAffection,
                .gestureCombo: .twirl,
                .heartTrace: .heart,
                .rhythm: .jump,
                .feed: .kitchen,
            ]
            var mementos = Set<String>()
            for game in CompanionMicrogameKind.allCases {
                let plan = policy.plan(for: game, won: true)
                try require(plan.game == game && plan.won, "Winning game identity drifted")
                try require(
                    plan.rewardBeat == expectedBeats[game],
                    "Winning reward beat drifted for \(game)"
                )
                guard let reward = plan.relationshipReward else {
                    throw CheckFailure(message: "Winning game lost its positive memory")
                }
                try require(
                    reward.bond > 0 && reward.chemistry > 0,
                    "Winning game received a non-positive relationship reward"
                )
                try require(
                    mementos.insert(reward.mementoID).inserted,
                    "Two games shared an indistinguishable memento"
                )
                try require(
                    !plan.restoreImmediately && plan.resumeDelay == 0,
                    "Winning presentation skipped its audiovisual reward handoff"
                )
            }
        }

        await run("Microgame endings restore promptly and never create relationship debt", reporter: reporter) {
            let policy = CompanionMicrogameCompletionPolicy()
            for game in CompanionMicrogameKind.allCases {
                let announced = policy.plan(for: game, won: false, announce: true)
                try require(
                    announced.restoreImmediately,
                    "Ended game did not restore its captured presentation"
                )
                try require(
                    announced.rewardBeat == nil
                        && announced.relationshipReward == nil,
                    "Ended game created a reward, penalty or persistent memory"
                )
                try require(
                    announced.resumeDelay == (game == .catchPet ? 3.6 : 4.0),
                    "Announced return timing drifted for \(game)"
                )
                let silent = policy.plan(for: game, won: false, announce: false)
                try require(
                    silent.resumeDelay == 0.2
                        && silent.restoreImmediately
                        && silent.relationshipReward == nil,
                    "Silent cancellation did not return quickly and debt-free"
                )
            }
        }

        await run("Playback health is exactly-once and privacy-minimal", reporter: reporter) {
            var health = CompanionPlaybackHealthAccumulator(
                maximumSampleCount: 3,
                firstFrameTargetMilliseconds: 500
            )
            let first = health.beginAttempt()
            let second = health.beginAttempt()
            try require(
                health.recordFirstFrame(for: first, milliseconds: 320),
                "First frame was not accepted"
            )
            try require(
                !health.recordFirstFrame(for: first, milliseconds: 450),
                "Duplicate first frame changed the sample set"
            )
            try require(
                health.finishAttempt(first, reason: .ended),
                "Playback end was not accepted"
            )
            try require(
                !health.finishAttempt(first, reason: .failed),
                "Stale terminal callback changed playback health"
            )
            try require(
                health.finishAttempt(second, reason: .cancelled),
                "Cancellation was not accepted"
            )
            let snapshot = health.snapshot
            try require(snapshot.startedCount == 2, "Start count drifted")
            try require(snapshot.readyCount == 1, "Ready count was not exactly once")
            try require(snapshot.endedCount == 1, "End count drifted")
            try require(snapshot.failureCount == 0, "Stale failure was counted")
            try require(snapshot.cancelledCount == 1, "Cancellation count drifted")
            try require(snapshot.activeAttemptCount == 0, "Attempt leaked")
            try require(snapshot.peakActiveAttemptCount == 2, "Peak concurrency drifted")
            try require(snapshot.firstFrameP95Milliseconds == 320, "P95 drifted")
            try require(snapshot.firstFrameStatus == .withinTarget, "Target status drifted")
        }

        await run("Playback latency samples remain bounded", reporter: reporter) {
            var health = CompanionPlaybackHealthAccumulator(
                maximumSampleCount: 3,
                firstFrameTargetMilliseconds: 500
            )
            for latency in [100, 200, 300, 900] {
                let token = health.beginAttempt()
                try require(
                    health.recordFirstFrame(for: token, milliseconds: latency),
                    "A bounded latency sample was rejected"
                )
                try require(
                    health.finishAttempt(token, reason: .ended),
                    "A bounded attempt did not finish"
                )
            }
            let snapshot = health.snapshot
            try require(snapshot.firstFrameSampleCount == 3, "Samples grew beyond the bound")
            try require(snapshot.firstFrameP95Milliseconds == 900, "Bounded P95 is wrong")
            try require(snapshot.firstFrameStatus == .aboveTarget, "Slow playback was hidden")
        }

        await run("Chemistry director enforces relationship boundaries", reporter: reporter) {
            let director = CompanionChemistryInteractionDirector()
            let calm = CompanionChemistryInteractionContext(
                hour: 22,
                relationshipTone: .calmPeer,
                chemistryLevel: 99,
                mood: .affectionate
            )
            try require(calm.chemistryLevel == 1, "Calm mode ignored its chemistry cap")
            let calmCandidates = director.candidates(for: .doubleTap, context: calm)
            try require(!calmCandidates.isEmpty, "Calm mode lost its neutral fallback")
            try require(
                calmCandidates.allSatisfy {
                    $0.moment.relationshipBoundary == .neutral
                },
                "Calm mode admitted a non-neutral moment"
            )

            let lowRomance = CompanionChemistryInteractionContext(
                hour: 23,
                relationshipTone: .romanceLite,
                chemistryLevel: 1,
                mood: .affectionate
            )
            try require(
                !director.candidates(for: .singleTap, context: lowRomance)
                    .contains { $0.moment == .kiss },
                "Romantic moment unlocked before its chemistry threshold"
            )
            let highRomance = CompanionChemistryInteractionContext(
                hour: 23,
                relationshipTone: .romanceLite,
                chemistryLevel: 3,
                mood: .affectionate
            )
            try require(
                director.candidates(for: .singleTap, context: highRomance)
                    .contains { $0.moment == .kiss },
                "Romance-lite did not unlock its explicitly gated moment"
            )
        }

        await run("Chemistry director selection is deterministic and fresh", reporter: reporter) {
            let director = CompanionChemistryInteractionDirector()
            let context = CompanionChemistryInteractionContext(
                hour: 20,
                relationshipTone: .playfulSpark,
                chemistryLevel: 3,
                mood: .playful
            )
            guard let first = director.select(
                for: .doubleTap,
                context: context,
                seed: 0xC0FFEE
            ) else {
                throw CheckFailure(message: "Chemistry director returned no selection")
            }
            try require(
                director.select(for: .doubleTap, context: context, seed: 0xC0FFEE) == first,
                "Equal seeds produced different selections"
            )
            let recent = CompanionChemistryInteractionContext(
                hour: 20,
                relationshipTone: .playfulSpark,
                chemistryLevel: 3,
                mood: .playful,
                recentMomentKeys: [first.selected.key, first.selected.key]
            )
            guard let next = director.select(
                for: .doubleTap,
                context: recent,
                seed: 0xC0FFEE
            ) else {
                throw CheckFailure(message: "Chemistry director lost its fallback after history")
            }
            try require(next.selected != first.selected, "Recent moment was immediately repeated")
            try require(
                next.candidates.first { $0.moment == first.selected }?.isRecent == true,
                "Recent moment was not marked in the audit candidates"
            )
        }

        await run("Direct taps never impersonate scheduled care", reporter: reporter) {
            let director = CompanionChemistryInteractionDirector()
            let context = CompanionChemistryInteractionContext(
                hour: 14,
                relationshipTone: .romanceLite,
                chemistryLevel: 3,
                mood: .focused
            )
            let singleTapMoments = Set(
                director.candidates(for: .singleTap, context: context).map(\.moment)
            )
            let doubleTapMoments = Set(
                director.candidates(for: .doubleTap, context: context).map(\.moment)
            )
            try require(
                singleTapMoments.isDisjoint(with: [.drink, .stretch]),
                "A single tap was routed into hydration or movement care"
            )
            try require(
                doubleTapMoments.isDisjoint(with: [.workout, .timeCafe]),
                "A double tap was routed into a utility or time-themed beat"
            )
            try require(!singleTapMoments.isEmpty, "Single tap lost every response")
            try require(!doubleTapMoments.isEmpty, "Double tap lost every response")
        }

        await run("Codex notify privacy-minimal mapping", reporter: reporter) {
            let payload = Data(
                """
                {
                  "type": "agent-turn-complete",
                  "thread-id": "thread-sensitive",
                  "turn-id": "turn-sensitive",
                  "cwd": "/private/project",
                  "input-messages": ["secret prompt"],
                  "last-assistant-message": "secret answer"
                }
                """.utf8
            )
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let event = try CodexNotifyMapper.map(payload, now: now)
            try require(event?.type == .responseReady, "Agent turn was not mapped to a neutral response")
            try require(event?.source == "codex-notify", "Unexpected mapper source")
            try require(event?.occurredAt == now, "Unexpected event timestamp")
            try require(event?.outcome == nil, "Agent turn was incorrectly marked as task success")
            try require(event?.metadata.isEmpty == true, "Private payload leaked into metadata")
            try require(event?.privacy == CompanionEventPrivacy(), "Privacy flags changed")

            let encoded = try CompanionEventCodec.encode(event!, now: now)
            let serialized = String(decoding: encoded, as: UTF8.self)
            try require(!serialized.contains("secret"), "Prompt or response leaked")
            try require(!serialized.contains("/private/project"), "Working directory leaked")
            try require(!serialized.contains("thread-sensitive"), "Thread ID leaked")
        }

        await run("Unsupported Codex notify event ignored", reporter: reporter) {
            let payload = Data(#"{"type":"other-event","input-messages":["secret"]}"#.utf8)
            let event = try CodexNotifyMapper.map(payload)
            try require(event == nil, "Unsupported notification should be ignored")
        }

        await run("App Server turn started privacy projection", reporter: reporter) {
            let payload = Data(
                """
                {
                  "jsonrpc": "2.0",
                  "method": "turn/started",
                  "params": {
                    "threadId": "thread-sensitive-start",
                    "turn": {
                      "id": "turn-sensitive-start",
                      "status": "inProgress",
                      "items": [{"text": "secret prompt"}],
                      "cwd": "/private/project"
                    }
                  }
                }
                """.utf8
            )
            let now = Date(timeIntervalSince1970: 1_800_000_100)
            let event = try CodexAppServerMapper.map(payload, now: now)
            try require(event?.type == .taskStarted, "Started turn did not map to task.started")
            try require(event?.source == "codex-app-server", "Unexpected App Server source")
            try require(event?.sourceVersion == "turn-events-v1", "Projection version changed")
            try require(event?.occurredAt == now, "App Server adapter trusted an upstream timestamp")
            try require(event?.taskRef == nil, "Upstream identifier leaked into taskRef")
            try require(event?.durationMs == nil, "Started turn retained a duration")
            try require(event?.outcome == nil, "Started turn received an outcome")
            try require(event?.metadata.isEmpty == true, "Private App Server fields leaked into metadata")

            let encoded = try CompanionEventCodec.encode(event!, now: now)
            let serialized = String(decoding: encoded, as: UTF8.self)
            for privateValue in [
                "thread-sensitive-start",
                "turn-sensitive-start",
                "secret prompt",
                "/private/project",
            ] {
                try require(!serialized.contains(privateValue), "Private App Server input leaked: \(privateValue)")
            }
        }

        await run("App Server completed turn stays neutral", reporter: reporter) {
            let payload = Data(
                #"{"method":"turn/completed","params":{"threadId":"private-thread","turn":{"id":"private-turn","status":"completed","durationMs":1234,"error":{"message":"private failure"},"items":[{"text":"private answer"}]}}}"#.utf8
            )
            let event = try CodexAppServerMapper.map(payload)
            try require(event?.type == .responseReady, "Completed turn was not mapped to response.ready")
            try require(event?.type != .taskCompleted, "Completed turn was promoted to task.completed")
            try require(event?.outcome == nil, "Completed turn was incorrectly marked as task success")
            try require(event?.durationMs == 1234, "Completed duration was lost")
            try require(event?.taskRef == nil, "Completed turn leaked an upstream identifier")

            let encoded = try CompanionEventCodec.encode(event!)
            let serialized = String(decoding: encoded, as: UTF8.self)
            try require(!serialized.contains("private"), "Completed turn leaked upstream content")
        }

        await run("App Server terminal failure and cancellation mapping", reporter: reporter) {
            let failed = try CodexAppServerMapper.map(
                Data(#"{"method":"turn/completed","params":{"threadId":"t","turn":{"id":"f","status":"failed","durationMs":8}}}"#.utf8)
            )
            try require(failed?.type == .taskFailed, "Failed turn did not map to task.failed")
            try require(failed?.outcome == .failure, "Failed turn outcome changed")

            let interrupted = try CodexAppServerMapper.map(
                Data(#"{"method":"turn/completed","params":{"threadId":"t","turn":{"id":"i","status":"interrupted","durationMs":9}}}"#.utf8)
            )
            try require(interrupted?.type == .taskCancelled, "Interrupted turn did not map to task.cancelled")
            try require(interrupted?.outcome == .cancelled, "Interrupted turn outcome changed")
        }

        await run("Unsupported App Server notification ignored", reporter: reporter) {
            let payload = Data(#"{"method":"item/started","private":"secret"}"#.utf8)
            let event = try CodexAppServerMapper.map(payload)
            try require(event == nil, "Unsupported App Server notification should be ignored")
        }

        await run("App Server method and status agreement enforced", reporter: reporter) {
            let cases = [
                #"{"method":"turn/started","params":{"threadId":"t","turn":{"id":"x","status":"completed"}}}"#,
                #"{"method":"turn/completed","params":{"threadId":"t","turn":{"id":"x","status":"inProgress"}}}"#,
            ]
            for payload in cases {
                do {
                    _ = try CodexAppServerMapper.map(Data(payload.utf8))
                    throw CheckFailure(message: "Invalid method/status pair was accepted")
                } catch let error as CodexAppServerMapperError {
                    try require(error == .invalidStatus, "Unexpected App Server status error: \(error)")
                    try require(
                        error.companionErrorCode == "APP_SERVER_EVENT_INVALID_STATUS",
                        "App Server status error code changed"
                    )
                }
            }
        }

        await run("App Server duration limits enforced", reporter: reporter) {
            let durations: [Int64] = [-1, CodexAppServerMapper.maximumDurationMs + 1]
            for duration in durations {
                let payload = Data(
                    """
                    {"method":"turn/completed","params":{"threadId":"t","turn":{"id":"x","status":"completed","durationMs":\(duration)}}}
                    """.utf8
                )
                do {
                    _ = try CodexAppServerMapper.map(payload)
                    throw CheckFailure(message: "Invalid App Server duration was accepted")
                } catch let error as CodexAppServerMapperError {
                    try require(error == .invalidDuration, "Unexpected duration error: \(error)")
                    try require(
                        error.companionErrorCode == "APP_SERVER_EVENT_INVALID_DURATION",
                        "App Server duration error code changed"
                    )
                }
            }
        }

        await run("Malformed App Server input has stable failures", reporter: reporter) {
            let cases: [(Data, CodexAppServerMapperError, String)] = [
                (Data("{not-json".utf8), .invalidJSON, "APP_SERVER_EVENT_INVALID_JSON"),
                (Data(#"{"method":"turn/started","params":{}}"#.utf8), .invalidEnvelope, "APP_SERVER_EVENT_INVALID_ENVELOPE"),
                (Data(repeating: 0x20, count: CodexAppServerMapper.maximumPayloadBytes + 1), .payloadTooLarge, "APP_SERVER_EVENT_PAYLOAD_TOO_LARGE"),
            ]
            for (payload, expected, code) in cases {
                do {
                    _ = try CodexAppServerMapper.map(payload)
                    throw CheckFailure(message: "Invalid App Server payload was accepted")
                } catch let error as CodexAppServerMapperError {
                    try require(error == expected, "Unexpected App Server input error: \(error)")
                    try require(error.companionErrorCode == code, "App Server input error code changed")
                    try require(!error.recoveryAction.isEmpty, "App Server failure lost its recovery action")
                }
            }
        }

        await run("Backup manifest round-trip", reporter: reporter) {
            let original = CompanionBackupManifestV1(
                createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                appVersion: "0.20.0",
                settings: CompanionSettingsV1(locale: "en-US"),
                packs: [
                    CompanionBackupPackReference(
                        packID: "cc.chengyin.pack.aurora",
                        version: "1.2.0",
                        relativePath: "packs/cc.chengyin.pack.aurora/1.2.0",
                        manifestSHA256: String(repeating: "a", count: 64)
                    )
                ]
            )
            let data = try CompanionBackupCodec.encode(original)
            let decoded = try CompanionBackupCodec.decode(data)
            try require(decoded == original, "Backup manifest changed during round-trip")
        }

        await run("Backup traversal rejection", reporter: reporter) {
            let manifest = CompanionBackupManifestV1(
                appVersion: "0.20.0",
                settings: CompanionSettingsV1(),
                packs: [
                    CompanionBackupPackReference(
                        packID: "cc.chengyin.pack.aurora",
                        version: "1.0.0",
                        relativePath: "packs/../private",
                        manifestSHA256: String(repeating: "b", count: 64)
                    )
                ]
            )
            do {
                _ = try CompanionBackupCodec.encode(manifest)
                throw CheckFailure(message: "Unsafe backup path was accepted")
            } catch let error as CompanionBackupValidationError {
                try require(error == .invalidRelativePath, "Unexpected backup error: \(error)")
                try require(
                    error.companionErrorCode == "BACKUP_VALIDATION_INVALID_RELATIVE_PATH",
                    "Backup traversal error code changed"
                )
            }
        }

        await run("Duplicate backup pack rejection", reporter: reporter) {
            let reference = CompanionBackupPackReference(
                packID: "cc.chengyin.pack.aurora",
                version: "1.0.0",
                relativePath: "packs/cc.chengyin.pack.aurora/1.0.0",
                manifestSHA256: String(repeating: "c", count: 64)
            )
            let manifest = CompanionBackupManifestV1(
                appVersion: "0.20.0",
                settings: CompanionSettingsV1(),
                packs: [reference, reference]
            )
            do {
                _ = try CompanionBackupCodec.encode(manifest)
                throw CheckFailure(message: "Duplicate backup pack was accepted")
            } catch let error as CompanionBackupValidationError {
                try require(error == .duplicatePackID, "Unexpected duplicate error: \(error)")
                try require(
                    error.companionErrorCode == "BACKUP_VALIDATION_DUPLICATE_PACK_ID",
                    "Duplicate backup pack error code changed"
                )
            }
        }

        await run("Malformed backup has stable failure", reporter: reporter) {
            do {
                _ = try CompanionBackupCodec.decode(Data("{not-json".utf8))
                throw CheckFailure(message: "Malformed backup JSON was accepted")
            } catch let error as CompanionBackupValidationError {
                try require(error == .malformedPayload, "Unexpected malformed backup error: \(error)")
                try require(
                    error.companionErrorCode == "BACKUP_VALIDATION_MALFORMED_PAYLOAD",
                    "Malformed backup error code changed"
                )
            }
        }

        await run("Invalid backup display target is rejected", reporter: reporter) {
            let manifest = CompanionBackupManifestV1(
                appVersion: "0.20.0",
                settings: CompanionSettingsV1(
                    displayTarget: CompanionDisplayTarget(
                        mode: .specific,
                        identifier: "../private-display"
                    )
                ),
                packs: []
            )
            do {
                _ = try CompanionBackupCodec.encode(manifest)
                throw CheckFailure(message: "Unsafe display target was accepted")
            } catch let error as CompanionBackupValidationError {
                try require(error == .invalidDisplayTarget, "Unexpected display target error: \(error)")
                try require(
                    error.companionErrorCode == "BACKUP_VALIDATION_INVALID_DISPLAY_TARGET",
                    "Display target error code changed"
                )
            }
        }

        await run("Codex notify config append plan", reporter: reporter) {
            let config = Data("# user config\nmodel = \"gpt\"\n".utf8)
            let plan = try CodexNotifyConfigPlanner.plan(
                existingConfig: config,
                helperPath: "/Applications/Chengyin/CompanionEventEmitter"
            )
            try require(plan.status == .appendAtTop, "Missing notify was not detected")
            try require(
                plan.proposedLine.contains(#""codex-notify""#),
                "Proposed notify command is incomplete"
            )
        }

        await run("Codex notify exact configuration detection", reporter: reporter) {
            let config = Data(
                #"notify = ["/Applications/Chengyin/CompanionEventEmitter", "codex-notify"]"#.utf8
            )
            let plan = try CodexNotifyConfigPlanner.plan(
                existingConfig: config,
                helperPath: "/Applications/Chengyin/CompanionEventEmitter"
            )
            try require(plan.status == .alreadyConfigured, "Exact notify was not recognized")
        }

        await run("Codex notify conflict protection", reporter: reporter) {
            let config = Data(#"notify = ["/usr/local/bin/my-existing-hook"]"#.utf8)
            let plan = try CodexNotifyConfigPlanner.plan(
                existingConfig: config,
                helperPath: "/Applications/Chengyin/CompanionEventEmitter"
            )
            try require(plan.status == .conflict, "Existing notify would be overwritten")
        }

        await run("Commented Codex notify ignored", reporter: reporter) {
            let config = Data(#"# notify = ["/usr/local/bin/old-hook"]"#.utf8)
            let plan = try CodexNotifyConfigPlanner.plan(
                existingConfig: config,
                helperPath: "/Applications/Chengyin/CompanionEventEmitter"
            )
            try require(plan.status == .appendAtTop, "Commented notify caused a conflict")
        }

        let result = await reporter.result()
        print("Companion contract checks: \(result.passed) passed, \(result.failed) failed")
        if result.failed > 0 {
            exit(1)
        }
    }

    private static func run(
        _ name: String,
        reporter: CheckReporter,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            await reporter.pass(name)
        } catch {
            await reporter.fail(name, error)
        }
    }

    private static func requireAsync(_ condition: Bool, _ message: String) async throws {
        guard condition else {
            throw CheckFailure(message: message)
        }
    }
}
