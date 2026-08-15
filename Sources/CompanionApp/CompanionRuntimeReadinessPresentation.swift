import CompanionContracts
import Foundation

/// Read-only localized projection for the Settings health surface.
/// Runtime collection and repair remain in their focused coordinators.
extension CompanionViewModel {
    var runtimeReadinessSummary: String {
        CompanionRuntimeSupportCopy.summary(runtimeSupportSnapshot)
    }

    var runtimeReadinessChecks: [CompanionRuntimeReadinessCheck] {
        runtimeSupportSnapshot.checks
    }

    var runtimeSafeRepairAvailable: Bool {
        !runtimeSupportSnapshot.safeRecoveryActions.isEmpty
    }

    func runtimeReadinessTitle(
        for component: CompanionRuntimeReadinessComponent
    ) -> String {
        CompanionRuntimeSupportCopy.title(for: component)
    }

    func runtimeReadinessDetail(
        for check: CompanionRuntimeReadinessCheck
    ) -> String {
        CompanionRuntimeSupportCopy.detail(
            for: check,
            snapshot: runtimeSupportSnapshot,
            installedContentPackCount: installedContentPackCount
        )
    }
}
