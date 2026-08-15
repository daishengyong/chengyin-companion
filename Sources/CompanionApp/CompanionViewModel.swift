import AppKit
import Combine
import CompanionContracts
import Foundation
import ServiceManagement
import SwiftUI

private func companionText(_ key: String, _ fallback: String) -> String {
    CompanionLocalization.string(key: key, fallback: fallback)
}

private func companionFormat(
    _ key: String,
    _ fallback: String,
    _ arguments: CVarArg...
) -> String {
    String(
        format: CompanionLocalization.string(key: key, fallback: fallback),
        locale: Locale.current,
        arguments: arguments
    )
}

private enum ContentSequenceFallback {
    case event(
        CompanionEventKind,
        CompanionCompletionContext?,
        String?,
        CompanionExperienceSource
    )
    case action(CompanionAction, presentationIntent: CompanionUserPresentationIntent)
    case scene(CompanionScene, presentationIntent: CompanionUserPresentationIntent)
    case miniScene(CompanionMiniScene, presentationIntent: CompanionUserPresentationIntent)
    case workdayCue(CompanionWorkdayContentCue)
}

@MainActor
final class CompanionViewModel: ObservableObject {
    @Published var isSpeaking = false
    @Published var status = companionText("status.presence", "澄音陪着你")
    @Published var eventAction: CompanionAction?
    @Published var activeScene: CompanionScene?
    @Published var activeMiniScene: CompanionMiniScene?
    var activeContentSequence: CompanionVideoSequence? {
        contentSequenceRuntime.activeSequence
    }
    @Published var activeEventKind: CompanionEventKind?
    @Published var activeEventText: String?
    @Published var outfit: CompanionOutfit
    var petMood: PetMood {
        get { feedbackRuntime.mood }
        set { feedbackRuntime.setMood(newValue) }
    }
    var petPose: PetPose {
        get { feedbackRuntime.pose }
        set { feedbackRuntime.setPose(newValue) }
    }
    var petEffect: PetEffect? { feedbackRuntime.effect }
    @Published var directInteractionActive = false
    @Published var playPalettePresented = false
    @Published var catchGameBestScore: Int
    @Published var hideGameBestScore: Int
    @Published var feedGameTreat: CompanionTreat = .strawberry
    @Published var feedGameRound = 0
    @Published var playbackMode: CompanionPlaybackMode {
        didSet { preferenceStore.savePlaybackMode(playbackMode) }
    }
    @Published var reducedDynamicEffectsEnabled: Bool {
        didSet { preferenceStore.saveReducedDynamicEffectsEnabled(reducedDynamicEffectsEnabled) }
    }
    @Published var displayMode: CompanionDisplayMode {
        didSet {
            guard !suppressDisplayPersistence else { return }
            preferenceStore.saveDisplayMode(displayMode)
        }
    }
    @Published var presentationAppearance: CompanionPresentationAppearance {
        didSet { preferenceStore.savePresentationAppearance(presentationAppearance) }
    }
    @Published var displayTarget: CompanionDisplayTarget {
        didSet { preferenceStore.saveDisplayTarget(displayTarget) }
    }
    @Published var remindersEnabled: Bool {
        didSet { preferenceStore.saveRemindersEnabled(remindersEnabled) }
    }
    @Published var careCadence: CompanionCareCadence {
        didSet { preferenceStore.saveCareCadence(careCadence) }
    }
    @Published var timeAnnouncementsEnabled: Bool {
        didSet { preferenceStore.saveTimeAnnouncementsEnabled(timeAnnouncementsEnabled) }
    }
    @Published var halfHourlyAnnouncementsEnabled: Bool {
        didSet { preferenceStore.saveHalfHourlyAnnouncementsEnabled(halfHourlyAnnouncementsEnabled) }
    }
    @Published var quietHoursEnabled: Bool {
        didSet { preferenceStore.saveQuietHoursEnabled(quietHoursEnabled) }
    }
    @Published var flirtyRemindersEnabled: Bool {
        didSet { preferenceStore.saveFlirtyRemindersEnabled(flirtyRemindersEnabled) }
    }
    @Published var codexCompletionAnnouncementsEnabled: Bool {
        didSet { preferenceStore.saveCompletionAnnouncementsEnabled(codexCompletionAnnouncementsEnabled) }
    }
    @Published var usePetName: Bool {
        didSet { preferenceStore.saveUsePetName(usePetName) }
    }
    @Published var randomOutfitsEnabled: Bool {
        didSet { preferenceStore.saveRandomOutfitsEnabled(randomOutfitsEnabled) }
    }
    @Published var petInteractionsEnabled: Bool {
        didSet { preferenceStore.savePetInteractionsEnabled(petInteractionsEnabled) }
    }
    @Published var localContentPacksEnabled: Bool {
        didSet {
            preferenceStore.saveLocalContentPacksEnabled(localContentPacksEnabled)
            contentLibraryRuntime.setEnabled(localContentPacksEnabled)
            rebuildRuntimeReadiness()
        }
    }
    @Published var launchAtLoginEnabled = false
    @Published var launchAtLoginMessage: String?
    @Published var lastError: String?
    var relationshipState: CompanionRelationshipStateV1 {
        relationshipRuntime.state
    }
    var relationshipReceipt: CompanionRelationshipReceipt? {
        relationshipRuntime.receipt
    }
    var gestureCoachLesson: CompanionGestureLesson? { gestureDiscovery.lesson }
    @Published private(set) var keepsMediaInHead = false
    @Published var codexVisualState: CompanionCodexVisualState = .idle
    var installedContentPackCount: Int { contentLibraryRuntime.enabledPackCount }
    var contentPackHealth: String { contentLibraryRuntime.health }
    var contentPackQualitySummary: String { contentLibraryRuntime.qualitySummary }
    var contentPackSummaries: [CompanionContentPackSummary] { contentLibraryRuntime.summaries }
    var contentPackCatalog: ContentPackRuntimeCatalog { contentLibraryRuntime.catalog }
    @Published private(set) var diagnosticOperationMessage: String?
    @Published private(set) var lifestyleRhythmStatus = companionText(
        "care.status.scheduling",
        "正在安排下一次关心"
    )
    var carePausedUntil: Date? { lifestyleRuntime.pausedUntil }
    var workdayState: CompanionWorkdayStateV1 { workdayRuntime.state }
    var firstSessionStep: CompanionFirstSessionStep {
        firstSessionRuntime.journey.step
    }
    var firstSessionWorkArcBeat: CompanionWorkArcPreviewBeat {
        firstSessionRuntime.workArcBeat
    }
    var firstSessionPresented: Bool { firstSessionRuntime.isActive }
    var completionReplyWindowActive: Bool {
        workdayRuntime.completionReplyWindowActive
    }

    private let speaker = VoicePackPlayer()
    private let interactionSpeaker = VoicePackPlayer()
    private let effectSpeaker = VoicePackPlayer()
    private let voiceSelection = CompanionVoiceSelectionRuntimeCoordinator(
        library: VoiceLineLibrary.load()
    )
    private let contentOperations: CompanionContentOperationsCoordinator
    private let preferenceStore = CompanionPreferenceStore()
    private let contentLibraryRuntime = CompanionContentLibraryRuntimeCoordinator()
    private let runtimeRepair = CompanionRuntimeRepairCoordinator()
    private let microgameRuntime = CompanionMicrogameRuntimeCoordinator()
    private let relationshipRuntime =
        CompanionRelationshipRuntimeCoordinator()
    private let gestureDiscovery = CompanionGestureDiscoveryCoordinator()
    private let feedbackRuntime = CompanionPetFeedbackRuntimeCoordinator()
    private let experienceRuntime =
        CompanionExperienceRuntimeCoordinator<CompanionEventKind>()
    private let contentSequenceRuntime =
        CompanionContentSequenceRuntimeCoordinator<ContentSequenceFallback>()
    let firstSessionRuntime =
        CompanionFirstSessionRuntimeCoordinator()
    private let sharedDayRuntime: CompanionSharedDayRuntimeCoordinator
    private var workdayRuntime: CompanionWorkdayRuntimeCoordinator {
        sharedDayRuntime.workday
    }
    private var lifestyleRuntime: CompanionLifestyleRuntimeCoordinator {
        sharedDayRuntime.lifestyle
    }
    let defaults = UserDefaults.standard
    private var contentOperationsObservation: AnyCancellable?
    private var contentLibraryRuntimeObservation: AnyCancellable?
    private var microgameRuntimeObservation: AnyCancellable?
    private var relationshipRuntimeObservation: AnyCancellable?
    private var gestureDiscoveryObservation: AnyCancellable?
    private var feedbackRuntimeObservation: AnyCancellable?
    private var experienceRuntimeObservation: AnyCancellable?
    private var contentSequenceRuntimeObservation: AnyCancellable?
    private var workdayRuntimeObservation: AnyCancellable?
    private var firstSessionRuntimeObservation: AnyCancellable?
    private var runtimeRepairObservation: AnyCancellable?
    var presentationRuntime = CompanionPresentationRuntimeCoordinator()
    private var suppressDisplayPersistence = false
    private var gestureMoveCuePlayed = false
    private var interactionAudioActive = false
    private var hideGameLastEdge: PetDockEdge?
    private var comboLongPressArmed = false
    private var suppressNextHeartTraceDragEnd = false
    private var lastRhythmMissCueAt = Date.distantPast
    private var lastFeedMissCueAt = Date.distantPast
    private static let completionReplyDuration: TimeInterval = 10

    var microgameSession: CompanionMicrogameSession {
        microgameRuntime.session
    }

    var runtimeSupportSnapshot: CompanionRuntimeSupportSnapshot {
        runtimeRepair.snapshot
    }
    var runtimeRepairInProgress: Bool { runtimeRepair.isRepairing }
    var runtimeRepairMessage: String? { runtimeRepair.message }

    var contentPackOperationInProgress: Bool {
        contentOperations.contentPackOperationInProgress
    }
    var contentPackOperationMessage: String? {
        contentOperations.contentPackOperationMessage
    }
    var contentPackUndoRemovalAvailable: Bool {
        contentOperations.contentPackUndoRemovalAvailable
    }
    var contentPackRecoveryItems: [ContentPackRecoveryItem] { contentOperations.contentPackRecoveryItems }
    var backupOperationInProgress: Bool {
        contentOperations.backupOperationInProgress
    }
    var backupOperationMessage: String? {
        contentOperations.backupOperationMessage
    }
    var pendingBackupPreview: CompanionBackupPreview? {
        contentOperations.pendingBackupPreview
    }

