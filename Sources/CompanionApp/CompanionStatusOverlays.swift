import CompanionContracts
import SwiftUI

/// Focused, presentation-only overlays for Codex state, completion replies and
/// relationship feedback. Keeping these in one small file prevents the main
/// stage composition from becoming the owner of status animation policy.
struct CompletionReplyCue: View {
    @State private var pulses = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "heart.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .pink)

            Image(systemName: "cursorarrow.click")
            Image(systemName: "hand.tap.fill")
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.black.opacity(0.36), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.pink.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: .pink.opacity(0.65), radius: 10)
        .scaleEffect(pulses ? 1.06 : 0.94)
        .opacity(pulses ? 1 : 0.74)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.72)
                    .repeatForever(autoreverses: true)
            ) {
                pulses = true
            }
        }
        .accessibilityLabel(companionAccessibilityText(
            "accessibility.completionReply.label", "澄音正在等待你的手势回应"
        ))
        .accessibilityIdentifier("chengyin.completion-reply-cue")
    }
}

struct CodexPresenceHalo: View {
    let state: CompanionCodexVisualState
    @State private var pulses = false

    private var color: Color {
        switch state {
        case .idle:
            .clear
        case .working:
            .blue
        case .completed:
            .yellow
        case .awaitingReply:
            .pink
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let radius = min(
                28,
                max(18, min(proxy.size.width, proxy.size.height) * 0.13)
            )
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(
                    color.opacity(pulses ? 0.92 : 0.42),
                    lineWidth: state == .completed ? 3 : 2
                )
                .shadow(
                    color: color.opacity(pulses ? 0.78 : 0.30),
                    radius: pulses ? 16 : 7
                )
                .padding(2)
                .scaleEffect(pulses ? 1 : 0.988)
        }
        .opacity(state == .idle ? 0 : 1)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(
                .easeInOut(duration: state == .completed ? 0.48 : 1.05)
                    .repeatForever(autoreverses: true)
            ) {
                pulses = true
            }
        }
        .accessibilityHidden(true)
    }
}

struct CodexPresenceGlyph: View {
    let state: CompanionCodexVisualState

    private var symbol: String {
        switch state {
        case .idle:
            "circle"
        case .working:
            "hammer.fill"
        case .completed:
            "checkmark.seal.fill"
        case .awaitingReply:
            "hand.tap.fill"
        }
    }

    private var color: Color {
        switch state {
        case .idle:
            .clear
        case .working:
            .blue
        case .completed:
            .yellow
        case .awaitingReply:
            .pink
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(color.opacity(0.82), in: Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.42), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.70), radius: 8)
            .accessibilityLabel(companionCodexAccessibilityLabel(state))
            .accessibilityIdentifier("chengyin.codex-presence")
    }
}

struct RelationshipReceiptToast: View {
    let receipt: CompanionRelationshipReceipt
    let compact: Bool

    private var accent: Color {
        receipt.kind.isMilestone ? .yellow : .pink
    }

    var body: some View {
        HStack(spacing: compact ? 4 : 7) {
            Image(systemName: receipt.kind.symbolName)
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(
                    compact
                        ? receipt.kind.compactTitle
                        : receipt.kind.title
                )
                .font(
                    .system(
                        size: compact ? 9 : 12,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .lineLimit(1)
                if !compact, let detail = receipt.kind.detail {
                    Text(detail)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 7 : 10)
        .padding(.vertical, compact ? 5 : 7)
        .background(.black.opacity(0.62), in: Capsule())
        .overlay(
            Capsule()
                .stroke(accent.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.55), radius: 11)
        .frame(maxWidth: compact ? 94 : nil)
        .accessibilityElement(children: .combine)
    }
}

struct SurpriseCornerStar: View {
    @State private var twinkles = false

    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.yellow)
            .frame(width: 25, height: 25)
            .background(.black.opacity(0.56), in: Circle())
            .overlay(
                Circle()
                    .stroke(Color.yellow.opacity(0.70), lineWidth: 1)
            )
            .shadow(
                color: .yellow.opacity(twinkles ? 0.90 : 0.38),
                radius: twinkles ? 10 : 4
            )
            .rotationEffect(.degrees(twinkles ? 8 : -8))
            .scaleEffect(twinkles ? 1.12 : 0.92)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.72)
                        .repeatForever(autoreverses: true)
                ) {
                    twinkles = true
                }
            }
            .help(companionAccessibilityText(
                "accessibility.surprise.help", "她准备了一个惊喜，试试双击"
            ))
            .accessibilityLabel(companionAccessibilityText(
                "accessibility.surprise.label", "澄音准备了一个惊喜，双击可以打开"
            ))
            .accessibilityIdentifier("chengyin.surprise-cue")
    }
}
