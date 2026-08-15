import Foundation
import Darwin

@main
struct ContentPackSmoke {
    static func main() async throws {
        setbuf(stdout, nil)
        try validPackIsAccepted()
        print("PASS  valid pack accepted")
        try validV2ExperienceIsAccepted()
        print("PASS  v2 multi-step experience accepted")
        try validDynamicProjectionIsAccepted()
        print("PASS  dynamic focal and safe-area projection accepted")
        try invalidFocalTrackIsRejected()
        print("PASS  invalid focal track rejected")
        try invalidSafeAreaIsRejected()
        print("PASS  invalid safe area rejected")
        try clippedSafeAreaIsRejected()
        print("PASS  clipped safe area rejected")
        try unknownProjectionFieldIsRejected()
        print("PASS  unknown projection field rejected")
        try v1DynamicProjectionIsRejected()
        print("PASS  dynamic projection rejected under schema v1")
        try oldMinimumForDynamicProjectionIsRejected()
        print("PASS  dynamic projection requires a compatible app minimum")
        try validWorkdayContentTriggersAreAccepted()
        print("PASS  workday content triggers accepted at compatible minimum")
        try oldMinimumForWorkdayContentTriggerIsRejected()
        print("PASS  workday content triggers require a compatible app minimum")
        try validContributionMetadataIsAccepted()
        print("PASS  complete contribution metadata accepted")
        try strictContributionContractIsAccepted()
        print("PASS  strict v2 contribution contract accepted")
        try orphanContributionMetadataIsRejected()
        print("PASS  orphan contribution metadata rejected")
        try schema1ContributionIsRejected()
        print("PASS  contribution metadata rejected under schema v1")
        try v1ExperienceIsRejected()
        print("PASS  v2 feature rejected under schema v1")
        try unknownExperienceAssetIsRejected()
        print("PASS  unknown experience asset rejected")
        try pathTraversalIsRejected()
        print("PASS  path traversal rejected")
        try symbolicLinkEscapeIsRejected()
        print("PASS  symbolic-link escape rejected")
        try duplicateAssetIDIsRejected()
        print("PASS  duplicate asset ID rejected")
        try duplicateAssetPathIsRejected()
        print("PASS  duplicate asset path rejected")
        try unknownManifestFieldIsRejected()
        print("PASS  unknown manifest field rejected")
        try privateEvidencePathIsRejected()
        print("PASS  private evidence path rejected")
        try duplicateAssetFallbackIsRejected()
        print("PASS  duplicate asset fallback rejected")
        try oversizedSingleAssetIsRejected()
        print("PASS  oversized single asset rejected before hashing")
        try decodeBombDeclarationsAreRejected()
        print("PASS  decode-bomb media declarations rejected")
        try modifiedMediaIsRejected()
        print("PASS  modified media rejected")
        try newerMinimumVersionIsRejected()
        print("PASS  newer minimum version rejected")
        try undeclaredFileIsRejected()
        print("PASS  undeclared file rejected")
        try hiddenFileIsRejected()
        print("PASS  hidden file rejected")
        try malformedManifestHasStableCode()
        print("PASS  malformed manifest has stable error code")
        try await flatArchiveInstallsTransactionallyAndCleansStaging()
        print("PASS  flat .chengyinpack installs transactionally and cleans staging")
        try await corruptArchivePreservesInstalledInventory()
        print("PASS  corrupt .chengyinpack preserves installed inventory")
        try await installUpgradeAndRollbackAreTransactional()
        print("PASS  transactional install, upgrade and rollback")
        try await interruptedStagingCleanupIsScoped()
        print("PASS  interrupted staging cleanup is scoped")
        try await stagingCopyFailureLeavesNoStoreMutation()
        print("PASS  staging-copy failure leaves no store mutation")
        try await injectedFailurePreservesActiveVersion()
        print("PASS  injected failure preserves active version")
        try await stagedCandidateIsRevalidatedAfterAsyncProbe()
        print("PASS  staged candidate is revalidated after async media probe")
        try await sameVersionConflictIsRejected()
        print("PASS  same-version conflict rejected")
        try await downgradeRequiresExplicitRollback()
        print("PASS  downgrade requires explicit rollback")
        try await officialPackRequiresSignatureVerifier()
        print("PASS  official pack requires signature verifier")
        try await playbackHealthPromotesOrRollsBack()
        print("PASS  playback health promotes or rolls back")
        try await postActivationCrashKeepsCompletePendingRevision()
        print("PASS  post-activation crash keeps complete pending revision")
        try await removalIsRecoverable()
        print("PASS  removal is recoverable")
        try await recoveryCatalogSurvivesRestart()
        print("PASS  recovery catalog survives restart")
        try await invalidRecoveryIdentifierIsRejected()
        print("PASS  recovery identifier traversal rejected")
        try await damagedRecoveryDoesNotBrickValidItems()
        print("PASS  damaged recovery item is isolated")
        try await failedRestoreReturnsItemToRecoveryArea()
        print("PASS  failed restore remains recoverable for cleanup")
        try await symlinkRecoveryPurgesLinkOnly()
        print("PASS  recovery symlink cannot escape purge boundary")
        try await recoveryInventoryIsBounded()
        print("PASS  recovery inventory is bounded")
        try await contentStoreSnapshotProjectsActiveAndRecoveryTogether()
        print("PASS  content store snapshot is coherent under one lock")
        try await contentLibraryKeepsInventorySnapshotsCurrent()
        print("PASS  content library keeps mutation snapshots current")
        try await contentOperationsCoordinateStateAndSafeReceipts()
        print("PASS  content operations coordinate state and safe receipts")
        try await portableBackupRoundTripRestoresSettingsAndPacks()
        print("PASS  portable backup restores settings and packs")
        try await portableBackupPreflightPreventsPartialRestore()
        print("PASS  portable backup preflight prevents partial restore")
        try runtimeCatalogResolvesInstalledVideo()
        print("PASS  runtime catalog resolves installed video and accessibility")
        try runtimeAccessibilityIsLocalizedSanitizedAndBounded()
        print("PASS  runtime accessibility is localized, sanitized and bounded")
        try runtimeCatalogPrefersMatchingLocale()
        print("PASS  runtime catalog prefers matching locale")
        try runtimeCatalogExcludesDisabledPack()
        print("PASS  runtime catalog excludes disabled pack")
        try qualityLevelsAreDerivedFromTrustState()
        print("PASS  content quality levels are Core-derived")
        try stableCodesAndSafePresentation()
        print("PASS  stable error codes and privacy-safe presentation")
        try failureReceiptUIPresentationAndLogMatrix()
        print("PASS  UI, JSON receipt and log error matrix is consistent")
        try await mediaProbeAcceptsRealVideo()
        print("PASS  media probe decodes complete real video with an explicit backend")
        try mediaTimelineAlignmentPolicyIsDeterministic()
        print("PASS  media timeline tolerance is deterministic")
        try await mediaProbeRejectsAudioDeclarationMismatch()
        print("PASS  media probe rejects audio declaration mismatch")
        try await mediaProbeRejectsDimensionMismatch()
        print("PASS  media probe rejects dimension mismatch")
        try await mediaProbeRejectsCorruptVideoWithStableCode()
        print("PASS  media probe rejects corrupt video with stable code")
        try await mediaProbeRejectsCorruptTailWithStableCode()
        print("PASS  media probe rejects corrupt tail with stable code")
        print("Content pack smoke checks passed (68/68).")
    }