    init() {
        let runtimeEnvironment = CompanionRuntimeEnvironment.current(); _ = runtimeEnvironment.publishAuditReceipt()
        let firstSessionLaunchDisposition = CompanionFirstSessionPreferences.launchDisposition(from: defaults)
        let launchDate = Date()
        let workdayRuntime = CompanionWorkdayRuntimeCoordinator(
            adapter: CompanionWorkdayAdapter(now: launchDate),
            watcher: CodexCompletionWatcher(
                root: runtimeEnvironment.legacySessionRoot,
                protocolRoot: runtimeEnvironment.eventRoot,
                startedAt: launchDate,
                legacySessionsEnabled: false
            )
        )
        let lifestyleRuntime = CompanionLifestyleRuntimeCoordinator(now: launchDate)
        sharedDayRuntime = CompanionSharedDayRuntimeCoordinator(
            workday: workdayRuntime,
            lifestyle: lifestyleRuntime
        )

        let appVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.18.0"
        contentOperations = CompanionContentOperationsCoordinator(
            root: runtimeEnvironment.contentRoot,
            currentAppVersion: appVersion
        )

        let savedPreferences = preferenceStore.load().snapshot
        reducedDynamicEffectsEnabled = savedPreferences.reducedDynamicEffectsEnabled
        playbackMode = savedPreferences.playbackMode
        displayMode = savedPreferences.displayMode
        presentationAppearance = savedPreferences.presentationAppearance
        displayTarget = savedPreferences.displayTarget
        remindersEnabled = savedPreferences.remindersEnabled
        careCadence = savedPreferences.careCadence
        timeAnnouncementsEnabled = savedPreferences.timeAnnouncementsEnabled
        halfHourlyAnnouncementsEnabled = savedPreferences.halfHourlyAnnouncementsEnabled
        quietHoursEnabled = savedPreferences.quietHoursEnabled
        flirtyRemindersEnabled = savedPreferences.flirtyRemindersEnabled
        codexCompletionAnnouncementsEnabled =
            savedPreferences.codexCompletionAnnouncementsEnabled
        usePetName = savedPreferences.usePetName
        randomOutfitsEnabled = savedPreferences.randomOutfitsEnabled
        petInteractionsEnabled = savedPreferences.petInteractionsEnabled
        localContentPacksEnabled = savedPreferences.localContentPacksEnabled
        catchGameBestScore = savedPreferences.catchGameBestScore
        hideGameBestScore = savedPreferences.hideGameBestScore
        outfit = .satin
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        contentOperationsObservation = contentOperations.objectWillChange.sink {
            [weak self] _ in
            self?.objectWillChange.send()
        }
        contentLibraryRuntimeObservation = contentLibraryRuntime.objectWillChange.sink {
            [weak self] _ in
            self?.objectWillChange.send()
        }
        microgameRuntimeObservation = microgameRuntime.objectWillChange.sink {
            [weak self] _ in
            self?.objectWillChange.send()
        }
        relationshipRuntimeObservation = relationshipRuntime.objectWillChange.sink {
            [weak self] _ in
            self?.objectWillChange.send()
        }
        gestureDiscoveryObservation = gestureDiscovery.objectWillChange.sink {
            [weak self] _ in
            self?.objectWillChange.send()
        }
        feedbackRuntimeObservation = feedbackRuntime.objectWillChange.sink {
            [weak self] _ in
            self?.objectWillChange.send()
        }
        experienceRuntimeObservation = experienceRuntime.objectWillChange.sink {
            [weak self] _ in
            self?.objectWillChange.send()
        }
        contentSequenceRuntimeObservation = contentSequenceRuntime.objectWillChange.sink {
            [weak self] _ in
            self?.objectWillChange.send()
        }
        workdayRuntimeObservation = sharedDayRuntime.objectWillChange.sink {
            [weak self] _ in
            self?.objectWillChange.send()
        }
        firstSessionRuntimeObservation = firstSessionRuntime.objectWillChange.sink {
            [weak self] _ in
            self?.objectWillChange.send()
        }
        runtimeRepairObservation = runtimeRepair.objectWillChange.sink {
            [weak self] _ in
            self?.objectWillChange.send()
        }
        if workdayState.completedCount > 0 {
            status = CompanionCopy.workdayPresence(
                completedCount: workdayState.completedCount
            )
        }

        // Preserve an existing user's already-explicit romantic preferences,
        // while keeping new installations on the warm, non-romantic default.
        if relationshipState.bondMoments == 0,
           relationshipState.toneCap == .warmSupport,
           usePetName || flirtyRemindersEnabled {
            updateRelationshipState { state in
                state.setToneCap(.romanceLite)
            }
        }

        speaker.onStart = { [weak self] in
            Task { @MainActor in
                self?.isSpeaking = true
            }
        }
        speaker.onFinish = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.isSpeaking = false
                if self.activeContentSequence == nil,
                   self.eventAction == nil,
                   self.activeMiniScene == nil {
                    if !self.directInteractionActive {
                        self.petMood = .calm
                    }
                }
            }
        }
        speaker.onMissing = { [weak self] fileName in
            Task { @MainActor in
                self?.lastError = companionFormat(
                    "error.voice.missingTTS",
                    "缺少火山语音片段：%@",
                    fileName
                )
            }
        }
        interactionSpeaker.onStart = { [weak self] in
            Task { @MainActor in
                self?.interactionAudioActive = true
                self?.isSpeaking = true
            }
        }
        interactionSpeaker.onFinish = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.interactionAudioActive = false
                if !self.speaker.isPlaying,
                   self.activeContentSequence == nil,
                   self.eventAction == nil,
                   self.activeScene == nil,
                   self.activeMiniScene == nil {
                    self.isSpeaking = false
                }
                if !self.directInteractionActive {
                    self.resumePendingEventsAfterInteraction()
                }
            }
        }
        interactionSpeaker.onMissing = { [weak self] fileName in
            Task { @MainActor in
                self?.lastError = companionFormat(
                    "error.voice.missingInteraction",
                    "缺少互动语音片段：%@",
                    fileName
                )
            }
        }

        startSharedDayRuntime()
        startContentPackRecovery()
        rebuildRuntimeReadiness()
        evaluateReminderSchedule()

        switch firstSessionLaunchDisposition {
        case .startCleanInstallation:
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.startFirstSession(replay: false)
            }
        case .preserveExistingInstallation:
            // Do not interrupt established users after an upgrade. The same
            // journey remains replayable from the play palette.
            CompanionFirstSessionPreferences.markCompleted(
                preference: nil,
                in: defaults
            )
        case .alreadyCompleted:
            break
        }
    }

    deinit {
        effectSpeaker.stop()
    }

    func toggleDisplayMode() {
        let next: CompanionDisplayMode
        switch displayMode {
        case .full: next = .compact
        case .compact: next = .head
        case .head: next = .full
        }
        setDisplayMode(next)
    }

    func setDisplayMode(_ mode: CompanionDisplayMode) {
        gestureDiscovery.cancelPendingLesson()
        if catchGameActive {
            stopCatchGame(restorePreviousMode: false, announce: false)
        }
        if hideGameActive {
            stopHideGame(restorePreviousMode: false, announce: false)
        }
        if comboGameActive {
            stopComboGame(restorePreviousMode: false, announce: false)
        }
        if heartTraceGameActive {
            stopHeartTraceGame(restorePreviousMode: false, announce: false)
        }
        if rhythmGameActive {
            stopRhythmGame(restorePreviousMode: false, announce: false)
        }
        if feedGameActive {
            stopFeedGame(restorePreviousMode: false, announce: false)
        }
        presentationRuntime.reset()
        displayMode = mode
    }

    func togglePlaybackMode() {
        setPlaybackMode(
            playbackMode == .audioVisual ? .audioOnly : .audioVisual
        )
    }

    func setPlaybackMode(_ mode: CompanionPlaybackMode) {
        if mode == .audioVisual {
            reducedDynamicEffectsEnabled = false
        }
        preferenceStore.markPlaybackSelectionCurrent()
        playbackMode = mode
        status = playbackMode == .audioVisual
            ? companionText("status.playback.audiovisual", "音画同步模式")
            : companionText("status.playback.audioOnly", "仅声音模式")
    }

    func setReducedDynamicEffectsEnabled(_ enabled: Bool) {
        reducedDynamicEffectsEnabled = enabled
        if enabled {
            experienceRuntime.cancelPresentation()
            contentSequenceRuntime.cancelActive()
            activeScene = nil
            activeMiniScene = nil
            eventAction = nil
            keepsMediaInHead = false
            presentationRuntime.reset()
            isSpeaking = false
            speaker.stop()
            interactionSpeaker.stop()
            playbackMode = .audioOnly
        }
        status = enabled
            ? companionText(
                "status.performance.reduced",
                "低动态模式 · 头像待机与预生成声音"
            )
            : companionText(
                "status.performance.standard",
                "标准动态模式"
            )
    }

    var relationshipTone: CompanionRelationshipTone {
        relationshipState.toneCap
    }

    var relationshipChapterLabel: String {
        CompanionRelationshipFeedbackPolicy.chapterLabel(
            for: relationshipState.bondMoments
        )
    }

    var relationshipMomentsLabel: String {
        companionFormat(
            "relationship.moments.count",
            "%llu 个共同瞬间",
            relationshipState.bondMoments
        )
    }

    var relationshipMementoLabel: String {
        companionFormat(
            "relationship.mementos.count",
            "%d 件纪念物",
            relationshipState.unlockedMementoIDs.count
        )
    }

    var workdayCompactLabel: String {
        CompanionCopy.workdayCompact(completedCount: workdayState.completedCount)
    }

    var workdaySummaryLabel: String {
        CompanionCopy.workdaySummary(state: workdayState)
    }

    func forgetTodayWorkday() {
        let now = Date()
        do {
            try workdayRuntime.resetDay(at: now)
            status = CompanionCopy.workdayForgotten
            showPetEffect(symbol: "leaf.fill", text: CompanionCopy.workdayForgottenShort)
        } catch {
            lastError = CompanionErrorPresentation.message(for: error)
        }
    }

    func forgetRelationshipMemories() {
        do {
            try relationshipRuntime.forgetAllMemory()
            contentSequenceRuntime.resetSelectionCache()
            status = CompanionCopy.relationshipForgotten
            showPetEffect(
                symbol: "heart.slash.fill",
                text: CompanionCopy.relationshipForgottenShort
            )
        } catch {
            lastError = companionFormat(
                "error.memory.clear",
                "共同回忆暂时无法清除：%@",
                error.localizedDescription
            )
        }
    }

    func forgetRelationshipMemory(
        _ scope: CompanionRelationshipMemoryScope
    ) {
        do {
            try relationshipRuntime.forgetMemory(scope)
            switch scope {
            case .sharedProgress:
                break
            case .sessionChemistry:
                break
            case .surpriseProgress:
                break
            case .mementos:
                break
            case .playbackHistory:
                contentSequenceRuntime.resetSelectionCache()
            }
            status = CompanionCopy.relationshipScopeForgotten(scope)
            showPetEffect(
                symbol: "leaf.fill",
                text: CompanionCopy.relationshipMemoryScopeLabel(scope)
            )
        } catch {
            lastError = companionFormat(
                "error.memory.fieldClear",
                "共同回忆暂时无法分项清除：%@",
                error.localizedDescription
            )
        }
    }

    var sessionChemistryLabel: String {
        switch relationshipState.chemistryLevel {
        case 1:
            companionText("relationship.chemistry.one", "开始合拍")
        case 2:
            companionText("relationship.chemistry.two", "越来越有默契")
        case 3:
            companionText("relationship.chemistry.three", "心照不宣")
        default:
            companionText("relationship.chemistry.zero", "正在熟悉彼此")
        }
    }

    func setRelationshipTone(_ tone: CompanionRelationshipTone) {
        updateRelationshipState { state in
            state.setToneCap(tone)
        }
        if !tone.allowsFlirtyReminders {
            flirtyRemindersEnabled = false
        }
        status = companionFormat(
            "status.tone.changed",
            "陪伴语气已切换为%@",
            tone.label
        )
    }

    func pauseCare(for duration: TimeInterval) {
        let now = Date()
        let until = now.addingTimeInterval(max(60, duration))
        if let error = lifestyleRuntime.pause(until: until, at: now) {
            lastError = CompanionErrorPresentation.message(for: error)
            return
        }
        lifestyleRhythmStatus = CompanionLifestylePresentation.paused(
            until: until
        )
    }

    func pauseCareForToday() {
        let now = Date()
        let until = Calendar.current.date(
            bySettingHour: 23,
            minute: 30,
            second: 0,
            of: now
        ) ?? now.addingTimeInterval(4 * 60 * 60)
        let safeUntil = max(until, now.addingTimeInterval(60))
        if let error = lifestyleRuntime.pause(until: safeUntil, at: now) {
            lastError = CompanionErrorPresentation.message(for: error)
            return
        }
        lifestyleRhythmStatus = companionText(
            "care.status.quietToday",
            "今天剩下的时间安静陪伴"
        )
    }

    func resumeCare() {
        let now = Date()
        if let error = lifestyleRuntime.resume(at: now) {
            lastError = CompanionErrorPresentation.message(for: error)
            return
        }
        lifestyleRhythmStatus = companionText(
            "care.status.resumed",
            "主动关心已恢复"
        )
        evaluateReminderSchedule()
    }

    func forgetCareRhythmMemory() {
        let now = Date()
        if let error = lifestyleRuntime.reset(at: now) {
            lastError = CompanionErrorPresentation.message(for: error)
            return
        }
        lifestyleRhythmStatus = companionText(
            "care.status.reset",
            "关心节奏记录已清除，重新从现在开始"
        )
        showPetEffect(
            symbol: "clock.arrow.circlepath",
            text: companionText("effect.care.rescheduled", "重新安排节奏")
        )
        evaluateReminderSchedule()
    }

    func previewLifestyleCare() {
        let options: [CompanionLifestyleReminderKind] = [
            .hydration,
            .sedentaryMovement,
            .eyeRest,
            .focusEncouragement
        ]
        _ = deliverLifestyleReminder(
            options.randomElement() ?? .focusEncouragement,
            at: Date()
        )
    }

    func previewEvent(_ event: CompanionEventKind = .flirt) {
        triggerEvent(
            event,
            priority: true,
            source: .userInitiated
        )
    }

    func previewCodexWorkArc() {
        guard !petGameActive else {
            status = companionText(
                "status.workArc.gameBlocked",
                "先结束当前小游戏，再体验 Codex 工作弧"
            )
            return
        }
        runCodexWorkArcPreview(completesFirstSession: false)
    }

    func clearFirstSessionPresentationState() {
        experienceRuntime.cancelPresentation()
        contentSequenceRuntime.cancelActive()
        speaker.stop()
        interactionSpeaker.stop()
        closeCompletionReplyWindow()
        activeScene = nil
        activeMiniScene = nil
        eventAction = nil
        activeEventKind = nil
        activeEventText = nil
        isSpeaking = false
    }

    func playRandomAction() {
        playAction(CompanionAction.allCases.randomElement() ?? .heart)
    }

    func contentPackVideo(
        for action: CompanionAction,
        eventKind: CompanionEventKind?
    ) -> CompanionVideoAsset? {
        var triggers = eventKind.map(
            CompanionEventTriggerRouting.triggers(for:)
        ) ?? []
        triggers.append("manual:action.\(action.contentAssetID)")
        return selectContentPackVideo(
            key: "action:\(action.rawValue):\(eventKind?.rawValue ?? "manual")",
            triggers: triggers
        )
    }

    func contentPackVideo(for scene: CompanionScene) -> CompanionVideoAsset? {
        selectContentPackVideo(
            key: "scene:\(scene.rawValue)",
            triggers: ["manual:scene.\(scene.rawValue)"]
        )
    }

    func contentPackVideo(for scene: CompanionMiniScene) -> CompanionVideoAsset? {
        selectContentPackVideo(
            key: "mini:\(scene.rawValue)",
            triggers: ["manual:mini.\(scene.rawValue)"]
        )
    }

    var contentPackIdleVideos: [CompanionVideoAsset] {
        contentPackCatalog.videos(
            for: "idle",
            preferredLocale: Self.preferredContentLocale
        )
    }

    func importContentPack(from source: URL) {
        Task { [weak self] in
            guard let self else { return }
            if let receipt = await contentOperations.install(from: source) {
                applyContentOperationReceipt(receipt)
            }
        }
    }

    func rollbackContentPack(id packID: String) {
        Task { [weak self] in
            guard let self else { return }
            if let receipt = await contentOperations.rollback(packID: packID) {
                applyContentOperationReceipt(receipt)
            }
        }
    }

    func removeContentPack(id packID: String) {
        Task { [weak self] in
            guard let self else { return }
            if let receipt = await contentOperations.remove(packID: packID) {
                applyContentOperationReceipt(receipt)
            }
        }
    }

    func undoLastContentPackRemoval() {
        Task { [weak self] in
            guard let self else { return }
            if let receipt = await contentOperations.restoreLastRemoval() {
                applyContentOperationReceipt(receipt)
            }
        }
    }

    func restoreContentPackRecoveryItem(id: String) {
        Task { [weak self] in
            guard let self, let receipt = await contentOperations.restoreRecoveryItem(id: id) else { return }
            applyContentOperationReceipt(receipt)
        }
    }

    func purgeContentPackRecoveryItem(id: String) {
        Task { [weak self] in
            guard let self, let receipt = await contentOperations.purgeRecoveryItem(id: id) else { return }
            applyContentOperationReceipt(receipt)
        }
    }

    func exportPortableBackup(to destination: URL) {
        let settings = backupSettingsSnapshot
        Task { [weak self] in
            guard let self else { return }
            if let receipt = await contentOperations.exportBackup(
                to: destination,
                settings: settings
            ) {
                applyContentOperationReceipt(receipt)
            }
        }
    }

    func inspectPortableBackup(at directory: URL) {
        Task { [weak self] in
            guard let self else { return }
            if let receipt = await contentOperations.inspectBackup(at: directory) {
                applyContentOperationReceipt(receipt)
            }
        }
    }

    func cancelPortableBackupRestore() {
        contentOperations.cancelBackupRestore()
    }

    func restoreInspectedPortableBackup() {
        Task { [weak self] in
            guard let self else { return }
            if let receipt = await contentOperations.restoreInspectedBackup() {
                applyContentOperationReceipt(receipt)
            }
        }
    }

    private func applyContentOperationReceipt(
        _ receipt: CompanionContentOperationReceipt
    ) {
        if let presentedError = receipt.presentedError {
            lastError = presentedError
            if receipt.operation == .install {
                contentLibraryRuntime.setHealth(
                    companionText(
                        "pack.health.importFailed",
                        "内容包导入失败，现有体验未改变"
                    ),
                    enabled: localContentPacksEnabled
                )
            }
            return
        }
        guard let success = receipt.success else { return }
        switch success {
        case let .installed(result, inventory):
            runtimeRepair.markContentLibraryHealthy(true)
            contentLibraryRuntime.replaceInventory(
                inventory,
                enabled: localContentPacksEnabled
            )
            contentLibraryRuntime.invalidatePlaybackValidation(
                packID: result.pack.record.packID,
                version: result.pack.record.version
            )
            contentLibraryRuntime.setHealth(
                companionText(
                    "pack.health.ready",
                    "内容包已就绪，等待真实首播验证"
                ),
                enabled: localContentPacksEnabled
            )
        case let .rolledBack(_, inventory),
             let .removalRestored(_, inventory, _),
             let .removed(inventory, _),
             let .recoveryPurged(inventory, _):
            runtimeRepair.markContentLibraryHealthy(true)
            contentLibraryRuntime.replaceInventory(
                inventory,
                enabled: localContentPacksEnabled
            )
            contentLibraryRuntime.setHealth(
                companionText("pack.health.healthy", "播放正常"),
                enabled: localContentPacksEnabled
            )
        case .backupExported, .backupInspected:
            break
        case let .backupRestored(settings, installedPackCount, inventory):
            let repairs = applyBackupSettings(settings)
            contentOperations.presentBackupRestoreCompletion(
                installedPackCount: installedPackCount,
                repairCount: repairs.count
            )
            runtimeRepair.markContentLibraryHealthy(true)
            contentLibraryRuntime.replaceInventory(
                inventory,
                enabled: localContentPacksEnabled
            )
        }
        rebuildRuntimeReadiness()
    }
    private var backupSettingsSnapshot: CompanionSettingsV1 {
        CompanionSettingsBackupProjection.export(
            preferences: preferenceStore.load().snapshot,
            relationshipTone: relationshipTone,
            locale: Self.preferredContentLocale,
            learnedGestureIDs: gestureDiscovery.learnedIDs
        )
    }

    @discardableResult
    private func applyBackupSettings(
        _ settings: CompanionSettingsV1
    ) -> [CompanionSettingsRestoreRepair] {
        let plan = CompanionSettingsBackupProjection.restore(
            settings,
            currentLocale: Self.preferredContentLocale
        )
        setRelationshipTone(plan.relationshipTone)
        setDisplayMode(plan.displayMode)
        presentationAppearance = plan.presentationAppearance
        displayTarget = plan.displayTarget
        reducedDynamicEffectsEnabled = plan.reducedDynamicEffectsEnabled
        playbackMode = plan.playbackMode
        petInteractionsEnabled = plan.petInteractionsEnabled
        remindersEnabled = plan.remindersEnabled
        careCadence = plan.careCadence
        timeAnnouncementsEnabled = plan.timeAnnouncementsEnabled
        halfHourlyAnnouncementsEnabled = plan.halfHourlyAnnouncementsEnabled
        quietHoursEnabled = plan.quietHoursEnabled
        flirtyRemindersEnabled = plan.flirtyRemindersEnabled
        codexCompletionAnnouncementsEnabled = plan.codexCompletionAnnouncementsEnabled
        usePetName = plan.usePetName
        randomOutfitsEnabled = plan.randomOutfitsEnabled
        localContentPacksEnabled = plan.localContentPacksEnabled
        gestureDiscovery.replaceLearnedIDs(plan.learnedGestureIDs)
        evaluateReminderSchedule()
        return plan.repairs
    }

    func copyPrivacyMinimalDiagnosticReport() {
        let qualityCounts = Dictionary(grouping: contentPackSummaries, by: \CompanionContentPackSummary.qualityLevel).mapValues(\.count)
        let info = Bundle.main.infoDictionary ?? [:]
        let report = CompanionDiagnosticSnapshot(
            generatedAt: Date(),
            appVersion: info["CFBundleShortVersionString"] as? String ?? "development",
            buildNumber: info["CFBundleVersion"] as? String ?? "local",
            buildIdentity: info["ChengyinBuildIdentity"] as? String ?? "development-build",
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: Self.runtimeArchitecture,
            localeIdentifier: Self.preferredContentLocale,
            displayMode: displayMode.rawValue,
            presentationAppearance: presentationAppearance.rawValue,
            displayTargetMode: displayTarget.mode.rawValue,
            playbackMode: playbackMode.rawValue,
            reducedDynamicEffectsEnabled: reducedDynamicEffectsEnabled,
            relationshipTone: relationshipTone.rawValue,
            remindersEnabled: remindersEnabled,
            careCadence: careCadence.rawValue,
            careMemoryRecoverySource: lifestyleRuntime.recoverySource.rawValue,
            workdayRecoverySource: workdayRuntime.recoverySource.rawValue,
            quietHoursEnabled: quietHoursEnabled,
            codexCompletionAnnouncementsEnabled: codexCompletionAnnouncementsEnabled,
            eventBridgeStatusCode: workdayRuntime.eventBridgeCode,
            enabledContentPackCount: installedContentPackCount,
            localContentPacksEnabled: localContentPacksEnabled,
            labPackCount: qualityCounts[.lab, default: 0],
            stablePackCount: qualityCounts[.stable, default: 0],
            verifiedPackCount: qualityCounts[.verified, default: 0],
            bundledVideoCount: runtimeSupportSnapshot.facts.bundledVideoCount,
            voiceLineCount: runtimeSupportSnapshot.facts.declaredVoiceLineCount,
            playbackHealth: CompanionPlaybackHealthMonitor.shared.snapshot,
            microphoneUsageDeclared: runtimeSupportSnapshot.facts.microphoneUsageDeclared
        ).markdown()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if pasteboard.setString(report, forType: .string) {
            diagnosticOperationMessage = CompanionLocalization.string(
                key: "diagnostic.copied",
                fallback: "隐私最小诊断已复制，可在检查后粘贴到 Issue。"
            )
        } else {
            diagnosticOperationMessage = CompanionLocalization.string(
                key: "diagnostic.copyFailed",
                fallback: "诊断报告未能写入剪贴板。"
            )
        }
    }

    func refreshRuntimeReadiness() {
        runtimeRepair.refresh(
            workdayRuntime: workdayRuntime,
            voiceFileNames: voiceSelection.audioFileNames,
            localContentPacksEnabled: localContentPacksEnabled
        )
    }

    func repairRuntimeReadiness() {
        runtimeRepair.repair(
            workdayRuntime: workdayRuntime,
            contentOperations: contentOperations,
            voiceFileNames: voiceSelection.audioFileNames,
            localContentPacksEnabled: localContentPacksEnabled,
            applyInventory: { [weak self] inventory in
                guard let self else { return }
                self.contentLibraryRuntime.replaceInventory(
                    inventory,
                    enabled: self.localContentPacksEnabled
                )
            },
            setContentHealth: { [weak self] message in
                guard let self else { return }
                self.contentLibraryRuntime.setHealth(
                    message,
                    enabled: self.localContentPacksEnabled
                )
            }
        )
    }

    private func rebuildRuntimeReadiness() {
        runtimeRepair.rebuild(
            voiceFileNames: voiceSelection.audioFileNames,
            eventBridgeReady: workdayRuntime.eventBridgeReady,
            localContentPacksEnabled: localContentPacksEnabled
        )
    }

    private static var runtimeArchitecture: String {
#if arch(arm64)
        "arm64"
#elseif arch(x86_64)
        "x86_64"
#else
        "unknown"
#endif
    }

    func reportContentPlaybackReady(_ asset: CompanionVideoAsset) {
        rememberPlayedContentAsset(asset)
        reportContentPlayback(asset, succeeded: true)
    }

    func reportContentPlaybackFailure(_ asset: CompanionVideoAsset) {
        reportContentPlayback(asset, succeeded: false)
    }

    func reportContentSequenceCompleted(_ sequence: CompanionVideoSequence) {
        guard case let .completed(fallback) = contentSequenceRuntime.finish(
            sequenceID: sequence.id,
            succeeded: true
        ) else { return }
        experienceRuntime.cancelPresentation()
        rememberPlayedContentIdentifier(sequence.id)
        reportContentPlayback(
            reference: sequence.packReference,
            succeeded: true
        )

        let opensCompletionReplyWindow: Bool
        if case let .event(kind, _, _, _) = fallback {
            opensCompletionReplyWindow = kind == .taskComplete
        } else {
            opensCompletionReplyWindow = false
        }
        finishEvent(
            opensCompletionReplyWindow: opensCompletionReplyWindow
        )
    }

    func reportContentSequenceFailure(_ sequence: CompanionVideoSequence) {
        guard case let .failed(fallback) = contentSequenceRuntime.finish(
            sequenceID: sequence.id,
            succeeded: false
        ) else { return }
        experienceRuntime.cancelPresentation()
        reportContentPlayback(
            reference: sequence.packReference,
            succeeded: false
        )
        finishEvent(continuesIntoFallback: fallback != nil)

        experienceRuntime.scheduleHandoff(
            after: 0.18,
            isValid: { fallback != nil },
            onReady: { [weak self] in
                guard let self, let fallback else { return }
                switch fallback {
                case let .event(kind, context, preferredVoiceLineID, source):
                    _ = self.triggerEvent(
                        kind,
                        priority: true,
                        completionContext: context,
                        preferredVoiceLineID: preferredVoiceLineID,
                        source: source,
                        allowsContentExperience: false,
                        bypassesExperienceDirector: true
                    )
                case let .action(action, presentationIntent):
                    self.playAction(
                        action,
                        presentationIntent: presentationIntent,
                        allowsContentExperience: false
                    )
                case let .scene(scene, presentationIntent):
                    self.playScene(
                        scene,
                        presentationIntent: presentationIntent,
                        allowsContentExperience: false
                    )
                case let .miniScene(scene, presentationIntent):
                    self.playMiniScene(
                        scene,
                        presentationIntent: presentationIntent,
                        allowsContentExperience: false
                    )
                case let .workdayCue(cue):
                    self.presentBuiltInWorkdayCue(cue)
                }
            }
        )
    }

    var isPresentingMedia: Bool {
        activeContentSequence != nil
            || eventAction != nil
            || activeScene != nil
            || activeMiniScene != nil
    }

    private func prepareForMicrogame(stoppingEffects: Bool = false) {
        experienceRuntime.cancelPresentation()
        contentSequenceRuntime.cancelActive()
        speaker.stop()
        interactionSpeaker.stop()
        if stoppingEffects {
            effectSpeaker.stop()
        }
        activeScene = nil
        activeMiniScene = nil
        eventAction = nil
        activeEventKind = nil
        activeEventText = nil
    }

    func toggleCatchGame() {
        if catchGameActive {
            stopCatchGame()
        } else {
            startCatchGame()
        }
    }

    func startCatchGame() {
        guard petInteractionsEnabled,
              !petGameActive,
              microgameRuntime.begin(
                .catchPet,
                returnMode: displayMode.presentationMode,
                windowOrigin: activePetWindow?.frame.origin
              )
        else { return }

        prepareForMicrogame()
        petMood = .playful
        status = companionText(
            "status.game.catch.started",
            "小游戏：20 秒抓住澄音 5 次"
        )
        showPetEffect(
            symbol: "hand.tap.fill",
            text: companionText("effect.game.catch.invite", "20 秒，来抓我 5 次")
        )
        setTemporaryDisplayMode(.head)
        playInteractionCue(.petGameStart, bypassCooldown: true)

        microgameRuntime.startCountdown(
            initialActionDelay: 0.36,
            onInitialAction: { [weak self] in
                guard let self, self.catchGameActive else { return }
                self.movePetForCatchGame()
            },
            onExpired: { [weak self] game in
                guard game == .catchPet else { return }
                self?.finishCatchGame(won: false)
            }
        )
    }

    func stopCatchGame(
        restorePreviousMode: Bool = true,
        announce: Bool = true
    ) {
        guard catchGameActive else { return }
        finishCatchGame(
            won: false,
            restorePreviousMode: restorePreviousMode,
            announce: announce
        )
    }

    func toggleHideGame() {
        if hideGameActive {
            stopHideGame()
        } else {
            startHideGame()
        }
    }

    func startHideGame() {
        guard petInteractionsEnabled,
              !petGameActive,
              microgameRuntime.begin(
                .hideAndSeek,
                returnMode: displayMode.presentationMode,
                windowOrigin: activePetWindow?.frame.origin
              )
        else { return }

        prepareForMicrogame()
        hideGameLastEdge = nil
        petMood = .playful
        status = companionText(
            "status.game.hide.started",
            "小游戏：去屏幕边缘找澄音"
        )
        showPetEffect(
            symbol: "eye.fill",
            text: companionText("effect.game.hide.invite", "我只露出一点点哦")
        )
        setTemporaryDisplayMode(.head)
        playInteractionCue(.petHideStart, bypassCooldown: true)

        microgameRuntime.startCountdown(
            initialActionDelay: 0.42,
            onInitialAction: { [weak self] in
                guard let self, self.hideGameActive else { return }
                self.movePetForHideGame()
            },
            onExpired: { [weak self] game in
                guard game == .hideAndSeek else { return }
                self?.finishHideGame(won: false)
            }
        )
    }

    func stopHideGame(
        restorePreviousMode: Bool = true,
        announce: Bool = true
    ) {
        guard hideGameActive else { return }
        finishHideGame(
            won: false,
            restorePreviousMode: restorePreviousMode,
            announce: announce
        )
    }

    func toggleComboGame() {
        if comboGameActive {
            stopComboGame()
        } else {
            startComboGame()
        }
    }

    func startComboGame() {
        guard petInteractionsEnabled,
              !petGameActive,
              microgameRuntime.begin(
                .gestureCombo,
                returnMode: displayMode.presentationMode,
                windowOrigin: activePetWindow?.frame.origin
              )
        else { return }

        prepareForMicrogame()
        comboLongPressArmed = false
        directInteractionActive = false
        petMood = .playful
        status = companionText(
            "status.game.combo.started",
            "小游戏：轻点、长按、甩动"
        )
        setTemporaryDisplayMode(.head)
        playInteractionCue(.petComboStart, bypassCooldown: true)

        microgameRuntime.startCountdown { [weak self] game in
            guard game == .gestureCombo else { return }
            self?.finishComboGame(won: false)
        }
    }

    func stopComboGame(
        restorePreviousMode: Bool = true,
        announce: Bool = true
    ) {
        guard comboGameActive else { return }
        finishComboGame(
            won: false,
            restorePreviousMode: restorePreviousMode,
            announce: announce
        )
    }

    func toggleHeartTraceGame() {
        if heartTraceGameActive {
            stopHeartTraceGame()
        } else {
            startHeartTraceGame()
        }
    }

    func startHeartTraceGame() {
        guard petInteractionsEnabled,
              !petGameActive,
              microgameRuntime.begin(
                .heartTrace,
                returnMode: displayMode.presentationMode
              )
        else { return }

        prepareForMicrogame()
        suppressNextHeartTraceDragEnd = false
        directInteractionActive = false
        petMood = .affectionate
        status = companionText(
            "status.game.heart.started",
            "小游戏：按住发光点画一颗心"
        )
        setTemporaryDisplayMode(.compact)
        playInteractionCue(.petTraceStart, bypassCooldown: true)

        microgameRuntime.startCountdown { [weak self] game in
            guard game == .heartTrace else { return }
            self?.finishHeartTraceGame(won: false)
        }
    }

    func stopHeartTraceGame(
        restorePreviousMode: Bool = true,
        announce: Bool = true
    ) {
        guard heartTraceGameActive else { return }
        finishHeartTraceGame(
            won: false,
            restorePreviousMode: restorePreviousMode,
            announce: announce
        )
    }

    func toggleRhythmGame() {
        if rhythmGameActive {
            stopRhythmGame()
        } else {
            startRhythmGame()
        }
    }

    func startRhythmGame() {
        guard petInteractionsEnabled,
              !petGameActive,
              microgameRuntime.begin(
                .rhythm,
                returnMode: displayMode.presentationMode
              )
        else { return }

        prepareForMicrogame(stoppingEffects: true)
        lastRhythmMissCueAt = .distantPast
        directInteractionActive = false
        petMood = .playful
        status = companionText(
            "status.game.rhythm.started",
            "小游戏：跟着心跳轻点澄音"
        )
        setTemporaryDisplayMode(.head)
        let introDuration = playInteractionCue(
            .petRhythmStart,
            bypassCooldown: true
        )

        microgameRuntime.startRhythmTimeline(
            introDuration: introDuration,
            onBeatOpened: { [weak self] _ in
                self?.effectSpeaker.play(fileName: "heart-thump.wav")
            },
            onFinished: { [weak self] won in
                self?.finishRhythmGame(won: won)
            }
        )
    }

    func stopRhythmGame(
        restorePreviousMode: Bool = true,
        announce: Bool = true
    ) {
        guard rhythmGameActive else { return }
        finishRhythmGame(
            won: false,
            restorePreviousMode: restorePreviousMode,
            announce: announce
        )
    }

    func toggleFeedGame() {
        if feedGameActive {
            stopFeedGame()
        } else {
            startFeedGame()
        }
    }

    func startFeedGame() {
        guard petInteractionsEnabled,
              !petGameActive,
              microgameRuntime.begin(
                .feed,
                returnMode: displayMode.presentationMode
              )
        else { return }

        prepareForMicrogame()
        feedGameTreat = CompanionTreat.allCases.randomElement() ?? .strawberry
        feedGameRound += 1
        lastFeedMissCueAt = .distantPast
        directInteractionActive = false
        petMood = .affectionate
        status = companionText(
            "status.game.feed.started",
            "小游戏：把点心拖到澄音怀里"
        )
        setTemporaryDisplayMode(.compact)
        playInteractionCue(.petFeedStart, bypassCooldown: true)

        microgameRuntime.startCountdown { [weak self] game in
            guard game == .feed else { return }
            self?.finishFeedGame(won: false)
        }
    }

    func registerFeedDrop(succeeded: Bool) {
        guard feedGameActive else { return }

        guard succeeded else {
            petMood = .curious
            status = companionText(
                "status.game.feed.nearer",
                "再靠近一点，送到发光的爱心里"
            )
            NSHapticFeedbackManager.defaultPerformer.perform(
                .levelChange,
                performanceTime: .now
            )
            let now = Date()
            if now.timeIntervalSince(lastFeedMissCueAt) >= 2.1 {
                lastFeedMissCueAt = now
                playInteractionCue(.petFeedMiss, bypassCooldown: true)
            }
            return
        }

        let outcome = microgameRuntime.registerFeedSuccess()
        petMood = .affectionate
        status = companionFormat(
            "status.game.feed.score",
            "投喂成功 %d/3",
            feedGameScore
        )
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )

        if outcome == .completed {
            finishFeedGame(won: true)
            return
        }

        playInteractionCue(.petFeedBite, bypassCooldown: true)
        let alternatives = CompanionTreat.allCases.filter { $0 != feedGameTreat }
        feedGameTreat = alternatives.randomElement() ?? .cake
        feedGameRound += 1
    }

    func stopFeedGame(
        restorePreviousMode: Bool = true,
        announce: Bool = true
    ) {
        guard feedGameActive else { return }
        finishFeedGame(
            won: false,
            restorePreviousMode: restorePreviousMode,
            announce: announce
        )
    }

    func handlePetSingleClick(at date: Date = Date()) {
        guard petInteractionsEnabled else { return }
        noteUserInitiatedExperience(at: date)
        markGestureLearned(.singleTap)
        if registerRhythmTap(at: date) {
            return
        }
        if heartTraceGameActive {
            resetHeartTraceAttempt(announce: true)
            return
        }
        if registerComboGesture(.tap) {
            return
        }
        if registerHideGameHit() {
            return
        }
        if registerCatchGameHit() {
            return
        }
        if consumeCompletionReply(.singleTap) {
            return
        }
        _ = firstSessionRuntime.recordSingleTap()
        recordRelationshipMoment("interaction.single-tap")
        let moment = directedPetMoment(
            for: .singleTap,
            at: date
        ) ?? .action(.cheer)
        playPetMoment(moment, presentationIntent: .petInteraction)
    }

    func handlePetDoubleClick(at date: Date = Date()) {
        guard petInteractionsEnabled else { return }
        noteUserInitiatedExperience(at: date)
        markGestureLearned(.doubleTap)
        if registerRhythmTap(at: date) {
            return
        }
        if heartTraceGameActive {
            resetHeartTraceAttempt(announce: true)
            return
        }
        if registerComboGesture(.other) {
            return
        }
        if registerHideGameHit() {
            return
        }
        if registerCatchGameHit() {
            return
        }
        if consumeCompletionReply(.doubleTap) {
            return
        }
        _ = firstSessionRuntime.recordDoubleTap()
        if deliverGuaranteedSurpriseIfNeeded(at: date) {
            return
        }
        recordRelationshipMoment("interaction.double-tap")
        playPetMoment(
            directedPetMoment(for: .doubleTap, at: date) ?? .miniScene(.workout),
            presentationIntent: .petInteraction
        )
    }

    func handlePetHover(
        isInside: Bool,
        normalizedPoint: CGPoint = .zero
    ) {
        guard petInteractionsEnabled, !directInteractionActive else { return }
        if isInside {
            petMood = .curious
            updateGaze(normalizedPoint)
            scheduleGestureCoachIfNeeded()
        } else {
            gestureDiscovery.cancelPendingLesson()
            schedulePoseReset(after: 0.18)
            scheduleMoodReset(after: 0.75)
        }
    }

    func handlePetPointerMove(_ normalizedPoint: CGPoint) {
        guard petInteractionsEnabled, !directInteractionActive else { return }
        petMood = .curious
        updateGaze(normalizedPoint)
    }

    func handlePetPressChanged(_ isPressed: Bool) {
        guard petInteractionsEnabled else { return }
        feedbackRuntime.cancelPoseReset()
        if isPressed {
            feedbackRuntime.updatePose {
                $0.scale = 0.965
                $0.y = -1
            }
            petMood = .curious
        } else if !directInteractionActive {
            schedulePoseReset(after: 0.12)
        }
    }

    func handlePetLongPressBegan() {
        guard petInteractionsEnabled else { return }
        markGestureLearned(.longPress)
        if rhythmGameActive {
            registerRhythmMiss()
            return
        }
        if heartTraceGameActive {
            resetHeartTraceAttempt(announce: true)
            return
        }
        if comboGameActive {
            comboLongPressArmed = true
            beginDirectInteraction()
            petMood = .affectionate
            petPose = PetPose(x: 0, y: 3, rotation: -2.2, scale: 1.075)
            return
        }
        if registerHideGameHit() {
            return
        }
        if registerCatchGameHit() {
            return
        }
        beginDirectInteraction()
        petMood = .affectionate
        petPose = PetPose(x: 0, y: 3, rotation: -2.2, scale: 1.075)
        showPetEffect(
            symbol: "heart.fill",
            text: companionText("effect.pet.hold", "再摸一会儿")
        )
        playInteractionCue(.petHold, bypassCooldown: true)
    }

    func handlePetLongPressEnded() {
        if comboGameActive, comboLongPressArmed {
            comboLongPressArmed = false
            directInteractionActive = false
            petPose = PetPose(x: 0, y: 0, rotation: 2.4, scale: 1.035)
            schedulePoseReset(after: 0.45)
            _ = registerComboGesture(.hold)
            return
        }
        guard petInteractionsEnabled, directInteractionActive else { return }
        let wasCompletionReply = isCompletionReplyWindowOpen
        directInteractionActive = false
        interactionSpeaker.stop()
        petMood = .affectionate
        petPose = PetPose(x: 0, y: 0, rotation: 2.4, scale: 1.035)
        showPetEffect(
            symbol: "sparkles",
            text: companionText("effect.pet.happy", "被你哄开心了")
        )
        schedulePoseReset(after: 0.45)
        scheduleMoodReset(after: 2.4)
        let completionReply = wasCompletionReply
            ? applyCompletionReply(.longPress)
            : nil

        if playbackMode == .audioVisual {
            if !wasCompletionReply {
                recordRelationshipMoment("interaction.long-press")
            }
            let releaseAction = completionReply?.action
                ?? relationshipTone.longPressActions.randomElement()
                ?? .heart
            playAction(releaseAction, presentationIntent: .petInteraction)
            petMood = .affectionate
            return
        }

        if !wasCompletionReply {
            recordRelationshipMoment("interaction.long-press")
        }
        playInteractionCue(.petNudge, bypassCooldown: true)
        resumePendingEventsAfterInteraction()
    }

    func handlePetDragChanged(
        translation: CGSize,
        movingWindow: Bool,
        normalizedPoint: CGPoint
    ) {
        guard petInteractionsEnabled,
              !catchGameActive,
              !hideGameActive
        else { return }
        if hypot(translation.width, translation.height) >= 12 {
            markGestureLearned(.drag)
        }
        if suppressNextHeartTraceDragEnd {
            return
        }
        beginDirectInteraction()
        petMood = .playful

        if heartTraceGameActive {
            petPose = PetPose(
                x: max(-8, min(8, translation.width * 0.04)),
                y: max(-5, min(5, translation.height * 0.03)),
                rotation: max(-4, min(4, translation.width * 0.018)),
                scale: 1.018
            )
            registerHeartTracePoint(normalizedPoint)
            return
        }
        if rhythmGameActive {
            petPose = PetPose(
                x: max(-6, min(6, translation.width * 0.04)),
                y: 0,
                rotation: max(-4, min(4, translation.width * 0.02)),
                scale: 1.015
            )
            return
        }

        if movingWindow, !gestureMoveCuePlayed {
            gestureMoveCuePlayed = true
            playInteractionCue(.petPickup, bypassCooldown: true)
        }

        let cappedX = max(-52, min(52, translation.width * 0.22))
        let cappedY = max(-34, min(34, translation.height * 0.18))
        petPose = PetPose(
            x: movingWindow ? cappedX * 0.22 : cappedX,
            y: movingWindow ? 7 : cappedY,
            rotation: max(-9, min(9, translation.width * 0.075)),
            scale: movingWindow ? 1.07 : 1.025
        )
    }

    func handlePetDragEnded(
        translation: CGSize,
        velocity: CGSize,
        dockEdge: PetDockEdge?
    ) {
        guard petInteractionsEnabled,
              !catchGameActive,
              !hideGameActive
        else { return }
        directInteractionActive = false

        if suppressNextHeartTraceDragEnd {
            suppressNextHeartTraceDragEnd = false
            gestureMoveCuePlayed = false
            return
        }
        if heartTraceGameActive {
            gestureMoveCuePlayed = false
            schedulePoseReset(after: 0.2)
            resetHeartTraceAttempt(announce: true)
            return
        }
        if rhythmGameActive {
            gestureMoveCuePlayed = false
            schedulePoseReset(after: 0.2)
            registerRhythmMiss()
            return
        }

        let speed = hypot(velocity.width, velocity.height)
        if comboGameActive {
            gestureMoveCuePlayed = false
            petPose = PetPose(
                x: max(-12, min(12, velocity.width * 0.012)),
                y: 2,
                rotation: velocity.width >= 0 ? 13 : -13,
                scale: 1.045
            )
            schedulePoseReset(after: 0.55)
            _ = registerComboGesture(speed > 900 ? .fling : .other)
            return
        }
        let movedWindow = gestureMoveCuePlayed
            || hypot(translation.width, translation.height) > 24
        if movedWindow, consumeCompletionReply(.drag) {
            gestureMoveCuePlayed = false
            schedulePoseReset(after: 0.35)
            return
        }
        let dragPlan = CompanionPetDragPolicy.plan(
            for: CompanionPetDragInput(
                translationX: Double(translation.width),
                translationY: Double(translation.height),
                velocityX: Double(velocity.width),
                velocityY: Double(velocity.height),
                windowMoveObserved: gestureMoveCuePlayed,
                dockEdge: dockEdge
            )
        )
        let presentation = CompanionPetDragPresentation.presentation(for: dragPlan)
        petMood = presentation.mood
        petPose = presentation.pose
        showPetEffect(
            symbol: presentation.effectSymbol,
            text: presentation.effectText
        )
        let feedbackDuration = playInteractionCue(
            presentation.cue,
            bypassCooldown: true
        )
        recordRelationshipMoment(dragPlan.relationshipMomentKey)
        gestureMoveCuePlayed = false
        schedulePoseReset(after: dragPlan.poseResetDelay)
        scheduleMoodReset(after: 2.8)
        resumePendingEventsAfterInteraction(
            after: max(feedbackDuration + 0.15, 0.9)
        )
    }

    func playAction(
        _ action: CompanionAction,
        presentationIntent: CompanionUserPresentationIntent = .magicWand,
        allowsContentExperience: Bool = true
    ) {
        resetContentSelection()
        experienceRuntime.cancelPresentation()
        contentSequenceRuntime.cancelActive()
        speaker.stop()
        interactionSpeaker.stop()
        activeScene = nil
        activeMiniScene = nil
        keepsMediaInHead = false

        if playbackMode == .audioVisual,
           allowsContentExperience,
           beginContentSequenceIfAvailable(
                triggers: ["manual:action.\(action.contentAssetID)"],
                fallback: .action(
                    action,
                    presentationIntent: presentationIntent
                ),
                eventKind: nil,
                presentationStatus: companionFormat(
                    "status.play.action",
                    "澄音陪你玩：%@",
                    action.label
                ),
                presentationPlan: userPresentationPlan(for: presentationIntent)
           ) {
            return
        }

        if randomOutfitsEnabled {
            let alternatives = CompanionOutfit.allCases.filter { $0 != outfit }
            outfit = alternatives.randomElement() ?? outfit
        }
        activeEventKind = nil
        if playbackMode == .audioOnly {
            let line = voiceSelection.selectAction(
                action,
                addressedEnabled: addressedVoiceEnabled
            )
            activeEventText = line?.text ?? action.playfulCaption
            eventAction = nil
            petMood = .playful
            status = companionFormat(
                "status.audioOnly.action",
                "仅声音：%@",
                action.label
            )
            let duration = line.map { speaker.play(fileName: $0.audioFile) } ?? 0
            scheduleEventFinish(after: max(duration + 0.6, 2.8))
            return
        }
        applyUserPresentationPlan(userPresentationPlan(for: presentationIntent))
        activeEventText = action.nativeLine
        eventAction = action
        isSpeaking = true
        petMood = .playful
        status = companionFormat(
            "status.play.action",
            "澄音陪你玩：%@",
            action.label
        )
        scheduleEventFinish(after: 4.18)
    }

    func playScene(
        _ scene: CompanionScene,
        presentationIntent: CompanionUserPresentationIntent = .magicWand,
        allowsContentExperience: Bool = true
    ) {
        resetContentSelection()
        experienceRuntime.cancelPresentation()
        contentSequenceRuntime.cancelActive()
        speaker.stop()
        interactionSpeaker.stop()
        activeMiniScene = nil
        keepsMediaInHead = false

        if playbackMode == .audioVisual,
           allowsContentExperience,
           beginContentSequenceIfAvailable(
                triggers: ["manual:scene.\(scene.rawValue)"],
                fallback: .scene(
                    scene,
                    presentationIntent: presentationIntent
                ),
                eventKind: nil,
                presentationStatus: companionFormat(
                    "status.play.scene",
                    "澄音带你去：%@",
                    scene.label
                ),
                presentationPlan: userPresentationPlan(for: presentationIntent)
           ) {
            return
        }

        let line = voiceSelection.selectEvent(
            scene.voiceEvent,
            addressedEnabled: addressedVoiceEnabled
        )

        if playbackMode == .audioOnly {
            activeScene = nil
            activeMiniScene = nil
            eventAction = nil
            activeEventKind = nil
            activeEventText = line?.text ?? scene.fallbackText
            petMood = .affectionate
            status = companionFormat(
                "status.audioOnly.scene",
                "仅声音：%@",
                scene.label
            )
            let duration = line.map { speaker.play(fileName: $0.audioFile) } ?? 0
            scheduleEventFinish(after: max(duration + 0.6, 2.8))
            return
        }

        applyUserPresentationPlan(userPresentationPlan(for: presentationIntent))
        activeScene = scene
        activeEventKind = nil
        activeEventText = scene.hasNativeAudio
            ? scene.fallbackText
            : (line?.text ?? scene.fallbackText)
        eventAction = nil
        isSpeaking = scene.hasNativeAudio
        petMood = .playful
        status = companionFormat(
            "status.play.scene",
            "澄音带你去：%@",
            scene.label
        )

        let duration = scene.hasNativeAudio
            ? 0
            : (line.map { speaker.play(fileName: $0.audioFile) } ?? 0)
        let visibleDuration = scene.hasNativeAudio
            ? 4.18
            : max(duration + 0.8, 4.2)
        scheduleEventFinish(after: visibleDuration)
    }

    func playMiniScene(
        _ scene: CompanionMiniScene,
        presentationIntent: CompanionUserPresentationIntent = .magicWand,
        allowsContentExperience: Bool = true
    ) {
        resetContentSelection()
        experienceRuntime.cancelPresentation()
        contentSequenceRuntime.cancelActive()
        speaker.stop()
        interactionSpeaker.stop()
        keepsMediaInHead = false

        if playbackMode == .audioVisual,
           allowsContentExperience,
           beginContentSequenceIfAvailable(
                triggers: ["manual:mini.\(scene.rawValue)"],
                fallback: .miniScene(
                    scene,
                    presentationIntent: presentationIntent
                ),
                eventKind: nil,
                presentationStatus: companionFormat(
                    "status.play.miniScene",
                    "澄音的迷你生活：%@",
                    scene.label
                ),
                presentationPlan: userPresentationPlan(for: presentationIntent)
           ) {
            return
        }

        if playbackMode == .audioOnly {
            let line = voiceSelection.selectEvent(
                scene.voiceEvent,
                addressedEnabled: addressedVoiceEnabled
            )
            activeScene = nil
            activeMiniScene = nil
            eventAction = nil
            activeEventKind = nil
            activeEventText = line?.text ?? scene.spokenLine
            petMood = .affectionate
            status = companionFormat(
                "status.audioOnly.miniScene",
                "仅声音：%@",
                scene.label
            )
            let duration = line.map { speaker.play(fileName: $0.audioFile) } ?? 0
            scheduleEventFinish(after: max(duration + 0.6, 2.8))
            return
        }

        activeScene = nil
        eventAction = nil
        activeEventKind = nil
        applyUserPresentationPlan(userPresentationPlan(for: presentationIntent))

        activeMiniScene = scene
        activeEventText = scene.spokenLine
        isSpeaking = true
        petMood = .playful
        status = companionFormat(
            "status.play.miniScene",
            "澄音的迷你生活：%@",
            scene.label
        )

        scheduleEventFinish(after: 4.18)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval {
                launchAtLoginMessage = companionText(
                    "error.loginItem.permission",
                    "请在“系统设置 → 通用 → 登录项”中允许澄音。"
                )
            } else {
                launchAtLoginMessage = nil
            }
        } catch {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            launchAtLoginMessage = error.localizedDescription
        }
    }

    var latestCompanionText: String {
        if feedGameActive {
            return feedGameScore == 0
                ? companionText(
                    "game.feed.dragInstruction",
                    "拿起点心，拖到我怀里的发光爱心再松手。"
                )
                : companionFormat(
                    "game.feed.remainingInstruction",
                    "这一口收到啦，再喂我 %d 口。",
                    3 - feedGameScore
                )
        }
        return activeEventText
            ?? petEffect?.text
            ?? companionText(
                "interaction.default.prompt",
                "单击、双击、长按或拖动她，看看会发生什么。"
            )
    }

    var activeCaption: String {
        if let activeMiniScene {
            return activeMiniScene.label
        }
        if let activeScene {
            return activeScene.label
        }
        if let eventAction {
            return eventAction.label
        }
        return petMood.label
    }

    @discardableResult
    private func triggerEvent(
        _ event: CompanionEventKind,
        priority: Bool = false,
        completionContext: CompanionCompletionContext? = nil,
        preferredVoiceLineID: String? = nil,
        source: CompanionExperienceSource? = nil,
        allowsContentExperience: Bool = true,
        bypassesExperienceDirector: Bool = false
    ) -> Bool {
        let experienceSource = source ?? Self.experienceSource(for: event)
        if !bypassesExperienceDirector {
            let decision = experienceRuntime.decide(
                for: experienceSource,
                context: CompanionExperienceContext(
                    now: Date(),
                    isDirectInteractionActive: directInteractionActive
                        || interactionAudioActive,
                    isGameplayActive: petGameActive,
                    isMediaPlaybackActive: experienceRuntime.isPresentationActive
                        || activeContentSequence != nil
                        || eventAction != nil
                        || activeScene != nil
                        || activeMiniScene != nil,
                    isSpeaking: isSpeaking,
                    isQuietHours: isWithinQuietHours(Date())
                )
            )
            switch decision {
            case .present:
                break
            case .ambientOnly:
                presentAmbientExperience(experienceSource)
                return false
            case .enqueue:
                enqueuePendingEvent(
                    event,
                    completionContext: completionContext,
                    source: experienceSource
                )
                return false
            case .deferUntilNextEvaluation:
                return false
            }
        }

        if directInteractionActive || interactionAudioActive || petGameActive {
            if priority {
                enqueuePendingEvent(
                    event,
                    completionContext: completionContext,
                    source: experienceSource
                )
            }
            return false
        }
        if experienceRuntime.isPresentationActive
            || activeContentSequence != nil
            || eventAction != nil
            || activeScene != nil
            || activeMiniScene != nil {
            if priority {
                enqueuePendingEvent(
                    event,
                    completionContext: completionContext,
                    source: experienceSource
                )
            }
            return false
        }

        if event != .taskComplete, completionReplyWindowActive {
            closeCompletionReplyWindow()
        }
        resetContentSelection()
        if playbackMode == .audioVisual {
            if allowsContentExperience,
               beginContentSequenceIfAvailable(
                    triggers: CompanionEventTriggerRouting.triggers(for: event),
                    fallback: .event(
                        event,
                        completionContext,
                        preferredVoiceLineID,
                        experienceSource
                    ),
                    eventKind: event,
                    presentationStatus: CompanionEventPresentation.status(for: event)
               ) {
                return true
            }
            switch event {
            case .flirt:
                let scenes: [CompanionScene] = relationshipTone.allowsRomanticGestures
                    ? [.lunarOrbit, .timeCafe]
                    : [.timeCafe, .rainPortal]
                playScene(scenes.randomElement() ?? .timeCafe)
                return true
            case .lateNight:
                playScene(.underseaRoom)
                return true
            case .taskComplete:
                playNativeTaskCompletion(context: completionContext)
                return true
            default:
                break
            }
        }

        let line = voiceSelection.selectEvent(
            event,
            addressedEnabled: addressedVoiceEnabled,
            preferredID: preferredVoiceLineID
        )
        guard let line else {
            lastError = companionFormat(
                "error.voice.eventMissing",
                "语音包中没有 %@ 提示。",
                event.rawValue
            )
            return false
        }

        if randomOutfitsEnabled {
            let alternatives = CompanionOutfit.allCases.filter { $0 != outfit }
            outfit = alternatives.randomElement() ?? outfit
        }

        activeEventText = line.text
        activeEventKind = event
        if event == .taskComplete {
            codexVisualState = .completed
        }
        if playbackMode == .audioOnly {
            eventAction = nil
            petMood = event == .taskComplete ? .celebrating : .affectionate
            status = companionFormat(
                "status.audioOnly.event",
                "仅声音：%@",
                CompanionEventPresentation.status(for: event)
            )
            let duration = speaker.play(fileName: line.audioFile)
            scheduleEventFinish(
                after: max(duration + 0.6, 2.8),
                opensCompletionReplyWindow: event == .taskComplete
            )
            return true
        }
        let presentationDirective = presentationRuntime.beginAutomaticResponse(
            currentMode: displayMode.presentationMode
        )
        applyPresentationDirective(presentationDirective)
        eventAction = line.action
        petMood = event == .taskComplete ? .celebrating : .affectionate
        status = CompanionEventPresentation.status(for: event)

        let duration = speaker.play(fileName: line.audioFile)
        let visibleDuration = max(duration + 1.4, 5.2)
        scheduleEventFinish(after: visibleDuration)
        return true
    }

    func playNativeTaskCompletion(
        context: CompanionCompletionContext?
    ) {
        resetContentSelection()
        experienceRuntime.cancelPresentation()
        speaker.stop()
        activeScene = nil
        activeMiniScene = nil
        keepsMediaInHead = false

        let presentationDirective = presentationRuntime.beginAutomaticResponse(
            currentMode: displayMode.presentationMode
        )
        applyPresentationDirective(presentationDirective)

        let tier = context?.tier ?? .warm
        activeEventKind = .taskComplete
        codexVisualState = .completed
        let completionPresentation = CompanionTaskCompletionPresentation.celebration(
            tier: tier,
            context: context,
            addressed: addressedVoiceEnabled,
            allowsRomanticGestures: relationshipTone.allowsRomanticGestures,
            variation: UInt64.random(in: UInt64.min...UInt64.max)
        )
        activeEventText = completionPresentation.text
        eventAction = completionPresentation.action
        isSpeaking = true
        petMood = .celebrating
        status = CompanionEventPresentation.status(for: .taskComplete)
        scheduleEventFinish(
            after: 4.18,
            opensCompletionReplyWindow: true
        )
    }

    private func finishEvent(
        opensCompletionReplyWindow: Bool = false,
        continuesIntoFallback: Bool = false
    ) {
        _ = experienceRuntime.completePresentation()
        contentSequenceRuntime.cancelActive()
        activeScene = nil
        activeMiniScene = nil
        eventAction = nil
        activeEventKind = nil
        activeEventText = nil
        keepsMediaInHead = false
        isSpeaking = false
        if opensCompletionReplyWindow {
            openCompletionReplyWindow()
        }
        if !directInteractionActive {
            petMood = .calm
        }
        if workdayRuntime.hasActiveWork {
            petMood = .focused
            status = companionText(
                "status.codex.progress",
                "Codex 还在工作，澄音安静陪着你"
            )
        } else {
            status = completionReplyWindowActive
                ? companionText(
                    "status.completion.awaitingReply",
                    "澄音等着你的回应"
                )
                : workdayPresenceText
        }
        if let returnMode = presentationRuntime.finish(
            continuesIntoFallback: continuesIntoFallback
        ) {
            setTemporaryDisplayMode(CompanionDisplayMode(returnMode))
        }
        if continuesIntoFallback {
            return
        }
        resumePendingEventsAfterInteraction(after: 0.8)
    }

    private func enqueuePendingEvent(
        _ event: CompanionEventKind,
        completionContext: CompanionCompletionContext?,
        source: CompanionExperienceSource
    ) {
        _ = experienceRuntime.enqueue(
            event: event,
            completionContext: completionContext,
            source: source
        )
    }

    private func presentAmbientExperience(
        _ source: CompanionExperienceSource
    ) {
        guard source == .responseReady,
              !isPresentingMedia,
              !directInteractionActive,
              !petGameActive else {
            return
        }
        petMood = .curious
        status = companionText(
            "status.codex.responseReady",
            "Codex 有新结果，澄音轻轻提醒你"
        )
        showPetEffect(
            symbol: "sparkles",
            text: companionText("effect.codex.newResult", "新结果")
        )
    }

    private static func experienceSource(
        for event: CompanionEventKind
    ) -> CompanionExperienceSource {
        switch event {
        case .taskComplete, .taskFailed:
            .trustedTaskTerminal
        case .replyReady:
            .responseReady
        default:
            .proactiveCare
        }
    }

    private func scheduleEventFinish(
        after duration: TimeInterval,
        opensCompletionReplyWindow: Bool = false
    ) {
        let token = experienceRuntime.beginPresentation()
        experienceRuntime.scheduleFinish(
            for: token,
            after: duration
        ) { [weak self] _ in
            self?.finishEvent(
                opensCompletionReplyWindow: opensCompletionReplyWindow
            )
        }
    }

    func setTemporaryDisplayMode(_ mode: CompanionDisplayMode) {
        suppressDisplayPersistence = true
        displayMode = mode
        suppressDisplayPersistence = false
    }

    private func userPresentationPlan(
        for intent: CompanionUserPresentationIntent
    ) -> CompanionUserPresentationPlan {
        presentationRuntime.plan(
            for: intent,
            currentMode: displayMode.presentationMode,
            audiovisualEnabled: playbackMode == .audioVisual
        )
    }

    @discardableResult
    private func applyUserPresentationPlan(
        _ plan: CompanionUserPresentationPlan
    ) -> Bool {
        let directive = presentationRuntime.beginDirectUserPlan(plan)
        applyPresentationDirective(directive)
        return directive.directUserOwnsReturn
    }

    func applyPresentationDirective(
        _ directive: CompanionPresentationDirective
    ) {
        keepsMediaInHead = directive.keepsMediaInPet
        guard let targetMode = directive.targetMode else { return }
        setTemporaryDisplayMode(CompanionDisplayMode(targetMode))
    }

    private var addressedVoiceEnabled: Bool {
        usePetName && relationshipTone.allowsRomanticGestures
    }

    private var isCompletionReplyWindowOpen: Bool {
        workdayRuntime.isCompletionReplyWindowOpen()
    }

    func updateRelationshipState(
        _ transform: (inout CompanionRelationshipStateV1) throws -> Void
    ) {
        do {
            try relationshipRuntime.update(transform)
        } catch {
            lastError = companionFormat(
                "error.memory.save",
                "共同记忆暂时无法保存：%@",
                error.localizedDescription
            )
        }
    }

    private func recordRelationshipMoment(
        _ key: String,
        bond: UInt64 = 1,
        chemistry: Int = 1,
        mementoID: String? = nil,
        advanceSurprise: Bool = true,
        cooldown: TimeInterval = 18
    ) {
        do {
            try relationshipRuntime.recordMoment(
                key,
                bond: bond,
                chemistry: chemistry,
                mementoID: mementoID,
                advanceSurprise: advanceSurprise,
                cooldown: cooldown
            )
        } catch {
            lastError = companionFormat(
                "error.memory.save",
                "共同记忆暂时无法保存：%@",
                error.localizedDescription
            )
        }
    }

    private func unlockMemento(_ id: String) {
        do {
            try relationshipRuntime.unlockMemento(id)
        } catch {
            lastError = companionFormat(
                "error.memory.save",
                "共同记忆暂时无法保存：%@",
                error.localizedDescription
            )
        }
    }

    private func deliverGuaranteedSurpriseIfNeeded(at date: Date) -> Bool {
        guard relationshipState.isSurpriseGuaranteed,
              !experienceRuntime.isPresentationActive,
              !isPresentingMedia,
              !directInteractionActive else {
            return false
        }

        updateRelationshipState { state in
            state.consumeDeliveredSurprise()
            state.recordPositiveMoment(2)
            _ = state.increaseChemistry(by: 1)
            _ = try state.unlockMemento("surprise.shared-scene.001")
        }

        let hour = Calendar.current.component(.hour, from: date)
        let candidates = CompanionDirectSurprisePolicy().candidates(
            daypart: CompanionDaypart(hour: hour),
            relationshipTone: relationshipTone
        )
        let directed = candidates.randomElement() ?? .rainPortal
        playPetMoment(
            PetMoment(directed),
            presentationIntent: .petInteraction
        )
        return true
    }

    private func openCompletionReplyWindow() {
        codexVisualState = .awaitingReply
        workdayRuntime.openCompletionReplyWindow(
            for: Self.completionReplyDuration
        ) { [weak self] in
            self?.restorePresenceAfterCompletionReply()
        }
    }

    private func closeCompletionReplyWindow() {
        workdayRuntime.closeCompletionReplyWindow()
        restorePresenceAfterCompletionReply()
    }

    private func restorePresenceAfterCompletionReply() {
        codexVisualState = workdayRuntime.hasActiveWork ? .working : .idle
        if !workdayRuntime.hasActiveWork,
           !isPresentingMedia,
           !directInteractionActive {
            status = workdayPresenceText
        }
    }

    var workdayPresenceText: String {
        workdayState.completedCount > 0
            ? CompanionCopy.workdayPresence(
                completedCount: workdayState.completedCount
            )
            : companionText("status.presence", "澄音陪着你")
    }

    @discardableResult
    private func consumeCompletionReply(
        _ gesture: CompanionCompletionReplyGesture
    ) -> Bool {
        guard isCompletionReplyWindowOpen else {
            if completionReplyWindowActive {
                closeCompletionReplyWindow()
            }
            return false
        }

        let presentation = applyCompletionReply(gesture)
        playAction(presentation.action)
        return true
    }

    private func applyCompletionReply(
        _ gesture: CompanionCompletionReplyGesture
    ) -> CompanionTaskCompletionPresentation {
        closeCompletionReplyWindow()
        let plan = CompanionTaskCompletionPolicy.reply(
            to: gesture,
            allowsRomanticGestures: relationshipTone.allowsRomanticGestures
        )
        recordRelationshipMoment(
            plan.relationshipKey,
            bond: plan.bond,
            chemistry: plan.chemistry,
            cooldown: 0
        )
        return CompanionTaskCompletionPresentation.reply(
            to: gesture,
            allowsRomanticGestures: relationshipTone.allowsRomanticGestures
        )
    }

    private func selectContentPackVideo(
        key: String,
        triggers: [String]
    ) -> CompanionVideoAsset? {
        contentSequenceRuntime.selectVideo(
            key: key,
            triggers: triggers,
            catalog: contentPackCatalog,
            preferredLocale: Self.preferredContentLocale,
            context: relationshipRuntime.contentSelectionContext()
        )
    }

    @discardableResult
    private func beginContentSequenceIfAvailable(
        triggers: [String],
        fallback: ContentSequenceFallback,
        eventKind: CompanionEventKind?,
        presentationStatus: String,
        presentationPlan: CompanionUserPresentationPlan? = nil
    ) -> Bool {
        guard let sequence = contentSequenceRuntime.selectAndBegin(
            triggers: triggers,
            catalog: contentPackCatalog,
            preferredLocale: Self.preferredContentLocale,
            context: relationshipRuntime.contentSelectionContext(),
            fallback: fallback
        ) else {
            return false
        }
        experienceRuntime.cancelPresentation()
        speaker.stop()
        interactionSpeaker.stop()
        activeScene = nil
        activeMiniScene = nil
        eventAction = nil
        activeEventKind = eventKind
        activeEventText = nil
        keepsMediaInHead = false
        isSpeaking = sequence.videos.contains(where: \.hasNativeAudio)
        if eventKind == .taskComplete {
            codexVisualState = .completed
        }
        petMood = eventKind == .taskComplete ? .celebrating : .playful
        status = presentationStatus

        let returnPolicy = CompanionPresentationContentReturnPolicy(
            rawValue: sequence.returnPolicy.rawValue
        ) ?? .previousMode
        let directive = presentationRuntime.beginContentSequence(
            returnPolicy: returnPolicy,
            currentMode: displayMode.presentationMode,
            directPlan: presentationPlan
        )
        applyPresentationDirective(directive)

        // The caller-owned return plan must survive arbitrary pack return
        // policies so direct play always comes back to the user's chosen mode.

        // End notifications are the primary completion signal. This watchdog
        // protects trusted task events if AVFoundation never delivers one.
        let watchdog = min(max(sequence.estimatedDuration + 8, 12), 600)
        let token = experienceRuntime.beginPresentation()
        experienceRuntime.scheduleFinish(
            for: token,
            after: watchdog
        ) { [weak self] _ in
            self?.reportContentSequenceFailure(sequence)
        }
        return true
    }

    private func resetContentSelection() {
        contentSequenceRuntime.resetSelectionCache()
    }

    private func rememberPlayedContentAsset(_ asset: CompanionVideoAsset) {
        rememberPlayedContentIdentifier(asset.id)
    }

    private func rememberPlayedContentIdentifier(_ identifier: String) {
        do {
            try relationshipRuntime.rememberPlayedAsset(identifier)
        } catch {
            lastError = companionFormat(
                "error.memory.save",
                "共同记忆暂时无法保存：%@",
                error.localizedDescription
            )
        }
    }

    private func directedPetMoment(
        for interaction: CompanionDirectedInteraction,
        at date: Date
    ) -> PetMoment? {
        let currentKeys = Set([
            eventAction.map { PetMoment.action($0).key },
            activeScene.map { PetMoment.scene($0).key },
            activeMiniScene.map { PetMoment.miniScene($0).key }
        ].compactMap { $0 })
        return relationshipRuntime.selectPetMoment(
            for: interaction,
            at: date,
            mood: petMood.interactionDirectorMood,
            currentMomentKeys: currentKeys
        )
    }

    var gestureDiscoveryProgressLabel: String {
        companionFormat(
            "gesture.progress",
            "已学会 %d/%d",
            gestureDiscovery.completedCount,
            gestureDiscovery.totalCount
        )
    }

    func resetGestureDiscoveryTips() {
        gestureDiscovery.reset()
        status = companionText(
            "gesture.reset.status",
            "互动提示已经重新开启，缩成头像后把鼠标移过来看看"
        )
    }

    private func markGestureLearned(_ lesson: CompanionGestureLesson) {
        _ = gestureDiscovery.markLearned(lesson)
    }

    private func scheduleGestureCoachIfNeeded() {
        gestureDiscovery.scheduleIfEligible(
            displayMode == .head
                && !petGameActive
                && !isPresentingMedia
                && codexVisualState != .awaitingReply
        )
    }

    private func playPetMoment(
        _ moment: PetMoment,
        presentationIntent: CompanionUserPresentationIntent
    ) {
        switch moment {
        case let .action(action):
            playAction(
                action,
                presentationIntent: presentationIntent
            )
        case let .scene(scene):
            playScene(scene, presentationIntent: presentationIntent)
        case let .miniScene(scene):
            playMiniScene(scene, presentationIntent: presentationIntent)
        }
    }

    private func beginDirectInteraction() {
        feedbackRuntime.cancelPoseReset()
        feedbackRuntime.cancelMoodReset()
        if !directInteractionActive {
            gestureMoveCuePlayed = false
            noteUserInitiatedExperience()
        }
        directInteractionActive = true
    }

    func noteUserInitiatedExperience(at date: Date = Date()) { _ = experienceRuntime.discardPending(source: .proactiveCare); experienceRuntime.noteUserInitiated(at: date) }

    private func registerCatchGameHit() -> Bool {
        guard catchGameActive else { return false }

        let outcome = microgameRuntime.registerCatch(at: Date())
        catchGameBestScore = max(catchGameBestScore, catchGameScore)
        preferenceStore.saveCatchGameBestScore(catchGameBestScore)

        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
        petMood = .playful
        showPetEffect(
            symbol: "sparkles",
            text: companionFormat(
                "effect.game.catch.score",
                "抓到 %d/5 · %d 连击",
                catchGameScore,
                catchGameCombo
            )
        )

        if outcome == .completed {
            finishCatchGame(won: true)
            return true
        }

        playInteractionCue(.petGameCatch, bypassCooldown: true)
        movePetForCatchGame()
        return true
    }

    private func finishCatchGame(
        won: Bool,
        restorePreviousMode: Bool = true,
        announce: Bool = true
    ) {
        finishMicrogame(
            .catchPet,
            won: won,
            restorePreviousMode: restorePreviousMode,
            announce: announce
        )
    }

    private func registerHideGameHit() -> Bool {
        guard hideGameActive else { return false }

        let outcome = microgameRuntime.registerHideFind(at: Date())
        hideGameBestScore = max(hideGameBestScore, hideGameScore)
        preferenceStore.saveHideGameBestScore(hideGameBestScore)

        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
        petMood = .affectionate
        showPetEffect(
            symbol: "eye.fill",
            text: companionFormat(
                "effect.game.hide.score",
                "找到 %d/5 · %d 连击",
                hideGameScore,
                hideGameCombo
            )
        )

        if outcome == .completed {
            finishHideGame(won: true)
            return true
        }

        playInteractionCue(.petHideFound, bypassCooldown: true)
        movePetForHideGame()
        return true
    }

    private func finishHideGame(
        won: Bool,
        restorePreviousMode: Bool = true,
        announce: Bool = true
    ) {
        finishMicrogame(
            .hideAndSeek,
            won: won,
            restorePreviousMode: restorePreviousMode,
            announce: announce
        )
    }

    private func registerComboGesture(_ gesture: CompanionMicrogameGesture) -> Bool {
        guard comboGameActive else { return false }

        let expected: CompanionMicrogameGesture = [.tap, .hold, .fling][
            min(comboGameStep, CompanionMicrogameSession.comboTarget - 1)
        ]
        NSHapticFeedbackManager.defaultPerformer.perform(
            gesture == expected ? .alignment : .levelChange,
            performanceTime: .now
        )

        let outcome = microgameRuntime.registerComboGesture(gesture)
        guard outcome != .reset else {
            comboLongPressArmed = false
            petMood = .curious
            status = companionText(
                "status.game.combo.reset",
                "连招顺序重置：先轻点一下"
            )
            playInteractionCue(.petComboWrong, bypassCooldown: true)
            return true
        }

        petMood = .playful
        if outcome == .completed {
            finishComboGame(won: true)
            return true
        }

        status = comboGameStep == 1
            ? companionText("status.game.combo.stepOne", "连招 1/3：现在长按")
            : companionText("status.game.combo.stepTwo", "连招 2/3：最后快速甩动")
        playInteractionCue(.petComboStep, bypassCooldown: true)
        return true
    }

    private func finishComboGame(
        won: Bool,
        restorePreviousMode: Bool = true,
        announce: Bool = true
    ) {
        finishMicrogame(
            .gestureCombo,
            won: won,
            restorePreviousMode: restorePreviousMode,
            announce: announce
        )
    }

    private func registerHeartTracePoint(_ point: CGPoint) {
        let outcome = microgameRuntime.registerHeartPoint(
            CompanionNormalizedPoint(x: point.x, y: point.y)
        )
        guard outcome == .advanced || outcome == .completed else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
        petMood = .affectionate

        if outcome == .completed {
            suppressNextHeartTraceDragEnd = true
            finishHeartTraceGame(won: true)
            return
        }

        status = companionFormat(
            "status.game.heart.progress",
            "心形轨迹 %d/%d",
            heartTraceProgress,
            heartTraceGuidePoints.count
        )
        if heartTraceProgress == 3 || heartTraceProgress == 6 {
            playInteractionCue(.petTraceStep, bypassCooldown: true)
        }
    }

    private func resetHeartTraceAttempt(announce: Bool) {
        guard heartTraceGameActive else { return }
        microgameRuntime.resetHeartTrace()
        directInteractionActive = false
        petPose = .neutral
        petMood = .curious
        status = companionText(
            "status.game.heart.reset",
            "轨迹断开：从底部发光点重新开始"
        )
        if announce {
            playInteractionCue(.petTraceWrong, bypassCooldown: true)
        }
    }

    private func finishHeartTraceGame(
        won: Bool,
        restorePreviousMode: Bool = true,
        announce: Bool = true
    ) {
        finishMicrogame(
            .heartTrace,
            won: won,
            restorePreviousMode: restorePreviousMode,
            announce: announce
        )
    }

    private func registerRhythmTap(at date: Date) -> Bool {
        guard rhythmGameActive else { return false }
        let outcome = microgameRuntime.registerRhythmTap(at: date)
        guard outcome != .missed else {
            presentRhythmMissFeedback()
            return true
        }
        guard outcome == .advanced else { return false }

        petMood = .affectionate
        status = companionFormat(
            "status.game.rhythm.progress",
            "节拍命中 %d/8 · %d 连击",
            rhythmGameHits,
            rhythmGameCombo
        )
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )

        if rhythmGameHits == 3 || rhythmGameHits == 6 {
            playInteractionCue(.petRhythmHit, bypassCooldown: true)
        }
        return true
    }

    private func registerRhythmMiss() {
        guard rhythmGameActive else { return }
        _ = microgameRuntime.registerRhythmMiss()
        presentRhythmMissFeedback()
    }

    private func presentRhythmMissFeedback() {
        petMood = .curious
        status = rhythmGameBeat == 0
            ? companionText("status.game.rhythm.wait", "等心跳亮起时再轻点")
            : companionText("status.game.rhythm.miss", "差一点，等下一次心跳")
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .now
        )

        let now = Date()
        if now.timeIntervalSince(lastRhythmMissCueAt) >= 2.2 {
            lastRhythmMissCueAt = now
            playInteractionCue(.petRhythmMiss, bypassCooldown: true)
        }
    }

    private func finishRhythmGame(
        won: Bool,
        restorePreviousMode: Bool = true,
        announce: Bool = true
    ) {
        finishMicrogame(
            .rhythm,
            won: won,
            restorePreviousMode: restorePreviousMode,
            announce: announce
        )
    }

    private func finishFeedGame(
        won: Bool,
        restorePreviousMode: Bool = true,
        announce: Bool = true
    ) {
        finishMicrogame(
            .feed,
            won: won,
            restorePreviousMode: restorePreviousMode,
            announce: announce
        )
    }

    private func finishMicrogame(
        _ game: CompanionMicrogameKind,
        won: Bool,
        restorePreviousMode: Bool,
        announce: Bool
    ) {
        let wasTracing = game == .heartTrace && directInteractionActive
        guard let context = microgameRuntime.end(expectedGame: game) else {
            return
        }

        cleanUpMicrogamePresentation(game)
        if let windowOrigin = context.windowOrigin,
           let window = activePetWindow {
            window.setFrameOrigin(windowOrigin)
        }

        let plan = CompanionMicrogameCompletionPolicy().plan(
            for: game,
            won: won,
            announce: announce
        )
        let presentation = CompanionMicrogameCompletionPresenter.presentation(
            for: plan,
            allowsRomanticGestures: relationshipTone.allowsRomanticGestures
        )
        let returnMode = CompanionDisplayMode(context.presentationMode)
        status = presentation.status
        petMood = presentation.mood
        if let effect = presentation.effect {
            showPetEffect(symbol: effect.symbol, text: effect.text)
        }

        if won,
           let relationshipReward = plan.relationshipReward,
           let reward = presentation.reward {
            recordRelationshipMoment(
                relationshipReward.momentID,
                bond: relationshipReward.bond,
                chemistry: relationshipReward.chemistry,
                mementoID: relationshipReward.mementoID,
                cooldown: 0
            )
            switch reward {
            case let .action(action):
                playAction(action, presentationIntent: .gameReward)
            case let .miniScene(scene):
                playMiniScene(scene, presentationIntent: .gameReward)
            }
            commitGameRewardPresentation(returnMode, restorePreviousMode)
            return
        }

        if game == .heartTrace {
            suppressNextHeartTraceDragEnd = wasTracing
        }
        if plan.restoreImmediately && restorePreviousMode {
            setTemporaryDisplayMode(returnMode)
        }
        if let endCue = presentation.endCue {
            playInteractionCue(endCue, bypassCooldown: true)
        }
        resumePendingEventsAfterInteraction(after: plan.resumeDelay)
    }

    private func cleanUpMicrogamePresentation(
        _ game: CompanionMicrogameKind
    ) {
        switch game {
        case .catchPet:
            break
        case .hideAndSeek:
            hideGameLastEdge = nil
        case .gestureCombo:
            comboLongPressArmed = false
            directInteractionActive = false
            gestureMoveCuePlayed = false
        case .heartTrace:
            directInteractionActive = false
            gestureMoveCuePlayed = false
            petPose = .neutral
        case .rhythm:
            directInteractionActive = false
            effectSpeaker.stop()
            petPose = .neutral
        case .feed:
            directInteractionActive = false
            petPose = .neutral
        }
    }

    private var activePetWindow: NSWindow? {
        let visible = NSApp.windows.filter(\.isVisible)
        return visible.first(where: { $0.title == "澄音" })
            ?? visible.min {
                $0.frame.width * $0.frame.height
                    < $1.frame.width * $1.frame.height
            }
    }

    private func movePetForCatchGame() {
        guard catchGameActive, displayMode == .head,
              let window = activePetWindow
        else { return }

        let visible = window.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let placement = CompanionMicrogameWindowPolicy.catchPlacement(
            visibleFrame: visible,
            windowFrameSize: window.frame.size,
            pointerLocation: NSEvent.mouseLocation,
            entropy: UInt64.random(in: UInt64.min...UInt64.max)
        )

        window.setFrame(
            NSRect(origin: placement.origin, size: window.frame.size),
            display: true,
            animate: true
        )
    }

    private func movePetForHideGame() {
        guard hideGameActive, displayMode == .head,
              let window = activePetWindow
        else { return }

        let visible = window.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let placement = CompanionMicrogameWindowPolicy.hidePlacement(
            visibleFrame: visible,
            windowFrameSize: window.frame.size,
            previousEdge: hideGameLastEdge,
            entropy: UInt64.random(in: UInt64.min...UInt64.max)
        )
        hideGameLastEdge = placement.edge

        window.setFrame(
            NSRect(origin: placement.origin, size: window.frame.size),
            display: true,
            animate: true
        )
    }

    @discardableResult
    private func playInteractionCue(
        _ event: CompanionEventKind,
        bypassCooldown: Bool = false
    ) -> TimeInterval {
        guard !experienceRuntime.isPresentationActive,
              activeContentSequence == nil,
              eventAction == nil,
              activeScene == nil,
              activeMiniScene == nil
        else { return 0 }

        let selection = voiceSelection.selectInteraction(
            event,
            addressedEnabled: addressedVoiceEnabled,
            at: Date(),
            bypassCooldown: bypassCooldown
        )
        switch selection {
        case .cooldown:
            return 0
        case .unavailable:
            lastError = companionFormat(
                "error.voice.interactionEventMissing",
                "互动语音包中没有 %@ 提示。",
                event.rawValue
            )
            return 0
        case let .line(line):
            return interactionSpeaker.play(fileName: line.audioFile)
        }
    }

    private func updateGaze(_ normalizedPoint: CGPoint) {
        let x = max(-1, min(1, normalizedPoint.x))
        let y = max(-1, min(1, normalizedPoint.y))
        petPose = PetPose(
            x: x * 4.5,
            y: y * 2.4,
            rotation: x * 2.2,
            scale: 1.012
        )
    }

    func showPetEffect(symbol: String, text: String) {
        feedbackRuntime.presentEffect(symbol: symbol, text: text)
    }

    private func schedulePoseReset(after delay: TimeInterval) {
        feedbackRuntime.schedulePoseReset(after: delay)
    }

    private func scheduleMoodReset(after delay: TimeInterval) {
        feedbackRuntime.scheduleMoodReset(after: delay) { [weak self] in
            guard let self else { return false }
            return !self.directInteractionActive
                && !self.experienceRuntime.isPresentationActive
        }
    }

    private func resumePendingEventsAfterInteraction(
        after delay: TimeInterval = 0.9
    ) {
        guard !experienceRuntime.isPresentationActive,
              experienceRuntime.pendingCount > 0
        else { return }
        experienceRuntime.schedulePendingDelivery(
            after: delay,
            isReady: { [weak self] in
                guard let self else { return false }
                return !self.directInteractionActive
                    && !self.interactionAudioActive
                    && !self.experienceRuntime.isPresentationActive
            },
            onReady: { [weak self] next in
                self?.triggerEvent(
                    next.event,
                    priority: true,
                    completionContext: next.completionContext,
                    source: next.source
                )
            }
        )
    }

    func evaluateReminderSchedule() {
        let now = Date()
        applySharedDayCareReceipt(
            sharedDayRuntime.evaluateCare(
                at: now,
                facts: sharedDayCareFacts
            ),
            at: now
        )
    }

    private var sharedDayCareFacts: CompanionSharedDayCareFacts {
        CompanionSharedDayCareFacts(
            remindersEnabled: remindersEnabled,
            userRecentlyActive: isUserRecentlyActive,
            quietHoursEnabled: quietHoursEnabled,
            timeAnnouncementsEnabled: timeAnnouncementsEnabled,
            halfHourlyAnnouncementsEnabled: halfHourlyAnnouncementsEnabled,
            cadence: careCadence.backupCareCadence,
            activityState: sharedDayActivityState
        )
    }

    private var sharedDayActivityState: CompanionLifestyleActivityState {
        if petGameActive {
            return .gameplay
        }
        if isPresentingMedia
            || directInteractionActive
            || interactionAudioActive
            || isSpeaking {
            return .mediaPlayback
        }
        // Recent keyboard/mouse activity is a local, privacy-free proxy for a
        // work session. It never exposes a task title, prompt or file path.
        return .focusedWork(startedAt: lifestyleRuntime.activityAnchor)
    }

    private func applySharedDayCareReceipt(
        _ sharedReceipt: CompanionSharedDayCareReceipt,
        at now: Date
    ) {
        if let persistenceError = sharedReceipt.workdayPersistenceError {
            lastError = CompanionErrorPresentation.message(for: persistenceError)
        }
        let receipt = sharedReceipt.lifestyle
        if let persistenceError = receipt.persistenceError {
            lastError = CompanionErrorPresentation.message(for: persistenceError)
        }
        switch receipt.outcome {
        case let .play(kind):
            if deliverLifestyleReminder(kind, at: now) {
                if let error = lifestyleRuntime.recordDelivered(kind, at: now) {
                    lastError = CompanionErrorPresentation.message(for: error)
                }
            } else {
                lifestyleRhythmStatus = companionText(
                    "care.status.afterInteraction",
                    "当前互动结束后再关心你"
                )
            }
        default:
            lifestyleRhythmStatus = CompanionLifestylePresentation.status(
                for: receipt.outcome,
                now: now
            )
        }
    }

    private var isUserRecentlyActive: Bool {
        CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .null
        ) < 10 * 60
    }

    @discardableResult
    private func deliverLifestyleReminder(
        _ kind: CompanionLifestyleReminderKind,
        at date: Date
    ) -> Bool {
        let plan = CompanionLifestyleEventProjection.deliveryPlan(
            for: kind,
            at: date,
            allowsFlirtyEncouragement: flirtyRemindersEnabled
                && relationshipTone.allowsFlirtyReminders
        )
        let delivered = triggerEvent(
            plan.event,
            preferredVoiceLineID: plan.preferredVoiceLineID
        )

        if delivered {
            lifestyleRhythmStatus = CompanionLifestylePresentation.delivered(
                kind
            )
        }
        return delivered
    }

    private func handleCodexSignal(_ signal: CodexTaskSignal) {
        let workdayReceipt = workdayRuntime.consume(
            signal,
            allowsPassivePresenceUpdate: !isPresentingMedia
                && !directInteractionActive
                && !petGameActive
        )
        if let persistenceError = workdayReceipt.persistenceError {
            lastError = CompanionErrorPresentation.message(for: persistenceError)
        }
        applyWorkdayPresentation(workdayReceipt.presentation)
    }

    private func applyWorkdayPresentation(
        _ presentation: CompanionWorkdayPresentationPlan
    ) {
        let plan = CompanionWorkdayApplicationProjection.project(presentation)
        if let visual = plan.visual {
            codexVisualState = visual
        }
        if let mood = plan.mood {
            petMood = mood
        }
        if let projectedStatus = plan.status {
            status = projectedStatus
        }
        if let relationship = plan.relationship {
            recordRelationshipMoment(
                relationship.momentID,
                bond: relationship.bond,
                chemistry: relationship.chemistry,
                mementoID: relationship.primaryMementoID,
                cooldown: 0
            )
            for mementoID in relationship.additionalMementoIDs {
                unlockMemento(mementoID)
            }
        }
        if let contentCue = plan.contentCue {
            presentWorkdayContentCue(contentCue)
        }
        switch plan.event {
        case let .taskComplete(context):
            triggerEvent(
                .taskComplete,
                priority: true,
                completionContext: context
            )
        case .taskFailed:
            triggerEvent(.taskFailed, priority: true)
        case .responseReady:
            // A response boundary is useful but never a completion claim. The
            // unified director chooses full, ambient, queued, or silent delivery.
            triggerEvent(.replyReady, priority: false)
        case .none:
            break
        }
    }

    private func presentWorkdayContentCue(
        _ cue: CompanionWorkdayContentCue
    ) {
        guard playbackMode == .audioVisual else { return }
        let decision = experienceRuntime.decide(
            for: .ambientPresence,
            context: CompanionExperienceContext(
                now: Date(),
                isDirectInteractionActive: directInteractionActive
                    || interactionAudioActive,
                isGameplayActive: petGameActive,
                isMediaPlaybackActive: experienceRuntime.isPresentationActive
                    || activeContentSequence != nil
                    || eventAction != nil
                    || activeScene != nil
                    || activeMiniScene != nil,
                isSpeaking: isSpeaking,
                isQuietHours: isWithinQuietHours(Date())
            )
        )
        guard decision == .present else { return }
        if !beginContentSequenceIfAvailable(
            triggers: [cue.rawValue],
            fallback: .workdayCue(cue),
            eventKind: nil,
            presentationStatus: status
        ) {
            presentBuiltInWorkdayCue(cue)
        }
    }

    private func presentBuiltInWorkdayCue(
        _ cue: CompanionWorkdayContentCue
    ) {
        guard !directInteractionActive,
              !petGameActive,
              !isPresentingMedia else { return }
        switch cue {
        case .taskStarted:
            petMood = .focused
        case .taskLongRunning:
            petMood = .calm
        case .taskCancelled:
            petMood = .curious
        }
        let effect = CompanionWorkdayPresentationCopy.cueEffect(for: cue)
        showPetEffect(symbol: effect.symbol, text: effect.text)
    }

    private func isWithinQuietHours(_ date: Date) -> Bool {
        guard quietHoursEnabled else { return false }
        return CompanionLifestyleQuietHours(
            startHour: 23,
            startMinute: 30,
            endHour: 8,
            endMinute: 30
        ).contains(date, calendar: .current)
    }

    private func startSharedDayRuntime() {
        sharedDayRuntime.start(
            careFacts: { [weak self] in
                self?.sharedDayCareFacts
            },
            onCareReceipt: { [weak self] receipt, now in
                self?.applySharedDayCareReceipt(receipt, at: now)
            },
            announcementsEnabled: { [weak self] in
                self?.codexCompletionAnnouncementsEnabled == true
            },
            onWorkSignal: { [weak self] signal in
                self?.handleCodexSignal(signal)
            },
            onReadinessChanged: { [weak self] in
                self?.rebuildRuntimeReadiness()
            }
        )
    }

    private func startContentPackRecovery() {
        contentLibraryRuntime.startRecovery(
            enabled: { [weak self] in
                self?.localContentPacksEnabled == true
            },
            recover: { [weak self] in
                guard let self else { throw CancellationError() }
                return try await self.contentOperations.recoverInterruptedInstalls()
            },
            onLibraryHealthChanged: { [weak self] healthy in
                guard let self else { return }
                self.runtimeRepair.markContentLibraryHealthy(healthy)
                self.rebuildRuntimeReadiness()
            },
            onFailure: { [weak self] error in
                guard let self else { return }
                self.lastError = companionFormat(
                    "error.pack.selfCheck",
                    "内容包自检失败：%@",
                    CompanionErrorPresentation.message(for: error)
                )
            }
        )
    }

    private func reportContentPlayback(
        _ asset: CompanionVideoAsset,
        succeeded: Bool
    ) {
        guard let reference = asset.packReference else {
            return
        }
        reportContentPlayback(reference: reference, succeeded: succeeded)
    }

    private func reportContentPlayback(
        reference: ContentPackPlaybackReference,
        succeeded: Bool
    ) {
        guard let validation = contentLibraryRuntime
            .beginPlaybackValidation(reference) else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let inventory = try await contentOperations.reportPlayback(
                    reference: reference,
                    succeeded: succeeded
                )
                if contentLibraryRuntime.completePlaybackValidation(
                    validation,
                    inventory: inventory,
                    succeeded: succeeded,
                    enabled: localContentPacksEnabled
                ) {
                    runtimeRepair.markContentLibraryHealthy(true)
                    rebuildRuntimeReadiness()
                }
            } catch {
                let presentedError = CompanionErrorPresentation.message(for: error)
                if contentLibraryRuntime.failPlaybackValidation(
                    validation,
                    enabled: localContentPacksEnabled
                ) {
                    lastError = companionFormat(
                        "error.pack.playbackCheck",
                        "内容包播放健康检查失败：%@",
                        presentedError
                    )
                }
            }
        }
    }

    private static var preferredContentLocale: String {
        Locale.preferredLanguages.first ?? Locale.current.identifier
    }
}
