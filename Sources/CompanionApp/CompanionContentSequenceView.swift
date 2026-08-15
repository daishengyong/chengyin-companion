import CompanionContracts
import Foundation
import SwiftUI

/// Focused declarative sequence player. It prewarms only the bounded selected
/// sequence, ignores stale item callbacks through the cursor contract, and
/// leaves selection, recovery and return policy to the view model/Core.
struct CompanionContentSequenceView: View {
    @ObservedObject var viewModel: CompanionViewModel
    let sequence: CompanionVideoSequence
    let presentationMode: CompanionPresentationMode

    @State private var cursor: CompanionSequencePlaybackCursor
    @State private var stepStartedAt = Date()
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    init(
        viewModel: CompanionViewModel,
        sequence: CompanionVideoSequence,
        presentationMode: CompanionPresentationMode
    ) {
        self.viewModel = viewModel
        self.sequence = sequence
        self.presentationMode = presentationMode
        _cursor = State(
            initialValue: CompanionSequencePlaybackCursor(
                sequenceID: sequence.id,
                stepCount: sequence.steps.count
            )
        )
    }

    var body: some View {
        Group {
            if sequence.steps.indices.contains(cursor.currentIndex) {
                let index = cursor.currentIndex
                let step = sequence.steps[index]
                LoopingActionVideoView(
                    url: step.asset.url,
                    isMuted: false,
                    loops: false,
                    projection: mediaProjection(
                        for: step.asset,
                        mode: presentationMode
                    ),
                    onPlaybackReady: {
                        guard cursor.currentIndex == index else { return }
                        stepStartedAt = Date()
                    },
                    onPlaybackFailure: {
                        viewModel.reportContentSequenceFailure(sequence)
                    },
                    onPlaybackEnded: {
                        handleStepEnded(step: step, index: index)
                    }
                )
                .id("\(sequence.id):\(index)")
                .transition(
                    step.transition == .crossfade
                        ? .opacity
                        : .identity
                )
            } else {
                Color.clear
            }
        }
        .onAppear {
            stepStartedAt = Date()
            CompanionMediaPrewarmCache.shared.prewarm(
                urls: sequence.steps.map(\.asset.url)
            )
        }
    }

    private func handleStepEnded(
        step: CompanionVideoSequenceStep,
        index: Int
    ) {
        let elapsed = Date().timeIntervalSince(stepStartedAt)
        let minimum = TimeInterval(step.minimumPlaybackMs) / 1_000
        let remaining = max(0, minimum - elapsed)
        let expectedSequenceID = sequence.id
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
            guard cursor.sequenceID == expectedSequenceID,
                  cursor.currentIndex == index else {
                return
            }
            let advance: CompanionSequencePlaybackCursor.Advance
            if !reducesMotion,
               index + 1 < sequence.steps.count,
               sequence.steps[index + 1].transition == .crossfade {
                advance = withAnimation(.easeInOut(duration: 0.28)) {
                    cursor.stepEnded(
                        sequenceID: expectedSequenceID,
                        index: index
                    )
                }
            } else {
                advance = cursor.stepEnded(
                    sequenceID: expectedSequenceID,
                    index: index
                )
            }
            switch advance {
            case .showStep:
                stepStartedAt = Date()
            case .completed:
                viewModel.reportContentSequenceCompleted(sequence)
            case .ignored:
                break
            }
        }
    }
}