    private static func validPackIsAccepted() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }

        let manifest = try fixture.makeManifest()
        try fixture.write(manifest)
        let decoded = try ContentPackValidator().loadAndValidate(
            packageDirectory: fixture.root,
            currentAppVersion: "0.20.0"
        )
        try require(decoded == manifest, "valid pack was changed while decoding")
    }

    private static func validDynamicProjectionIsAccepted() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let base = try fixture.makeManifest().assets[0]
        let dynamic = projectionAsset(
            from: base,
            focalTracks: [
                "pet": [
                    .init(timeMs: 0, x: 0.50, y: 0.35, scale: 2.8),
                    .init(timeMs: 2_000, x: 0.52, y: 0.36, scale: 2.8),
                    .init(timeMs: 4_000, x: 0.50, y: 0.35, scale: 2.8)
                ]
            ],
            safeAreas: [
                "pet": .init(x: 0.42, y: 0.28, width: 0.16, height: 0.14)
            ]
        )
        try fixture.write(fixture.manifest(schemaVersion: 2, assets: [dynamic]))
        let decoded = try ContentPackValidator().loadAndValidate(
            packageDirectory: fixture.root,
            currentAppVersion: "0.20.0"
        )
        try require(
            decoded.assets[0].focalTracks?["pet"]?.count == 3,
            "validated focal timeline was not preserved"
        )
        try require(
            decoded.assets[0].safeAreas?["pet"]?.width == 0.16,
            "validated safe area was not preserved"
        )
    }

    private static func invalidFocalTrackIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let base = try fixture.makeManifest().assets[0]
        let invalid = projectionAsset(
            from: base,
            focalTracks: [
                "pet": [
                    .init(timeMs: 0, x: 0.5, y: 0.35, scale: 2.8),
                    .init(timeMs: 3_000, x: 0.5, y: 0.35, scale: 2.8),
                    .init(timeMs: 2_000, x: 0.5, y: 0.35, scale: 2.8)
                ]
            ]
        )
        try fixture.write(fixture.manifest(schemaVersion: 2, assets: [invalid]))
        try requireError(.invalidFocalTrack(asset: base.id, mode: "pet")) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }

        let overDuration = projectionAsset(
            from: base,
            focalTracks: [
                "pet": [
                    .init(timeMs: 0, x: 0.5, y: 0.35, scale: 2.8),
                    .init(timeMs: 4_001, x: 0.5, y: 0.35, scale: 2.8)
                ]
            ]
        )
        try fixture.write(
            fixture.manifest(schemaVersion: 2, assets: [overDuration])
        )
        try requireError(.invalidFocalTrack(asset: base.id, mode: "pet")) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func invalidSafeAreaIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let base = try fixture.makeManifest().assets[0]
        let invalid = projectionAsset(
            from: base,
            safeAreas: [
                "pet": .init(x: 0.9, y: 0.2, width: 0.2, height: 0.2)
            ]
        )
        try fixture.write(fixture.manifest(schemaVersion: 2, assets: [invalid]))
        try requireError(.invalidSafeArea(asset: base.id, mode: "pet")) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func clippedSafeAreaIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let base = try fixture.makeManifest().assets[0]
        let clipped = projectionAsset(
            from: base,
            safeAreas: [
                "pet": .init(x: 0.02, y: 0.02, width: 0.1, height: 0.1)
            ]
        )
        try fixture.write(fixture.manifest(schemaVersion: 2, assets: [clipped]))
        try requireError(.safeAreaNotVisible(asset: base.id, mode: "pet")) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func v1DynamicProjectionIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let base = try fixture.makeManifest().assets[0]
        let dynamic = projectionAsset(
            from: base,
            focalTracks: [
                "pet": [
                    .init(timeMs: 0, x: 0.5, y: 0.35, scale: 2.8),
                    .init(timeMs: 4_000, x: 0.5, y: 0.35, scale: 2.8)
                ]
            ]
        )
        try fixture.write(fixture.manifest(schemaVersion: 1, assets: [dynamic]))
        try requireError(.v2FeaturesRequireSchema2) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func unknownProjectionFieldIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let base = try fixture.makeManifest().assets[0]
        let dynamic = projectionAsset(
            from: base,
            focalTracks: [
                "pet": [
                    .init(timeMs: 0, x: 0.5, y: 0.35, scale: 2.8),
                    .init(timeMs: 4_000, x: 0.5, y: 0.35, scale: 2.8)
                ]
            ]
        )
        try fixture.write(fixture.manifest(schemaVersion: 2, assets: [dynamic]))
        let manifestURL = fixture.root.appendingPathComponent("manifest.json")
        var root = try JSONSerialization.jsonObject(
            with: Data(contentsOf: manifestURL)
        ) as! [String: Any]
        var assets = root["assets"] as! [[String: Any]]
        var tracks = assets[0]["focalTracks"] as! [String: [[String: Any]]]
        tracks["pet"]![0]["providerHint"] = "must-not-pass"
        assets[0]["focalTracks"] = tracks
        root["assets"] = assets
        try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: manifestURL)
        try requireError(
            .unknownManifestField(
                "assets[0].focalTracks.pet[0].providerHint"
            )
        ) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func oldMinimumForDynamicProjectionIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let base = try fixture.makeManifest().assets[0]
        let dynamic = projectionAsset(
            from: base,
            focalTracks: [
                "pet": [
                    .init(timeMs: 0, x: 0.5, y: 0.35, scale: 2.8),
                    .init(timeMs: 4_000, x: 0.5, y: 0.35, scale: 2.8)
                ]
            ]
        )
        try fixture.write(
            fixture.manifest(
                schemaVersion: 2,
                minAppVersion: "0.19.27",
                assets: [dynamic]
            )
        )
        try requireError(
            .projectionFeatureRequiresAppVersion(
                asset: base.id,
                required: "0.19.28"
            )
        ) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func projectionAsset(
        from base: ContentPackAsset,
        focalTracks: [String: [ContentPackAsset.FocalKeyframe]]? = nil,
        safeAreas: [String: ContentPackAsset.SafeArea]? = nil
    ) -> ContentPackAsset {
        ContentPackAsset(
            id: base.id,
            kind: base.kind,
            path: base.path,
            sha256: base.sha256,
            durationMs: base.durationMs,
            width: base.width,
            height: base.height,
            aspectRatio: base.aspectRatio,
            hasNativeAudio: base.hasNativeAudio,
            loop: base.loop,
            cropAnchors: base.cropAnchors,
            focalTracks: focalTracks,
            safeAreas: safeAreas,
            triggers: base.triggers,
            tags: base.tags,
            cooldownSeconds: base.cooldownSeconds,
            weight: base.weight
        )
    }

    private static func validWorkdayContentTriggersAreAccepted() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let base = try fixture.makeManifest().assets[0]
        let asset = workdayTriggerAsset(
            from: base,
            triggers: [
                "taskStarted", "taskLongRunning", "taskCancelled",
                "responseReady"
            ]
        )
        try fixture.write(
            fixture.manifest(
                schemaVersion: 2,
                minAppVersion: "0.19.42",
                assets: [asset]
            )
        )
        _ = try ContentPackValidator().loadAndValidate(
            packageDirectory: fixture.root,
            currentAppVersion: "0.19.42"
        )
    }

    private static func oldMinimumForWorkdayContentTriggerIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let base = try fixture.makeManifest().assets[0]
        let asset = workdayTriggerAsset(
            from: base,
            triggers: ["taskStarted"]
        )
        try fixture.write(
            fixture.manifest(
                schemaVersion: 2,
                minAppVersion: "0.19.41",
                assets: [asset]
            )
        )
        try requireError(
            .workdayTriggerRequiresAppVersion(
                trigger: "taskStarted",
                required: "0.19.42"
            )
        ) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func workdayTriggerAsset(
        from base: ContentPackAsset,
        triggers: [String]
    ) -> ContentPackAsset {
        ContentPackAsset(
            id: base.id,
            kind: base.kind,
            path: base.path,
            sha256: base.sha256,
            durationMs: base.durationMs,
            width: base.width,
            height: base.height,
            aspectRatio: base.aspectRatio,
            hasNativeAudio: base.hasNativeAudio,
            loop: base.loop,
            cropAnchors: base.cropAnchors,
            focalTracks: base.focalTracks,
            safeAreas: base.safeAreas,
            triggers: triggers,
            tags: base.tags,
            cooldownSeconds: base.cooldownSeconds,
            weight: base.weight
        )
    }

    private static func malformedManifestHasStableCode() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        try Data("{not-json".utf8).write(
            to: fixture.root.appendingPathComponent("manifest.json")
        )
        do {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
            throw SmokeFailure("malformed manifest unexpectedly passed")
        } catch let error as ContentPackValidationError {
            try require(
                error == .manifestInvalidJSON,
                "malformed manifest produced the wrong validation error"
            )
            try require(
                error.companionErrorCode == "PACK_VALIDATION_MANIFEST_INVALID_JSON",
                "malformed manifest error code changed"
            )
        }
    }

    private static func stableCodesAndSafePresentation() throws {
        let traversal = ContentPackValidationError.assetOutsidePackage(
            "../private/secret.mov"
        )
        let media = ContentPackMediaProbeError.dimensionsMismatch(
            asset: "scene",
            declaredWidth: 720,
            declaredHeight: 480,
            actualWidth: 1_280,
            actualHeight: 720
        )
        let conflict = ContentPackStoreError.versionConflict(
            packID: "cc.example.pack",
            version: "1.0.0"
        )
        let backup = CompanionBackupServiceError.backupManifestMissing

        try require(
            traversal.companionErrorCode == "PACK_VALIDATION_PATH_TRAVERSAL",
            "path traversal code changed"
        )
        try require(
            media.companionErrorCode == "PACK_MEDIA_DIMENSIONS_MISMATCH",
            "media dimensions code changed"
        )
        try require(
            conflict.companionErrorCode == "PACK_STORE_VERSION_CONFLICT",
            "store conflict code changed"
        )
        try require(
            backup.companionErrorCode == "BACKUP_SERVICE_MANIFEST_MISSING",
            "backup service code changed"
        )

        let presented = CompanionErrorPresentation.message(for: traversal)
        try require(
            presented.contains("PACK_VALIDATION_PATH_TRAVERSAL"),
            "user presentation omitted the support code"
        )
        try require(
            !presented.contains("../private/secret.mov"),
            "user presentation leaked a local or pack-relative path"
        )
        let unknown = NSError(
            domain: "fixture",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "/Users/example/private/project"]
        )
        let unknownPresentation = CompanionErrorPresentation.message(for: unknown)
        try require(
            unknownPresentation.contains("COMPANION_UNEXPECTED_ERROR"),
            "unknown error omitted the fallback support code"
        )
        try require(
            !unknownPresentation.contains("/Users/example"),
            "unknown error presentation leaked an absolute path"
        )
    }

    private static func failureReceiptUIPresentationAndLogMatrix() throws {
        let cases: [(state: String, error: Error, code: String)] = [
            (
                "missing-required",
                ContentPackValidationError.strictPackageMetadataMissing,
                "PACK_VALIDATION_STRICT_PACKAGE_METADATA_MISSING"
            ),
            (
                "accessibility-missing",
                ContentPackValidationError.strictAccessibilityMetadataMissing("scene"),
                "PACK_VALIDATION_STRICT_ACCESSIBILITY_METADATA_MISSING"
            ),
            (
                "malicious-unknown-field",
                ContentPackValidationError.unknownManifestField(
                    "manifest.<invalid-key>"
                ),
                "PACK_VALIDATION_UNKNOWN_MANIFEST_FIELD"
            ),
            (
                "media-failure-with-starter-fallback",
                ContentPackMediaProbeError.invalidJSON("scene"),
                "PACK_MEDIA_INVALID_JSON"
            ),
            (
                "unrecoverable-missing-manifest",
                ContentPackValidationError.manifestMissing,
                "PACK_VALIDATION_MANIFEST_MISSING"
            ),
            (
                "private-path-disclosure",
                ContentPackValidationError.privatePathInContribution("asset scene"),
                "PACK_VALIDATION_PRIVATE_PATH_DISCLOSURE"
            ),
            (
                "invalid-focal-track",
                ContentPackValidationError.invalidFocalTrack(asset: "scene", mode: "pet"),
                "PACK_VALIDATION_INVALID_FOCAL_TRACK"
            ),
            (
                "invalid-safe-area",
                ContentPackValidationError.invalidSafeArea(asset: "scene", mode: "pet"),
                "PACK_VALIDATION_INVALID_SAFE_AREA"
            ),
            (
                "safe-area-not-visible",
                ContentPackValidationError.safeAreaNotVisible(asset: "scene", mode: "pet"),
                "PACK_VALIDATION_SAFE_AREA_NOT_VISIBLE"
            ),
            (
                "recovery-invalid-id",
                ContentPackStoreError.invalidRecoveryItemIdentifier,
                "PACK_STORE_INVALID_RECOVERY_ITEM"
            ),
            (
                "projection-requires-app-version",
                ContentPackValidationError.projectionFeatureRequiresAppVersion(
                    asset: "scene",
                    required: "0.19.28"
                ),
                "PACK_VALIDATION_PROJECTION_REQUIRES_APP_VERSION"
            ),
            (
                "workday-trigger-requires-app-version",
                ContentPackValidationError.workdayTriggerRequiresAppVersion(
                    trigger: "taskStarted",
                    required: "0.19.42"
                ),
                "PACK_VALIDATION_WORKDAY_TRIGGER_REQUIRES_APP_VERSION"
            )
        ]
        let encoder = JSONEncoder()
        for row in cases {
            let receipt = CompanionFailureReceipt(
                error: row.error,
                fallbackCode: "COMPANION_UNEXPECTED_ERROR"
            )
            let json = String(
                decoding: try encoder.encode(receipt),
                as: UTF8.self
            )
            let ui = CompanionErrorPresentation.message(for: row.error)
            try require(receipt.code == row.code, "\(row.state) receipt code drifted")
            try require(ui.contains(row.code), "\(row.state) UI omitted the code")
            try require(
                receipt.safeLog.contains("[\(row.code)]"),
                "\(row.state) log omitted the code"
            )
            try require(
                receipt.safeLog.contains(receipt.recoveryAction),
                "\(row.state) log omitted the recovery action"
            )
            for forbidden in ["/Users/", "/Volumes/", "file://", "alice"] {
                try require(
                    !json.contains(forbidden)
                        && !receipt.safeLog.contains(forbidden)
                        && !ui.contains(forbidden),
                    "\(row.state) exposed private path material"
                )
            }
        }
    }

    private static func validV2ExperienceIsAccepted() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let asset = try fixture.makeManifest().assets[0]
        let experience = ContentPackExperience(
            id: "ritual.evening-welcome",
            kind: .ritual,
            triggers: ["evening"],
            steps: [
                ContentPackExperienceStep(
                    assetID: asset.id,
                    role: .enter,
                    minimumPlaybackMs: 800,
                    transition: .crossfade
                ),
                ContentPackExperienceStep(
                    assetID: asset.id,
                    role: .react,
                    minimumPlaybackMs: nil,
                    transition: .cut
                )
            ],
            locales: ["zh-Hans"],
            cooldownSeconds: 900,
            weight: 1.5,
            returnPolicy: .previousMode
        )
        let manifest = fixture.manifest(
            schemaVersion: 2,
            assets: [asset],
            experiences: [experience]
        )
        try fixture.write(manifest)
        let decoded = try ContentPackValidator().loadAndValidate(
            packageDirectory: fixture.root,
            currentAppVersion: "0.20.0"
        )
        try require(
            decoded.experiences?.first == experience,
            "v2 experience did not survive manifest decoding"
        )
    }

    private static func validContributionMetadataIsAccepted() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let asset = try fixture.makeManifest().assets[0]
        let contribution = completeContribution(assetID: asset.id)
        let manifest = fixture.manifest(
            schemaVersion: 2,
            assets: [asset],
            contribution: contribution
        )
        try fixture.write(manifest)
        let decoded = try ContentPackValidator().loadAndValidate(
            packageDirectory: fixture.root,
            currentAppVersion: "0.20.0"
        )
        try require(
            decoded.contribution == contribution,
            "contribution metadata changed during decoding"
        )
    }

    private static func strictContributionContractIsAccepted() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let asset = try fixture.makeManifest().assets[0]
        let manifest = fixture.manifest(
            schemaVersion: 2,
            assets: [asset],
            contribution: strictContribution(assetID: asset.id)
        )
        try fixture.write(manifest)
        let decoded = try ContentPackValidator().loadAndValidate(
            packageDirectory: fixture.root,
            currentAppVersion: "0.20.0"
        )
        try require(
            decoded.contributionMode == .strictV2,
            "strict contribution was not recognized as strict v2"
        )
        try require(
            decoded.contributionReadiness.isReady,
            "complete strict contribution was not ready"
        )
    }

    private static func orphanContributionMetadataIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let asset = try fixture.makeManifest().assets[0]
        var contribution = completeContribution(assetID: "missing-asset")
        contribution = ContentPackContributionMetadata(
            rights: contribution.rights,
            accessibility: [],
            fallback: contribution.fallback
        )
        try fixture.write(
            fixture.manifest(
                schemaVersion: 2,
                assets: [asset],
                contribution: contribution
            )
        )
        try requireError(.unknownRightsAsset("missing-asset")) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func schema1ContributionIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let asset = try fixture.makeManifest().assets[0]
        try fixture.write(
            fixture.manifest(
                schemaVersion: 1,
                assets: [asset],
                contribution: completeContribution(assetID: asset.id)
            )
        )
        try requireError(.contributionRequiresSchema2) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func completeContribution(
        assetID: String
    ) -> ContentPackContributionMetadata {
        ContentPackContributionMetadata(
            rights: [
                ContentPackAssetRights(
                    assetID: assetID,
                    origin: .generative,
                    holder: "Fixture creator",
                    license: "LicenseRef-Fixture",
                    evidenceID: "fixture.rights.001",
                    sourceSHA256: nil,
                    commercialUseReviewed: true,
                    subjectStatus: .fictionalAdult
                )
            ],
            accessibility: [
                ContentPackAssetAccessibility(
                    assetID: assetID,
                    descriptions: ["zh-Hans": "成年虚构角色在室内向用户挥手。"],
                    transcripts: ["zh-Hans": "欢迎回来。"],
                    flashingLights: false,
                    suddenLoudAudio: false
                )
            ],
            fallback: ContentPackFallbackDeclaration(strategy: .starter)
        )
    }

    private static func strictContribution(
        assetID: String
    ) -> ContentPackContributionMetadata {
        let approved = ContentPackReviewRecord(
            status: .approved,
            version: 1,
            reviewerID: "fixture.reviewer"
        )
        return ContentPackContributionMetadata(
            contractVersion: 2,
            package: ContentPackPackageProvenance(
                source: "fixture source generated for contract tests",
                author: "Fixture creator",
                provider: "Fixture provider",
                origin: .generative,
                license: "LicenseRef-Fixture",
                authorizationBasis: .providerOutput,
                allowedUses: ContentPackAllowedUse.allCases,
                attribution: ContentPackAttributionRequirement(
                    required: false,
                    text: nil
                ),
                adultFictionStatus: .fictionalAdultsOnly,
                evidenceID: "fixture.package.001",
                review: approved
            ),
            rights: [
                ContentPackAssetRights(
                    assetID: assetID,
                    origin: .generative,
                    holder: "Fixture creator",
                    license: "LicenseRef-Fixture",
                    evidenceID: "fixture.rights.001",
                    sourceSHA256: nil,
                    commercialUseReviewed: true,
                    subjectStatus: .fictionalAdult,
                    source: "fixture video generated for contract tests",
                    author: "Fixture creator",
                    provider: "Fixture provider",
                    authorizationBasis: .providerOutput,
                    allowedUses: ContentPackAllowedUse.allCases,
                    attribution: ContentPackAttributionRequirement(
                        required: false,
                        text: nil
                    ),
                    review: approved
                )
            ],
            accessibility: [
                ContentPackAssetAccessibility(
                    assetID: assetID,
                    descriptions: ["zh-Hans": "成年虚构角色在室内向用户挥手。"],
                    transcripts: ["zh-Hans": "欢迎回来。"],
                    altText: ["zh-Hans": "成年虚构角色微笑挥手。"],
                    captions: ["zh-Hans": "欢迎回来。"],
                    soundDescriptions: ["zh-Hans": "轻柔的人声，没有突发响声。"],
                    flashingLights: false,
                    suddenLoudAudio: false,
                    review: approved
                )
            ],
            fallback: ContentPackFallbackDeclaration(
                strategy: .starter,
                assets: [
                    ContentPackAssetFallback(
                        assetID: assetID,
                        strategy: .starter
                    )
                ]
            )
        )
    }

    private static func v1ExperienceIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let asset = try fixture.makeManifest().assets[0]
        let experience = ContentPackExperience(
            id: "reaction.greeting",
            kind: .reaction,
            triggers: ["singleTap"],
            steps: [
                ContentPackExperienceStep(
                    assetID: asset.id,
                    role: .react,
                    minimumPlaybackMs: nil,
                    transition: nil
                )
            ],
            locales: nil,
            cooldownSeconds: nil,
            weight: nil,
            returnPolicy: .previousMode
        )
        try fixture.write(
            fixture.manifest(
                schemaVersion: 1,
                assets: [asset],
                experiences: [experience]
            )
        )
        try requireError(.v2FeaturesRequireSchema2) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func unknownExperienceAssetIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let asset = try fixture.makeManifest().assets[0]
        let experience = ContentPackExperience(
            id: "scene.missing-asset",
            kind: .sceneStory,
            triggers: ["doubleTap"],
            steps: [
                ContentPackExperienceStep(
                    assetID: "missing-video",
                    role: .react,
                    minimumPlaybackMs: nil,
                    transition: nil
                )
            ],
            locales: nil,
            cooldownSeconds: nil,
            weight: nil,
            returnPolicy: .previousMode
        )
        try fixture.write(
            fixture.manifest(
                schemaVersion: 2,
                assets: [asset],
                experiences: [experience]
            )
        )
        try requireError(
            .unknownExperienceAsset(
                experience: "scene.missing-asset",
                asset: "missing-video"
            )
        ) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func pathTraversalIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }

        let valid = try fixture.makeManifest()
        let unsafe = fixture.asset(
            path: "../outside.mov",
            hash: valid.assets[0].sha256
        )
        try fixture.write(fixture.manifest(assets: [unsafe]))
        try requireError(
            .invalidAssetPath("../outside.mov")
        ) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func symbolicLinkEscapeIsRejected() throws {
        let fixture = try PackFixture()
        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("chengyin-outside-\(UUID().uuidString).mov")
        defer {
            fixture.remove()
            try? FileManager.default.removeItem(at: outside)
        }
        try Data("outside media".utf8).write(to: outside)
        try FileManager.default.removeItem(at: fixture.mediaURL)
        try FileManager.default.createSymbolicLink(
            at: fixture.mediaURL,
            withDestinationURL: outside
        )
        let hash = try ContentPackValidator.sha256(of: outside)
        try fixture.write(
            fixture.manifest(
                assets: [fixture.asset(path: "media/scene.mov", hash: hash)]
            )
        )
        try requireError(.assetOutsidePackage("media/scene.mov")) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func duplicateAssetIDIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let manifest = try fixture.makeManifest()
        try fixture.write(
            fixture.manifest(assets: [manifest.assets[0], manifest.assets[0]])
        )
        try requireError(.duplicateAssetID("scene")) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func duplicateAssetPathIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let manifest = try fixture.makeManifest()
        let original = manifest.assets[0]
        let alias = ContentPackAsset(
            id: "scene.alias",
            kind: original.kind,
            path: original.path,
            sha256: original.sha256,
            durationMs: original.durationMs,
            width: original.width,
            height: original.height,
            aspectRatio: original.aspectRatio,
            hasNativeAudio: original.hasNativeAudio,
            loop: original.loop,
            cropAnchors: original.cropAnchors,
            triggers: original.triggers,
            tags: original.tags,
            cooldownSeconds: original.cooldownSeconds,
            weight: original.weight
        )
        try fixture.write(fixture.manifest(assets: [original, alias]))
        try requireError(.duplicateAssetPath("media/scene.mov")) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func unknownManifestFieldIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        try fixture.write(fixture.makeManifest())
        let manifestURL = fixture.root.appendingPathComponent("manifest.json")
        var object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: manifestURL)
        ) as! [String: Any]
        object["unexpected"] = true
        try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: manifestURL)
        try requireError(.unknownManifestField("manifest.unexpected")) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func privateEvidencePathIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let asset = try fixture.makeManifest().assets[0]
        let base = completeContribution(assetID: asset.id)
        let rights = ContentPackAssetRights(
            assetID: asset.id,
            origin: .original,
            holder: "Fixture creator",
            license: "LicenseRef-Fixture",
            evidenceID: "fixture.rights.private-path",
            sourceSHA256: nil,
            commercialUseReviewed: false,
            subjectStatus: .fictionalAdult,
            source: "/Users/alice/private/source.mov"
        )
        let contribution = ContentPackContributionMetadata(
            rights: [rights],
            accessibility: base.accessibility,
            fallback: base.fallback
        )
        try fixture.write(
            fixture.manifest(
                schemaVersion: 2,
                assets: [asset],
                contribution: contribution
            )
        )
        try requireError(.privatePathInContribution("asset scene")) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func duplicateAssetFallbackIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let asset = try fixture.makeManifest().assets[0]
        let base = completeContribution(assetID: asset.id)
        let duplicate = ContentPackAssetFallback(
            assetID: asset.id,
            strategy: .starter
        )
        let contribution = ContentPackContributionMetadata(
            rights: base.rights,
            accessibility: base.accessibility,
            fallback: ContentPackFallbackDeclaration(
                strategy: .starter,
                assets: [duplicate, duplicate]
            )
        )
        try fixture.write(
            fixture.manifest(
                schemaVersion: 2,
                assets: [asset],
                contribution: contribution
            )
        )
        try requireError(.duplicateFallbackAsset(asset.id)) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func oversizedSingleAssetIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let handle = try FileHandle(forWritingTo: fixture.mediaURL)
        try handle.truncate(
            atOffset: UInt64(ContentPackValidator.maximumSingleAssetBytes + 1)
        )
        try handle.close()
        let asset = fixture.asset(
            path: "media/scene.mov",
            hash: String(repeating: "0", count: 64)
        )
        try fixture.write(fixture.manifest(assets: [asset]))
        try requireError(
            .assetTooLarge(
                asset: asset.id,
                actual: ContentPackValidator.maximumSingleAssetBytes + 1,
                maximum: ContentPackValidator.maximumSingleAssetBytes
            )
        ) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func decodeBombDeclarationsAreRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let valid = try fixture.makeManifest().assets[0]
        let oversized = ContentPackAsset(
            id: valid.id,
            kind: valid.kind,
            path: valid.path,
            sha256: valid.sha256,
            durationMs: valid.durationMs,
            width: 100_000,
            height: 100_000,
            aspectRatio: valid.aspectRatio,
            hasNativeAudio: valid.hasNativeAudio,
            loop: valid.loop,
            cropAnchors: valid.cropAnchors,
            triggers: valid.triggers,
            tags: valid.tags,
            cooldownSeconds: valid.cooldownSeconds,
            weight: valid.weight
        )
        try fixture.write(fixture.manifest(assets: [oversized]))
        try requireError(.mediaDimensionsTooLarge(valid.id)) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func modifiedMediaIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }

        let manifest = try fixture.makeManifest()
        try fixture.write(manifest)
        try Data("changed after manifest".utf8).write(to: fixture.mediaURL)
        try requireError(
            .hashMismatch(path: "media/scene.mov")
        ) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func newerMinimumVersionIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }

        let valid = try fixture.makeManifest()
        let newer = ContentPackManifest(
            schemaVersion: valid.schemaVersion,
            id: valid.id,
            version: valid.version,
            minAppVersion: "0.21.0",
            tier: valid.tier,
            character: valid.character,
            locales: valid.locales,
            assets: valid.assets,
            license: valid.license
        )
        try fixture.write(newer)
        try requireError(
            .appVersionTooOld(required: "0.21.0", current: "0.20.0")
        ) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func undeclaredFileIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        try fixture.write(fixture.makeManifest())
        let extra = fixture.root.appendingPathComponent("media/undeclared.mov")
        try Data("not declared".utf8).write(to: extra)
        try requireError(.undeclaredFile("media/undeclared.mov")) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func hiddenFileIsRejected() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        try fixture.write(fixture.makeManifest())
        let hidden = fixture.root.appendingPathComponent(".DS_Store")
        try Data("hidden".utf8).write(to: hidden)
        try requireError(.hiddenPathNotAllowed(".DS_Store")) {
            _ = try ContentPackValidator().loadAndValidate(
                packageDirectory: fixture.root,
                currentAppVersion: "0.20.0"
            )
        }
    }

    private static func flatArchiveInstallsTransactionallyAndCleansStaging() async throws {
        let pack = try PackFixture(media: "archive-install")
        let storeFixture = try StoreFixture()
        let archiveRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "chengyin-archive-smoke-\(UUID().uuidString)",
                isDirectory: true
            )
        let archive = archiveRoot.appendingPathComponent(
            "valid.chengyinpack",
            isDirectory: false
        )
        let importRoot = archiveRoot.appendingPathComponent(
            "imports",
            isDirectory: true
        )
        defer {
            pack.remove()
            storeFixture.remove()
            try? FileManager.default.removeItem(at: archiveRoot)
        }
        try pack.write(pack.makeManifest())
        try FileManager.default.createDirectory(
            at: archiveRoot,
            withIntermediateDirectories: true
        )
        try createFlatZip(from: pack.root, at: archive)
        let library = CompanionContentLibrary(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe(),
            archiveImporter: ContentPackArchiveImporter(
                temporaryRoot: importRoot
            )
        )
        let snapshot = try await library.install(from: archive)
        try require(
            snapshot.result.pack.record.packID == pack.packID,
            "archive install returned the wrong pack"
        )
        try require(
            snapshot.inventory.count == 1,
            "archive install returned stale inventory"
        )
        let leftovers = try FileManager.default.contentsOfDirectory(
            at: importRoot,
            includingPropertiesForKeys: nil
        )
        try require(
            leftovers.isEmpty,
            "successful archive install retained private extraction staging"
        )
    }

    private static func corruptArchivePreservesInstalledInventory() async throws {
        let pack = try PackFixture(media: "archive-stable")
        let storeFixture = try StoreFixture()
        let archiveRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "chengyin-archive-negative-\(UUID().uuidString)",
                isDirectory: true
            )
        let corrupt = archiveRoot.appendingPathComponent(
            "corrupt.chengyinpack",
            isDirectory: false
        )
        defer {
            pack.remove()
            storeFixture.remove()
            try? FileManager.default.removeItem(at: archiveRoot)
        }
        try pack.write(pack.makeManifest())
        try FileManager.default.createDirectory(
            at: archiveRoot,
            withIntermediateDirectories: true
        )
        try Data("not-a-zip".utf8).write(to: corrupt)
        let library = CompanionContentLibrary(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe(),
            archiveImporter: ContentPackArchiveImporter(
                temporaryRoot: archiveRoot.appendingPathComponent(
                    "imports",
                    isDirectory: true
                )
            )
        )
        _ = try await library.install(from: pack.root)
        do {
            _ = try await library.install(from: corrupt)
            throw SmokeFailure("corrupt archive unexpectedly installed")
        } catch let error as ContentPackArchiveError {
            try require(
                error == .invalidArchive,
                "corrupt archive returned the wrong stable error"
            )
        }
        let inventory = try await library.reportPlayback(
            reference: ContentPackPlaybackReference(
                packID: pack.packID,
                version: pack.version,
                health: .pendingHealth
            ),
            succeeded: true
        )
        try require(
            inventory.count == 1
                && inventory[0].record.packID == pack.packID,
            "corrupt archive changed installed inventory"
        )
    }

    private static func createFlatZip(from directory: URL, at archive: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = directory
        process.arguments = ["-q", "-r", archive.path, "."]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        try require(
            process.terminationReason == .exit && process.terminationStatus == 0,
            "failed to create the flat archive smoke fixture"
        )
    }

    private static func installUpgradeAndRollbackAreTransactional() async throws {
        let storeFixture = try StoreFixture()
        defer { storeFixture.remove() }
        let versionOne = try PackFixture(version: "1.0.0", media: "version-one")
        let versionTwo = try PackFixture(version: "2.0.0", media: "version-two")
        try versionOne.write(versionOne.makeManifest())
        try versionTwo.write(versionTwo.makeManifest())
        defer {
            versionOne.remove()
            versionTwo.remove()
        }

        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        let first = try await store.install(from: versionOne.root)
        try require(first.pack.record.version == "1.0.0", "v1 was not activated")
        let second = try await store.install(from: versionTwo.root)
        try require(second.pack.record.version == "2.0.0", "v2 was not activated")
        try require(
            second.pack.record.previousVersion == "1.0.0",
            "v1 was not recorded for rollback"
        )
        let rolledBack = try await store.rollback(packID: "cc.chengyin.pack.test")
        try require(rolledBack.record.version == "1.0.0", "rollback did not restore v1")
        try require(
            rolledBack.record.previousVersion == "2.0.0",
            "rollback did not retain a roll-forward target"
        )
    }

    private static func interruptedStagingCleanupIsScoped() async throws {
        let storeFixture = try StoreFixture()
        defer { storeFixture.remove() }
        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        _ = try await store.recoverInterruptedInstalls()

        let fileManager = FileManager.default
        let stagingRoot = storeFixture.root.appendingPathComponent("staging", isDirectory: true)
        let expired = stagingRoot.appendingPathComponent("expired.staging", isDirectory: true)
        let fresh = stagingRoot.appendingPathComponent("fresh.staging", isDirectory: true)
        let unrelated = stagingRoot.appendingPathComponent("keep-directory", isDirectory: true)
        let activeSentinel = storeFixture.root
            .appendingPathComponent("packs", isDirectory: true)
            .appendingPathComponent("sentinel/versions/1.0.0", isDirectory: true)
        for directory in [expired, fresh, unrelated, activeSentinel] {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        let fixedNow = Date(timeIntervalSince1970: 2_000_000)
        try fileManager.setAttributes(
            [.modificationDate: fixedNow.addingTimeInterval(-7_200)],
            ofItemAtPath: expired.path
        )
        try fileManager.setAttributes(
            [.modificationDate: fixedNow.addingTimeInterval(-7_200)],
            ofItemAtPath: unrelated.path
        )
        try fileManager.setAttributes(
            [.modificationDate: fixedNow],
            ofItemAtPath: fresh.path
        )

        let repository = ContentPackStoreRepository(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            fileManager: fileManager
        )
        let maintenance = ContentPackStoreMaintenanceTransactions(repository: repository)
        let removed = try repository.withStoreLock { scope in
            try maintenance.recoverInterruptedInstalls(
                olderThan: 3_600,
                now: fixedNow,
                lockedBy: scope
            )
        }
        try require(removed == 1, "cleanup did not remove exactly one expired staging directory")
        try require(!fileManager.fileExists(atPath: expired.path), "expired staging directory survived cleanup")
        try require(fileManager.fileExists(atPath: fresh.path), "fresh staging directory was removed")
        try require(fileManager.fileExists(atPath: unrelated.path), "non-staging directory was removed")
        try require(fileManager.fileExists(atPath: activeSentinel.path), "active-version namespace was touched")
    }

    private static func injectedFailurePreservesActiveVersion() async throws {
        let storeFixture = try StoreFixture()
        defer { storeFixture.remove() }
        let versionOne = try PackFixture(version: "1.0.0", media: "stable")
        let versionTwo = try PackFixture(version: "2.0.0", media: "candidate")
        try versionOne.write(versionOne.makeManifest())
        try versionTwo.write(versionTwo.makeManifest())
        defer {
            versionOne.remove()
            versionTwo.remove()
        }

        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        _ = try await store.install(from: versionOne.root)
        do {
            _ = try await store.install(
                from: versionTwo.root,
                failAt: .afterVersionCommit
            )
            throw SmokeFailure("injected install failure unexpectedly succeeded")
        } catch let error as ContentPackStoreError {
            try require(
                error == .injectedFailure(.afterVersionCommit),
                "unexpected injected failure: \(error)"
            )
        }

        let active = try await store.activePack(id: "cc.chengyin.pack.test")
        try require(active.record.version == "1.0.0", "failed upgrade changed active v1")
        let failedVersion = storeFixture.root
            .appendingPathComponent("packs/cc.chengyin.pack.test/versions/2.0.0")
        try require(
            !FileManager.default.fileExists(atPath: failedVersion.path),
            "failed upgrade left a committed v2 directory"
        )
    }

    private static func stagingCopyFailureLeavesNoStoreMutation() async throws {
        let storeFixture = try StoreFixture()
        defer { storeFixture.remove() }
        let candidate = try PackFixture(version: "1.0.0", media: "candidate")
        try candidate.write(candidate.makeManifest())
        defer { candidate.remove() }

        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        do {
            _ = try await store.install(
                from: candidate.root,
                failAt: .afterStagingCopy
            )
            throw SmokeFailure("staging-copy failure unexpectedly succeeded")
        } catch let error as ContentPackStoreError {
            try require(
                error == .injectedFailure(.afterStagingCopy),
                "unexpected staging-copy error: \(error)"
            )
        }

        let stagingRoot = storeFixture.root.appendingPathComponent(
            "staging",
            isDirectory: true
        )
        let staged = try FileManager.default.contentsOfDirectory(
            at: stagingRoot,
            includingPropertiesForKeys: nil
        )
        try require(staged.isEmpty, "staging-copy failure left a private copy")
        let packRoot = storeFixture.root.appendingPathComponent(
            "packs/cc.chengyin.pack.test",
            isDirectory: true
        )
        try require(
            !FileManager.default.fileExists(atPath: packRoot.path),
            "staging-copy failure created a pack directory"
        )
        let inventory = try await store.inventory()
        try require(inventory.isEmpty, "staging-copy failure changed inventory")
    }

    private static func stagedCandidateIsRevalidatedAfterAsyncProbe() async throws {
        let storeFixture = try StoreFixture()
        defer { storeFixture.remove() }
        let candidate = try PackFixture(version: "1.0.0", media: "candidate")
        try candidate.write(candidate.makeManifest())
        defer { candidate.remove() }

        let probe = SuspendedContentPackMediaProbe()
        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: probe
        )
        let installTask = Task {
            try await store.install(from: candidate.root)
        }
        await probe.waitUntilEntered()

        do {
            let stagingRoot = storeFixture.root.appendingPathComponent(
                "staging",
                isDirectory: true
            )
            let staged = try FileManager.default.contentsOfDirectory(
                at: stagingRoot,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            try require(staged.count == 1, "install did not expose one bounded staging copy")
            let stagedMedia = staged[0].appendingPathComponent("media/scene.mov")
            try Data("changed-after-probe-started".utf8).write(to: stagedMedia)
        } catch {
            await probe.release()
            _ = try? await installTask.value
            throw error
        }

        await probe.release()
        do {
            _ = try await installTask.value
            throw SmokeFailure("mutated staged candidate unexpectedly committed")
        } catch let error as ContentPackValidationError {
            try require(
                error == .hashMismatch(path: "media/scene.mov"),
                "staged revalidation returned the wrong failure: \(error)"
            )
        }
        let inventory = try await store.inventory()
        try require(inventory.isEmpty, "failed staged revalidation changed inventory")
        let leftovers = try FileManager.default.contentsOfDirectory(
            at: storeFixture.root.appendingPathComponent("staging"),
            includingPropertiesForKeys: nil
        )
        try require(leftovers.isEmpty, "failed staged revalidation left temporary content")
    }

    private static func sameVersionConflictIsRejected() async throws {
        let storeFixture = try StoreFixture()
        defer { storeFixture.remove() }
        let original = try PackFixture(version: "1.0.0", media: "original")
        let changed = try PackFixture(version: "1.0.0", media: "different")
        try original.write(original.makeManifest())
        try changed.write(changed.makeManifest())
        defer {
            original.remove()
            changed.remove()
        }

        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        _ = try await store.install(from: original.root)
        do {
            _ = try await store.install(from: changed.root)
            throw SmokeFailure("same-version content conflict unexpectedly succeeded")
        } catch let error as ContentPackStoreError {
            try require(
                error == .versionConflict(
                    packID: "cc.chengyin.pack.test",
                    version: "1.0.0"
                ),
                "unexpected version conflict error: \(error)"
            )
        }
    }

    private static func downgradeRequiresExplicitRollback() async throws {
        let storeFixture = try StoreFixture()
        defer { storeFixture.remove() }
        let newer = try PackFixture(version: "2.0.0", media: "newer")
        let older = try PackFixture(version: "1.0.0", media: "older")
        try newer.write(newer.makeManifest())
        try older.write(older.makeManifest())
        defer {
            newer.remove()
            older.remove()
        }

        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        _ = try await store.install(from: newer.root)
        do {
            _ = try await store.install(from: older.root)
            throw SmokeFailure("implicit downgrade unexpectedly succeeded")
        } catch let error as ContentPackStoreError {
            try require(
                error == .downgradeNotAllowed(
                    current: "2.0.0",
                    requested: "1.0.0"
                ),
                "unexpected downgrade error: \(error)"
            )
        }
    }

    private static func officialPackRequiresSignatureVerifier() async throws {
        let storeFixture = try StoreFixture()
        defer { storeFixture.remove() }
        let official = try PackFixture(
            version: "1.0.0",
            media: "official",
            tier: .free
        )
        try official.write(official.makeManifest())
        defer { official.remove() }

        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        do {
            _ = try await store.install(from: official.root)
            throw SmokeFailure("unsigned official pack unexpectedly installed")
        } catch let error as ContentPackStoreError {
            try require(
                error == .signatureVerifierRequired("cc.chengyin.pack.test"),
                "unexpected signature gate error: \(error)"
            )
        }
    }

    private static func playbackHealthPromotesOrRollsBack() async throws {
        let storeFixture = try StoreFixture()
        defer { storeFixture.remove() }
        let versionOne = try PackFixture(version: "1.0.0", media: "healthy-v1")
        let versionTwo = try PackFixture(version: "2.0.0", media: "bad-v2")
        try versionOne.write(versionOne.makeManifest())
        try versionTwo.write(versionTwo.makeManifest())
        defer {
            versionOne.remove()
            versionTwo.remove()
        }

        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        let first = try await store.install(from: versionOne.root)
        try require(
            first.pack.record.health == .pendingHealth,
            "new version did not enter pending health"
        )
        let healthy = try await store.markPlaybackSucceeded(
            packID: first.pack.record.packID,
            version: first.pack.record.version
        )
        try require(healthy.record.health == .healthy, "v1 did not become healthy")

        let second = try await store.install(from: versionTwo.root)
        try require(
            second.pack.record.health == .pendingHealth,
            "v2 did not enter pending health"
        )
        let restored = try await store.reportPlaybackFailure(
            packID: second.pack.record.packID,
            version: second.pack.record.version
        )
        try require(restored.record.version == "1.0.0", "playback failure did not restore v1")
        try require(restored.record.health == .healthy, "restored v1 is not healthy")
    }

    private static func postActivationCrashKeepsCompletePendingRevision() async throws {
        let storeFixture = try StoreFixture()
        defer { storeFixture.remove() }
        let versionOne = try PackFixture(version: "1.0.0", media: "old")
        let versionTwo = try PackFixture(version: "2.0.0", media: "complete-new")
        try versionOne.write(versionOne.makeManifest())
        try versionTwo.write(versionTwo.makeManifest())
        defer {
            versionOne.remove()
            versionTwo.remove()
        }

        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        _ = try await store.install(from: versionOne.root)
        do {
            _ = try await store.install(
                from: versionTwo.root,
                failAt: .afterActivation
            )
            throw SmokeFailure("post-activation crash simulation unexpectedly succeeded")
        } catch let error as ContentPackStoreError {
            try require(
                error == .injectedFailure(.afterActivation),
                "unexpected post-activation error: \(error)"
            )
        }

        let reconstructed = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        let active = try await reconstructed.activePack(id: "cc.chengyin.pack.test")
        try require(active.record.version == "2.0.0", "atomic pointer lost complete v2")
        try require(active.record.health == .pendingHealth, "v2 health state was not pending")
    }

    private static func removalIsRecoverable() async throws {
        let storeFixture = try StoreFixture()
        defer { storeFixture.remove() }
        let pack = try PackFixture(version: "1.0.0", media: "recoverable")
        try pack.write(pack.makeManifest())
        defer { pack.remove() }

        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        _ = try await store.install(from: pack.root)
        let receipt = try await store.remove(packID: "cc.chengyin.pack.test")
        try require(
            FileManager.default.fileExists(atPath: receipt.quarantinedDirectory.path),
            "removed pack was not moved to the recovery area"
        )
        let restored = try await store.restoreRemoval(receipt)
        try require(restored.record.version == "1.0.0", "removed pack did not restore")
    }

    private static func recoveryCatalogSurvivesRestart() async throws {
        let storeFixture = try StoreFixture()
        let pack = try PackFixture(version: "1.0.0", media: "restart-recovery")
        defer {
            storeFixture.remove()
            pack.remove()
        }
        try pack.write(pack.makeManifest())
        let firstStore = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        _ = try await firstStore.install(from: pack.root)
        let removal = try await firstStore.remove(packID: pack.packID)

        let restartedStore = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        let recovery = try await restartedStore.recoveryInventory()
        try require(recovery.count == 1, "restart lost the recovery item")
        try require(recovery[0].state == .recoverable, "valid recovery was not restorable")
        try require(recovery[0].packID == pack.packID, "recovery projected the wrong pack")
        try require(
            !recovery[0].id.contains("/") && recovery[0].id == removal.quarantinedDirectory.lastPathComponent,
            "recovery exposed a path instead of an opaque ID"
        )
        let restored = try await restartedStore.restoreRecoveryItem(id: recovery[0].id)
        try require(restored.record.packID == pack.packID, "restart recovery restored the wrong pack")
        let remainingRecovery = try await restartedStore.recoveryInventory()
        try require(remainingRecovery.isEmpty, "restored item stayed in recovery")
    }

    private static func invalidRecoveryIdentifierIsRejected() async throws {
        let storeFixture = try StoreFixture()
        defer { storeFixture.remove() }
        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        do {
            _ = try await store.restoreRecoveryItem(id: "../packs/secret")
            throw SmokeFailure("recovery traversal unexpectedly passed")
        } catch let error as ContentPackStoreError {
            try require(
                error == .invalidRecoveryItemIdentifier,
                "recovery traversal returned the wrong stable error"
            )
        }
    }

    private static func damagedRecoveryDoesNotBrickValidItems() async throws {
        let storeFixture = try StoreFixture()
        let valid = try PackFixture(media: "valid-recovery", packID: "cc.chengyin.pack.valid")
        let damaged = try PackFixture(media: "damaged-recovery", packID: "cc.chengyin.pack.damaged")
        defer {
            storeFixture.remove()
            valid.remove()
            damaged.remove()
        }
        try valid.write(valid.makeManifest())
        try damaged.write(damaged.makeManifest())
        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        _ = try await store.install(from: valid.root)
        _ = try await store.install(from: damaged.root)
        _ = try await store.remove(packID: valid.packID)
        let damagedRemoval = try await store.remove(packID: damaged.packID)
        try Data("{}".utf8).write(
            to: damagedRemoval.quarantinedDirectory.appendingPathComponent("active.json")
        )
        let inventory = try await store.recoveryInventory()
        try require(inventory.count == 2, "damaged recovery hid another item")
        try require(
            inventory.contains { $0.packID == valid.packID && $0.state == .recoverable },
            "valid recovery was not preserved"
        )
        try require(
            inventory.contains {
                $0.packID == damaged.packID
                    && $0.state == .needsCleanup
                    && $0.failureCode == ContentPackRecoveryCatalog.invalidMetadataCode
            },
            "damaged metadata was not isolated with a stable code"
        )
    }

    private static func failedRestoreReturnsItemToRecoveryArea() async throws {
        let storeFixture = try StoreFixture()
        let pack = try PackFixture(media: "restore-rollback")
        defer {
            storeFixture.remove()
            pack.remove()
        }
        try pack.write(pack.makeManifest())
        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        _ = try await store.install(from: pack.root)
        let receipt = try await store.remove(packID: pack.packID)
        try Data("{}".utf8).write(
            to: receipt.quarantinedDirectory.appendingPathComponent("active.json")
        )
        do {
            _ = try await store.restoreRemoval(receipt)
            throw SmokeFailure("damaged removal receipt unexpectedly restored")
        } catch is SmokeFailure {
            throw SmokeFailure("damaged removal receipt unexpectedly restored")
        } catch {
            try require(
                FileManager.default.fileExists(atPath: receipt.quarantinedDirectory.path),
                "failed restore did not return the item to recovery"
            )
            let activeInventory = try await store.inventory()
            try require(activeInventory.isEmpty, "failed restore changed active inventory")
        }
    }

    private static func symlinkRecoveryPurgesLinkOnly() async throws {
        let storeFixture = try StoreFixture()
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent(
            "chengyin-recovery-target-\(UUID().uuidString)",
            isDirectory: true
        )
        defer {
            storeFixture.remove()
            try? FileManager.default.removeItem(at: outside)
        }
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let sentinel = outside.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: sentinel)
        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        _ = try await store.recoveryInventory()
        let id = "fixture--cc.chengyin.pack.symlink"
        let link = storeFixture.root.appendingPathComponent("removed/\(id)")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let recovery = try await store.recoveryInventory()
        try require(
            recovery.count == 1
                && recovery[0].state == .needsCleanup
                && recovery[0].failureCode == ContentPackRecoveryCatalog.symlinkEntryCode,
            "recovery symlink was not isolated"
        )
        try await store.purgeRecoveryItem(id: id)
        try require(
            FileManager.default.fileExists(atPath: sentinel.path),
            "purging a recovery symlink followed it outside the store"
        )
        var linkStatus = stat()
        try require(lstat(link.path, &linkStatus) != 0, "recovery symlink was not removed")
    }

    private static func recoveryInventoryIsBounded() async throws {
        let storeFixture = try StoreFixture()
        defer { storeFixture.remove() }
        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        _ = try await store.recoveryInventory()
        let removed = storeFixture.root.appendingPathComponent("removed", isDirectory: true)
        for index in 0...ContentPackRecoveryCatalog.maximumItems {
            try FileManager.default.createDirectory(
                at: removed.appendingPathComponent("fixture-\(index)"),
                withIntermediateDirectories: false
            )
        }
        do {
            _ = try await store.recoveryInventory()
            throw SmokeFailure("oversized recovery inventory unexpectedly passed")
        } catch let error as ContentPackStoreError {
            try require(
                error == .tooManyRecoveryItems,
                "oversized recovery inventory returned the wrong stable error"
            )
        }
    }

    private static func contentLibraryKeepsInventorySnapshotsCurrent() async throws {
        let storeFixture = try StoreFixture()
        let pack = try PackFixture(version: "1.0.0", media: "library-snapshot")
        defer {
            storeFixture.remove()
            pack.remove()
        }
        try pack.write(pack.makeManifest())

        let library = CompanionContentLibrary(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        let installed = try await library.install(from: pack.root)
        try require(installed.inventory.count == 1, "install returned stale inventory")
        try require(
            installed.result.pack.record.packID == pack.packID,
            "install returned the wrong pack"
        )

        let removed = try await library.remove(packID: pack.packID)
        try require(removed.inventory.isEmpty, "remove returned stale inventory")
        try require(removed.recovery.count == 1, "remove omitted recovery state")
        let restored = try await library.restoreRemoval(removed.receipt)
        try require(restored.inventory.count == 1, "restore returned stale inventory")
        try require(restored.recovery.isEmpty, "restore retained stale recovery state")
        try require(
            restored.pack.record.packID == pack.packID,
            "restore returned the wrong pack"
        )
    }

    private static func contentStoreSnapshotProjectsActiveAndRecoveryTogether() async throws {
        let storeFixture = try StoreFixture()
        let active = try PackFixture(
            media: "snapshot-active",
            packID: "cc.chengyin.pack.snapshot-active"
        )
        let removed = try PackFixture(
            media: "snapshot-removed",
            packID: "cc.chengyin.pack.snapshot-removed"
        )
        defer {
            storeFixture.remove()
            active.remove()
            removed.remove()
        }
        try active.write(active.makeManifest())
        try removed.write(removed.makeManifest())

        let store = ContentPackStore(
            root: storeFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        _ = try await store.install(from: active.root)
        _ = try await store.install(from: removed.root)
        _ = try await store.remove(packID: removed.packID)

        let snapshot = try await store.snapshot()
        try require(
            snapshot.inventory.map(\.record.packID) == [active.packID],
            "snapshot returned the wrong active inventory"
        )
        try require(
            snapshot.recovery.count == 1
                && snapshot.recovery[0].packID == removed.packID,
            "snapshot returned recovery from a different store state"
        )
    }

    @MainActor
    private static func contentOperationsCoordinateStateAndSafeReceipts() async throws {
        let storeFixture = try StoreFixture()
        let pack = try PackFixture(
            version: "1.0.0",
            media: "operations-coordinator"
        )
        defer {
            storeFixture.remove()
            pack.remove()
        }
        try pack.write(pack.makeManifest())

        let coordinator = CompanionContentOperationsCoordinator(
            library: CompanionContentLibrary(
                root: storeFixture.root,
                currentAppVersion: "0.20.0",
                mediaProbe: AcceptingContentPackMediaProbe()
            )
        )
        guard let install = await coordinator.install(from: pack.root) else {
            throw SmokeFailure("coordinator rejected an idle install")
        }
        try require(install.succeeded, "coordinator install failed")
        if case let .installed(result, inventory) = install.success {
            try require(
                result.pack.record.packID == pack.packID,
                "coordinator returned the wrong installed pack"
            )
            try require(inventory.count == 1, "coordinator returned stale install inventory")
        } else {
            throw SmokeFailure("coordinator returned the wrong install receipt")
        }
        try require(
            !coordinator.contentPackOperationInProgress,
            "coordinator left install progress active"
        )

        guard let removed = await coordinator.remove(packID: pack.packID) else {
            throw SmokeFailure("coordinator rejected an idle removal")
        }
        if case let .removed(inventory, recovery) = removed.success {
            try require(inventory.isEmpty, "coordinator returned stale removal inventory")
            try require(recovery.count == 1, "coordinator omitted the recovery inventory")
        } else {
            throw SmokeFailure("coordinator returned the wrong removal receipt")
        }
        try require(
            coordinator.contentPackUndoRemovalAvailable,
            "coordinator did not expose recoverable removal"
        )

        guard let restored = await coordinator.restoreLastRemoval() else {
            throw SmokeFailure("coordinator rejected recoverable removal")
        }
        if case let .removalRestored(restoredPack, inventory, recovery) = restored.success {
            try require(
                restoredPack.record.packID == pack.packID,
                "restored the wrong pack"
            )
            try require(inventory.count == 1, "restore returned stale inventory")
            try require(recovery.isEmpty, "restore returned stale recovery inventory")
        } else {
            throw SmokeFailure("coordinator returned the wrong restore receipt")
        }
        try require(
            !coordinator.contentPackUndoRemovalAvailable,
            "coordinator retained a consumed removal receipt"
        )

        _ = await coordinator.remove(packID: pack.packID)
        let restartedCoordinator = CompanionContentOperationsCoordinator(
            library: CompanionContentLibrary(
                root: storeFixture.root,
                currentAppVersion: "0.20.0",
                mediaProbe: AcceptingContentPackMediaProbe()
            )
        )
        let startupRecovery = try await restartedCoordinator.recoverInterruptedInstalls()
        try require(
            startupRecovery.recovery.count == 1
                && restartedCoordinator.contentPackRecoveryItems.count == 1,
            "coordinator restart lost the persistent recovery inventory"
        )
        guard let restartRestored = await restartedCoordinator.restoreRecoveryItem(
            id: startupRecovery.recovery[0].id
        ) else {
            throw SmokeFailure("coordinator rejected a restart recovery")
        }
        if case let .removalRestored(_, inventory, recovery) = restartRestored.success {
            try require(inventory.count == 1, "restart recovery returned stale inventory")
            try require(recovery.isEmpty, "restart recovery returned a stale recovery list")
        } else {
            throw SmokeFailure("coordinator returned the wrong restart recovery receipt")
        }
        _ = await restartedCoordinator.remove(packID: pack.packID)
        let purgeID = restartedCoordinator.contentPackRecoveryItems[0].id
        guard let purged = await restartedCoordinator.purgeRecoveryItem(id: purgeID) else {
            throw SmokeFailure("coordinator rejected an explicit recovery purge")
        }
        if case let .recoveryPurged(inventory, recovery) = purged.success {
            try require(inventory.isEmpty, "purge changed the empty active inventory")
            try require(recovery.isEmpty, "purge retained the deleted recovery item")
        } else {
            throw SmokeFailure("coordinator returned the wrong purge receipt")
        }

        let missing = storeFixture.root.appendingPathComponent(
            "missing-contribution",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: missing,
            withIntermediateDirectories: true
        )
        guard let failed = await coordinator.install(from: missing) else {
            throw SmokeFailure("coordinator rejected an idle negative fixture")
        }
        try require(!failed.succeeded, "invalid coordinator install passed")
        let failure = failed.presentedError ?? ""
        try require(
            failure.contains("PACK_VALIDATION_MANIFEST_MISSING"),
            "coordinator failure lost its stable code"
        )
        try require(
            !failure.contains(storeFixture.root.path)
                && !failure.contains("/Users/")
                && !failure.contains("/Volumes/"),
            "coordinator failure disclosed a local path"
        )
        try require(
            !coordinator.contentPackOperationInProgress,
            "coordinator left failed progress active"
        )
    }

    private static func portableBackupRoundTripRestoresSettingsAndPacks() async throws {
        let sourceStoreFixture = try StoreFixture()
        let restoredStoreFixture = try StoreFixture()
        let pack = try PackFixture(version: "1.0.0", media: "portable-backup")
        let backupDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "chengyin-backup-\(UUID().uuidString)",
                isDirectory: true
            )
        defer {
            sourceStoreFixture.remove()
            restoredStoreFixture.remove()
            pack.remove()
            try? FileManager.default.removeItem(at: backupDirectory)
        }
        try pack.write(pack.makeManifest())

        let sourceStore = ContentPackStore(
            root: sourceStoreFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        _ = try await sourceStore.install(from: pack.root)
        let sourceService = CompanionBackupService(
            packStore: sourceStore,
            appVersion: "0.20.0"
        )
        let settings = CompanionSettingsV1(
            relationshipTone: .playfulSpark,
            locale: "zh-Hans",
            presentationMode: .stage,
            interactionEnabled: false,
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
            learnedGestureIDs: ["singleTap", "doubleTap", "drag"]
        )
        let exported = try await sourceService.export(
            to: backupDirectory,
            settings: settings
        )
        try require(exported.packs.count == 1, "active pack was not exported")
        try require(
            FileManager.default.fileExists(
                atPath: backupDirectory.appendingPathComponent("backup.json").path
            ),
            "backup manifest was not written"
        )

        let restoredStore = ContentPackStore(
            root: restoredStoreFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        let restoredService = CompanionBackupService(
            packStore: restoredStore,
            appVersion: "0.20.0"
        )
        let result = try await restoredService.restore(from: backupDirectory)
        try require(result.settings == settings, "portable settings changed during restore")
        try require(result.installedPacks.count == 1, "pack was not restored")
        let inventory = try await restoredStore.inventory()
        try require(inventory.count == 1, "restored pack was not activated")
        try require(
            inventory[0].record.packID == pack.packID,
            "restored pack ID changed"
        )
    }

    private static func portableBackupPreflightPreventsPartialRestore() async throws {
        let sourceStoreFixture = try StoreFixture()
        let restoredStoreFixture = try StoreFixture()
        let first = try PackFixture(
            media: "first-backup-pack",
            packID: "cc.chengyin.pack.alpha"
        )
        let second = try PackFixture(
            media: "second-backup-pack",
            packID: "cc.chengyin.pack.omega"
        )
        let backupDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "chengyin-preflight-backup-\(UUID().uuidString)",
                isDirectory: true
            )
        defer {
            sourceStoreFixture.remove()
            restoredStoreFixture.remove()
            first.remove()
            second.remove()
            try? FileManager.default.removeItem(at: backupDirectory)
        }
        try first.write(first.makeManifest())
        try second.write(second.makeManifest())
        let sourceStore = ContentPackStore(
            root: sourceStoreFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        _ = try await sourceStore.install(from: first.root)
        _ = try await sourceStore.install(from: second.root)
        let sourceService = CompanionBackupService(
            packStore: sourceStore,
            appVersion: "0.20.0"
        )
        _ = try await sourceService.export(
            to: backupDirectory,
            settings: CompanionSettingsV1()
        )
        let tamperedMedia = backupDirectory
            .appendingPathComponent("packs", isDirectory: true)
            .appendingPathComponent(second.packID, isDirectory: true)
            .appendingPathComponent(second.version, isDirectory: true)
            .appendingPathComponent("media/scene.mov")
        try Data("tampered".utf8).write(to: tamperedMedia)

        let restoredStore = ContentPackStore(
            root: restoredStoreFixture.root,
            currentAppVersion: "0.20.0",
            mediaProbe: AcceptingContentPackMediaProbe()
        )
        let restoredService = CompanionBackupService(
            packStore: restoredStore,
            appVersion: "0.20.0"
        )
        do {
            _ = try await restoredService.restore(from: backupDirectory)
            throw SmokeFailure("tampered backup unexpectedly restored")
        } catch let error as ContentPackValidationError {
            try require(
                error == .hashMismatch(path: "media/scene.mov"),
                "unexpected preflight failure: \(error)"
            )
        }
        let inventory = try await restoredStore.inventory()
        try require(
            inventory.isEmpty,
            "a pack was installed before the later backup candidate passed preflight"
        )
    }

    private static func runtimeCatalogResolvesInstalledVideo() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let base = try fixture.makeManifest().assets[0]
        let dynamic = projectionAsset(
            from: base,
            focalTracks: [
                "pet": [
                    .init(timeMs: 0, x: 0.5, y: 0.35, scale: 2.8),
                    .init(timeMs: 4_000, x: 0.5, y: 0.35, scale: 2.8)
                ]
            ],
            safeAreas: [
                "pet": .init(x: 0.42, y: 0.28, width: 0.16, height: 0.14)
            ]
        )
        let experience = ContentPackExperience(
            id: "reaction.accessible-wave",
            kind: .reaction,
            triggers: ["doubleTap"],
            steps: [
                ContentPackExperienceStep(
                    assetID: dynamic.id,
                    role: .react,
                    minimumPlaybackMs: nil,
                    transition: nil
                )
            ],
            locales: nil,
            cooldownSeconds: nil,
            weight: nil,
            returnPolicy: .previousMode
        )
        let manifest = fixture.manifest(
            schemaVersion: 2,
            assets: [dynamic],
            experiences: [experience],
            contribution: strictContribution(assetID: dynamic.id)
        )
        try fixture.write(manifest)
        let pack = InstalledContentPack(
            record: ActiveContentPackRecord(
                packID: fixture.packID,
                version: fixture.version,
                previousVersion: nil,
                health: .pendingHealth
            ),
            manifest: manifest,
            directory: fixture.root
        )
        let catalog = ContentPackRuntimeCatalog(activePacks: [pack])
        guard let asset = catalog.firstVideo(
            for: ["doubleTap"],
            preferredLocale: "zh-Hans-CN"
        ) else {
            throw SmokeFailure("installed video was absent from runtime catalog")
        }
        try require(asset.url == fixture.mediaURL, "runtime URL did not point into pack")
        try require(asset.hasNativeAudio, "native audio declaration was lost")
        try require(
            asset.focalTracks["pet"]?.count == 2,
            "runtime focal track was lost"
        )
        try require(
            asset.safeAreas["pet"]?.width == 0.16,
            "runtime safe area was lost"
        )
        try require(
            asset.packReference?.health == .pendingHealth,
            "pending health reference was lost"
        )
        guard let sequence = catalog.selectExperience(
            for: ["doubleTap"],
            preferredLocale: "zh-Hans-CN",
            randomSeed: 1
        )?.sequence,
        let accessibility = sequence.resolvedAccessibility(
            preferredLocale: "zh-Hans-CN"
        ) else {
            throw SmokeFailure("validated accessibility was absent at runtime")
        }
        try require(
            accessibility.label == "成年虚构角色微笑挥手。",
            "runtime alt text did not use the compatible locale"
        )
        try require(
            accessibility.value == "欢迎回来。 轻柔的人声，没有突发响声。",
            "runtime caption and sound description were not projected"
        )
        try require(
            !accessibility.flashingLights && !accessibility.suddenLoudAudio,
            "runtime media warnings changed during projection"
        )
    }

    private static func runtimeAccessibilityIsLocalizedSanitizedAndBounded() throws {
        let longCopy = "  first\n" + String(repeating: "x", count: 2_000)
        let declaration = ContentPackAssetAccessibility(
            assetID: "scene",
            descriptions: ["en": "English fallback"],
            transcripts: ["en": "spoken line"],
            altText: [
                "zh-Hans": longCopy,
                "zh-Hant": "繁體無障礙說明"
            ],
            captions: ["zh-Hans": "  第一行\n第二行  "],
            soundDescriptions: ["zh-Hans": "轻柔环境声。"],
            flashingLights: true,
            suddenLoudAudio: true,
            review: nil
        )
        let descriptor = CompanionRuntimeMediaAccessibility(
            declaration: declaration,
            localeOrder: ["zh-Hans", "en"]
        ).resolved(preferredLocale: "zh_Hans_CN")
        try require(descriptor != nil, "runtime accessibility did not resolve")
        try require(
            descriptor?.label?.count
                == CompanionRuntimeMediaAccessibility.maximumLabelCharacters,
            "runtime accessibility label was not bounded"
        )
        try require(
            descriptor?.label?.contains("\n") == false,
            "runtime accessibility label kept unbounded whitespace"
        )
        try require(
            descriptor?.value == "第一行 第二行 轻柔环境声。",
            "runtime accessibility value was not compact and deterministic"
        )
        try require(
            descriptor?.flashingLights == true
                && descriptor?.suddenLoudAudio == true,
            "runtime accessibility warnings were lost"
        )
        try require(
            CompanionRuntimeMediaAccessibility(
                declaration: declaration,
                localeOrder: ["zh-Hans", "zh-Hant", "en"]
            ).resolved(preferredLocale: "zh-TW")?.label == "繁體無障礙說明",
            "runtime accessibility copy disagreed with script-aware media selection"
        )
    }

    private static func runtimeCatalogPrefersMatchingLocale() throws {
        let english = try PackFixture(
            packID: "cc.chengyin.pack.english",
            locales: ["en"]
        )
        let chinese = try PackFixture(
            packID: "cc.chengyin.pack.chinese",
            locales: ["zh-Hans"]
        )
        let british = try PackFixture(
            packID: "cc.chengyin.pack.british",
            locales: ["en-GB"]
        )
        defer {
            english.remove()
            chinese.remove()
            british.remove()
        }
        let englishManifest = try english.makeManifest()
        let chineseManifest = try chinese.makeManifest()
        let britishManifest = try british.makeManifest()
        try english.write(englishManifest)
        try chinese.write(chineseManifest)
        try british.write(britishManifest)
        let packs = [
            InstalledContentPack(
                record: ActiveContentPackRecord(
                    packID: english.packID,
                    version: english.version,
                    previousVersion: nil,
                    health: .healthy
                ),
                manifest: englishManifest,
                directory: english.root
            ),
            InstalledContentPack(
                record: ActiveContentPackRecord(
                    packID: chinese.packID,
                    version: chinese.version,
                    previousVersion: nil,
                    health: .healthy
                ),
                manifest: chineseManifest,
                directory: chinese.root
            ),
            InstalledContentPack(
                record: ActiveContentPackRecord(
                    packID: british.packID,
                    version: british.version,
                    previousVersion: nil,
                    health: .healthy
                ),
                manifest: britishManifest,
                directory: british.root
            )
        ]
        let catalog = ContentPackRuntimeCatalog(activePacks: packs)
        let match = catalog.firstVideo(
            for: ["evening"],
            preferredLocale: "en-US"
        )
        try require(
            match?.packReference?.packID == english.packID,
            "generic English did not outrank a conflicting regional declaration"
        )
        let exact = catalog.firstVideo(
            for: ["evening"],
            preferredLocale: "en-GB"
        )
        try require(
            exact?.packReference?.packID == british.packID,
            "exact regional declaration did not win runtime selection"
        )
    }

    private static func runtimeCatalogExcludesDisabledPack() throws {
        let fixture = try PackFixture()
        defer { fixture.remove() }
        let manifest = try fixture.makeManifest()
        try fixture.write(manifest)
        let disabled = InstalledContentPack(
            record: ActiveContentPackRecord(
                packID: fixture.packID,
                version: fixture.version,
                previousVersion: nil,
                health: .disabled
            ),
            manifest: manifest,
            directory: fixture.root
        )
        let catalog = ContentPackRuntimeCatalog(activePacks: [disabled])
        try require(
            catalog.videos(
                for: "doubleTap",
                preferredLocale: "zh-Hans"
            ).isEmpty,
            "disabled pack leaked into runtime catalog"
        )
    }

    private static func qualityLevelsAreDerivedFromTrustState() throws {
        let local = try PackFixture(packID: "cc.chengyin.pack.quality-local")
        let official = try PackFixture(
            tier: .free,
            packID: "cc.chengyin.pack.quality-official"
        )
        defer {
            local.remove()
            official.remove()
        }
        let localManifest = try local.makeManifest()
        let officialManifest = try official.makeManifest()

        func pack(
            fixture: PackFixture,
            manifest: ContentPackManifest,
            health: ContentPackHealthStatus
        ) -> InstalledContentPack {
            InstalledContentPack(
                record: ActiveContentPackRecord(
                    packID: fixture.packID,
                    version: fixture.version,
                    previousVersion: nil,
                    health: health
                ),
                manifest: manifest,
                directory: fixture.root
            )
        }

        try require(
            pack(
                fixture: local,
                manifest: localManifest,
                health: .pendingHealth
            ).qualityLevel == .lab,
            "pending local pack escaped Lab"
        )
        try require(
            pack(
                fixture: local,
                manifest: localManifest,
                health: .healthy
            ).qualityLevel == .stable,
            "healthy local pack was not Stable"
        )
        try require(
            pack(
                fixture: official,
                manifest: officialManifest,
                health: .healthy
            ).qualityLevel == .verified,
            "signed-tier healthy pack was not Verified"
        )
    }

    private static func mediaProbeAcceptsRealVideo() async throws {
        let (fixture, manifest) = try realVideoFixture()
        defer { fixture.remove() }
        try await creatorContentPackMediaProbe().probe(
            packageDirectory: fixture.root,
            manifest: manifest
        )
        try require(
            [
                "avfoundation",
                "avfoundation+fixed-ffmpeg-full-software-decode",
            ].contains(creatorMediaValidationBackendID()),
            "media validation backend was not explicit"
        )
    }

    private static func mediaTimelineAlignmentPolicyIsDeterministic() throws {
        let accepted = ContentPackMediaQualityPolicy.timelineAlignment(
            videoStartMs: 0,
            videoDurationMs: 4_042,
            audioStartMs: 0,
            audioDurationMs: 4_096
        )
        try require(accepted.isAcceptable, "54ms end offset was rejected")
        let rejected = ContentPackMediaQualityPolicy.timelineAlignment(
            videoStartMs: 0,
            videoDurationMs: 4_000,
            audioStartMs: 251,
            audioDurationMs: 4_000
        )
        try require(!rejected.isAcceptable, "251ms start offset was accepted")
        try require(
            rejected.startOffsetMs == 251 && rejected.endOffsetMs == 251,
            "timeline offsets were not measured deterministically"
        )
    }

    private static func mediaProbeRejectsAudioDeclarationMismatch() async throws {
        let (fixture, manifest) = try realVideoFixture(hasNativeAudio: false)
        defer { fixture.remove() }
        do {
            try await creatorContentPackMediaProbe().probe(
                packageDirectory: fixture.root,
                manifest: manifest
            )
            throw SmokeFailure("audio declaration mismatch unexpectedly passed")
        } catch let error as ContentPackMediaProbeError {
            try require(
                error == .audioDeclarationMismatch(
                    asset: "real-video",
                    declared: false,
                    actual: true
                ),
                "unexpected audio mismatch error: \(error)"
            )
        }
    }

    private static func mediaProbeRejectsDimensionMismatch() async throws {
        let (fixture, manifest) = try realVideoFixture(width: 1_279)
        defer { fixture.remove() }
        do {
            try await creatorContentPackMediaProbe().probe(
                packageDirectory: fixture.root,
                manifest: manifest
            )
            throw SmokeFailure("dimension mismatch unexpectedly passed")
        } catch let error as ContentPackMediaProbeError {
            try require(
                error == .dimensionsMismatch(
                    asset: "real-video",
                    declaredWidth: 1_279,
                    declaredHeight: 720,
                    actualWidth: 1_280,
                    actualHeight: 720
                ),
                "unexpected dimension mismatch error: \(error)"
            )
        }
    }

    private static func mediaProbeRejectsCorruptVideoWithStableCode() async throws {
        let fixture = try PackFixture(media: "not a video container")
        defer { fixture.remove() }
        let manifest = try fixture.makeManifest()
        try fixture.write(manifest)
        do {
            try await creatorContentPackMediaProbe().probe(
                packageDirectory: fixture.root,
                manifest: manifest
            )
            throw SmokeFailure("corrupt video unexpectedly passed media probe")
        } catch let error as ContentPackMediaProbeError {
            try require(
                error.companionErrorCode == "PACK_MEDIA_NOT_PLAYABLE",
                "corrupt media did not normalize to a stable media code"
            )
        }
    }

    private static func mediaProbeRejectsCorruptTailWithStableCode() async throws {
        let (fixture, manifest) = try realVideoFixture()
        defer { fixture.remove() }
        var data = try Data(contentsOf: fixture.mediaURL)
        guard let mediaAtom = data.range(of: Data("mdat".utf8)),
              let movieAtom = data.range(of: Data("moov".utf8)),
              movieAtom.lowerBound > mediaAtom.upperBound + 500_000 else {
            throw SmokeFailure("real video fixture has no bounded media tail")
        }
        let payloadEnd = movieAtom.lowerBound - 4
        let corruptionStart = payloadEnd - 400_000
        data.replaceSubrange(
            corruptionStart..<payloadEnd,
            with: Data(repeating: 0, count: payloadEnd - corruptionStart)
        )
        try data.write(to: fixture.mediaURL, options: .atomic)

        do {
            try await creatorContentPackMediaProbe().probe(
                packageDirectory: fixture.root,
                manifest: manifest
            )
            throw SmokeFailure("corrupt media tail unexpectedly passed")
        } catch let error as ContentPackMediaProbeError {
            let expectedCode = creatorMediaValidationBackendID() == "avfoundation"
                ? "PACK_MEDIA_CHECKPOINT_DECODE_FAILED"
                : "PACK_MEDIA_FIRST_FRAME_DECODE_FAILED"
            try require(
                error.companionErrorCode == expectedCode,
                "corrupt tail produced the wrong stable code: \(error)"
            )
        }
    }

    private static func realVideoFixture(
        hasNativeAudio: Bool = true,
        width: Int = 1_280
    ) throws -> (PackFixture, ContentPackManifest) {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = repositoryRoot
            .appendingPathComponent(
                "Sources/CompanionApp/Resources/companion-master-landscape.mov"
            )
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw SmokeFailure("real video fixture is missing")
        }
        let fixture = try PackFixture(media: "placeholder")
        try FileManager.default.removeItem(at: fixture.mediaURL)
        try FileManager.default.copyItem(at: source, to: fixture.mediaURL)
        let hash = try ContentPackValidator.sha256(of: fixture.mediaURL)
        let video = ContentPackAsset(
            id: "real-video",
            kind: .video,
            path: "media/scene.mov",
            sha256: hash,
            durationMs: 4_096,
            width: width,
            height: 720,
            aspectRatio: "16:9",
            hasNativeAudio: hasNativeAudio,
            loop: false,
            cropAnchors: [
                "pet": .init(x: 0.5, y: 0.35, scale: 2.8),
                "partial": .init(x: 0.5, y: 0.5, scale: 1)
            ],
            triggers: ["doubleTap"],
            tags: ["real-media-probe"],
            cooldownSeconds: 0,
            weight: 1
        )
        let manifest = fixture.manifest(assets: [video])
        try fixture.write(manifest)
        return (fixture, manifest)
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        guard condition() else {
            throw SmokeFailure(message)
        }
    }

    private static func requireError(
        _ expected: ContentPackValidationError,
        operation: () throws -> Void
    ) throws {
        do {
            try operation()
            throw SmokeFailure("expected \(expected), but validation succeeded")
        } catch let error as ContentPackValidationError {
            try require(
                error == expected,
                "expected \(expected), received \(error)"
            )
        }
    }
}

