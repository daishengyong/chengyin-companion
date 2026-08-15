import CompanionContracts
import Foundation

extension CompanionViewModel {
    func replayFirstSession() {
        startFirstSession(replay: true)
    }

    func skipFirstSession() {
        guard firstSessionPresented else { return }
        let effect = firstSessionRuntime.skip()
        guard effect == .skipped else { return }
        CompanionFirstSessionPreferences.markCompleted(
            preference: firstSessionRuntime.journey.preference,
            in: defaults
        )
        if let returnMode = presentationRuntime.finish() {
            setTemporaryDisplayMode(CompanionDisplayMode(returnMode))
        }
        status = workdayPresenceText
        showPetEffect(
            symbol: "checkmark.circle.fill",
            text: CompanionLocalization.string(
                key: "firstSession.skipped.effect",
                fallback: "随时可从魔术棒重新打开"
            )
        )
    }

    func chooseFirstSessionPreference(
        _ preference: CompanionFirstSessionPreference
    ) {
        let effect = firstSessionRuntime.selectPreference(preference)
        guard effect == .applyPreferenceAndRunWorkArc(preference) else { return }
        applyFirstSessionPreference(preference)
        runCodexWorkArcPreview(completesFirstSession: true)
    }

    func startFirstSession(replay: Bool) {
        guard !petGameActive else {
            status = CompanionLocalization.string(
                key: "firstSession.gameBlocked",
                fallback: "先结束当前小游戏，再打开快速上手"
            )
            return
        }
        let effect = replay
            ? firstSessionRuntime.replay()
            : firstSessionRuntime.begin()
        guard effect == .presentCoach else { return }

        if !replay {
            CompanionFirstSessionPreferences.markStarted(in: defaults)
        }

        clearFirstSessionPresentationState()
        playPalettePresented = false
        presentationRuntime.reset()
        applyPresentationDirective(
            presentationRuntime.beginAutomaticResponse(
                currentMode: displayMode.presentationMode
            )
        )
        petMood = .curious
        codexVisualState = .idle
        status = CompanionLocalization.string(
            key: "firstSession.started.status",
            fallback: "快速上手：先轻点澄音一下"
        )
        showPetEffect(
            symbol: "cursorarrow.click",
            text: CompanionLocalization.string(
                key: "firstSession.started.effect",
                fallback: "轻点我一下"
            )
        )
    }

    private func applyFirstSessionPreference(
        _ preference: CompanionFirstSessionPreference
    ) {
        remindersEnabled = true
        switch preference {
        case .workCompanion:
            careCadence = .gentle
            flirtyRemindersEnabled = false
            updateRelationshipState { $0.setToneCap(.calmPeer) }
        case .playfulBreaks:
            careCadence = .lively
            flirtyRemindersEnabled = false
            updateRelationshipState { $0.setToneCap(.playfulSpark) }
        case .gentleCare:
            careCadence = .standard
            flirtyRemindersEnabled = false
            updateRelationshipState { $0.setToneCap(.warmSupport) }
        }
        evaluateReminderSchedule()
    }

    func runCodexWorkArcPreview(completesFirstSession: Bool) {
        clearFirstSessionPresentationState()
        firstSessionRuntime.runWorkArc { [weak self] beat in
            guard let self else { return }
            switch beat {
            case .idle:
                break
            case .started:
                self.petMood = .focused
                self.codexVisualState = .working
                self.status = CompanionLocalization.string(
                    key: "status.workArc.started",
                    fallback: "体验：Codex 开始工作，澄音进入安静陪伴"
                )
                self.showPetEffect(
                    symbol: "hammer.fill",
                    text: CompanionLocalization.string(
                        key: "effect.codex.started",
                        fallback: "Codex 开始工作"
                    )
                )
            case .progress:
                self.petMood = .focused
                self.status = CompanionLocalization.string(
                    key: "status.workArc.progress",
                    fallback: "体验：Codex 正在推进，澄音继续陪着你"
                )
            case .longRunning:
                self.status = CompanionLocalization.string(
                    key: "status.workArc.longRunning",
                    fallback: "体验：长任务进行中，澄音不打扰地守着你"
                )
            case .completed:
                if completesFirstSession {
                    guard self.firstSessionRuntime.completeJourneyAfterWorkArc()
                        == .complete else { return }
                    CompanionFirstSessionPreferences.markCompleted(
                        preference: self.firstSessionRuntime.journey.preference,
                        in: self.defaults
                    )
                }
                self.playNativeTaskCompletion(
                    context: CompanionCompletionContext(
                        duration: 12 * 60,
                        completionCountToday: 2,
                        recoveredAfterFailure: false,
                        tier: .playful
                    )
                )
            }
        }
    }
}
