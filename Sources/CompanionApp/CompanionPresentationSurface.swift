import CompanionContracts
import SwiftUI

extension ContentView {
    var performancePolicy: CompanionPerformancePolicy {
        CompanionPerformancePolicy(
            reducedDynamicEffectsEnabled: viewModel.reducedDynamicEffectsEnabled,
            systemReduceMotionEnabled: reducesMotion,
            requestedPlayback: viewModel.playbackMode == .audioVisual
                ? .audiovisual
                : .audioOnly
        )
    }

    var presentationAnimation: Animation? {
        !performancePolicy.usesAnimatedTransitions
            ? nil
            : .spring(response: 0.4, dampingFraction: 0.82)
    }

    var mediaTransition: AnyTransition {
        !performancePolicy.usesAnimatedTransitions
            ? .identity
            : .scale(scale: 0.96).combined(with: .opacity)
    }

    var surfacePlan: CompanionPresentationSurfacePlan {
        CompanionPresentationSurfacePolicy.plan(
            mode: viewModel.displayMode.presentationMode,
            requestedAppearance: viewModel.presentationAppearance,
            systemReduceTransparencyEnabled: reducesTransparency,
            systemIncreaseContrastEnabled: colorSchemeContrast == .increased
        )
    }
}

struct CompanionPresentationSurface: View {
    let plan: CompanionPresentationSurfacePlan

    var body: some View {
        ZStack {
            switch plan.resolvedAppearance {
            case .transparent:
                Color.clear
            case .cinematic:
                Color.black.opacity(plan.backgroundOpacity)
                LinearGradient(
                    colors: [
                        Color.indigo.opacity(0.24),
                        Color.black.opacity(0.08),
                        Color.pink.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(plan.vignetteOpacity)
                    ],
                    center: .center,
                    startRadius: 80,
                    endRadius: 760
                )
                if plan.usesTranslucentMaterial {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.34)
                }
            case .dim:
                Color.black.opacity(plan.backgroundOpacity)
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.035),
                        Color.black.opacity(plan.vignetteOpacity)
                    ],
                    center: .center,
                    startRadius: 40,
                    endRadius: 680
                )
            }
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: plan.cornerRadius,
                style: .continuous
            )
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