private struct SmokeFailure: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

private struct AcceptingContentPackMediaProbe: ContentPackMediaProbing {
    func probe(
        packageDirectory: URL,
        manifest: ContentPackManifest
    ) async throws {}
}

private actor SuspendedContentPackMediaProbe: ContentPackMediaProbing {
    private var entered = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { continuation in
            enteredWaiters.append(continuation)
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func probe(
        packageDirectory: URL,
        manifest: ContentPackManifest
    ) async throws {
        entered = true
        enteredWaiters.forEach { $0.resume() }
        enteredWaiters.removeAll(keepingCapacity: false)
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }
}

private struct PackFixture {
    let root: URL
    let mediaURL: URL
    let version: String
    let tier: ContentPackManifest.Tier
    let packID: String
    let locales: [String]

    init(
        version: String = "1.0.0",
        media: String = "fixture video bytes",
        tier: ContentPackManifest.Tier = .local,
        packID: String = "cc.chengyin.pack.test",
        locales: [String] = ["zh-Hans"]
    ) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chengyin-pack-\(UUID().uuidString)", isDirectory: true)
        mediaURL = root.appendingPathComponent("media/scene.mov")
        self.version = version
        self.tier = tier
        self.packID = packID
        self.locales = locales
        try FileManager.default.createDirectory(
            at: mediaURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(media.utf8).write(to: mediaURL)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    func makeManifest() throws -> ContentPackManifest {
        let hash = try ContentPackValidator.sha256(of: mediaURL)
        return manifest(assets: [asset(path: "media/scene.mov", hash: hash)])
    }

    func manifest(
        schemaVersion: Int = 1,
        minAppVersion: String = "0.20.0",
        assets: [ContentPackAsset],
        experiences: [ContentPackExperience]? = nil,
        contribution: ContentPackContributionMetadata? = nil
    ) -> ContentPackManifest {
        ContentPackManifest(
            schemaVersion: schemaVersion,
            id: packID,
            version: version,
            minAppVersion: minAppVersion,
            tier: tier,
            character: "chengyin",
            locales: locales,
            assets: assets,
            license: "Test Content License",
            experiences: experiences,
            contribution: contribution
        )
    }

    func asset(path: String, hash: String) -> ContentPackAsset {
        ContentPackAsset(
            id: "scene",
            kind: .video,
            path: path,
            sha256: hash,
            durationMs: 4_000,
            width: 1_280,
            height: 720,
            aspectRatio: "16:9",
            hasNativeAudio: true,
            loop: false,
            cropAnchors: [
                "pet": .init(x: 0.5, y: 0.35, scale: 2.8),
                "partial": .init(x: 0.5, y: 0.5, scale: 1)
            ],
            triggers: ["doubleTap", "evening"],
            tags: ["test"],
            cooldownSeconds: 300,
            weight: 1
        )
    }

    func write(_ manifest: ContentPackManifest) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(
            to: root.appendingPathComponent("manifest.json")
        )
    }
}

private struct StoreFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chengyin-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
