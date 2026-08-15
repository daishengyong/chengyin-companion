import CompanionContracts
import Foundation

/// A one-time, progressive hint for discovering the desktop pet gestures.
///
/// Lessons are stored as completed capabilities, not as a score. There is no
/// deadline, streak or penalty: each hint simply disappears once the gesture has
/// been used successfully.
typealias CompanionGestureLesson = CompanionGestureCapability

extension CompanionGestureCapability {
    var title: String {
        switch self {
        case .singleTap:
            CompanionLocalization.string(
                key: "gesture.singleTap.title",
                fallback: "轻点我"
            )
        case .doubleTap:
            CompanionLocalization.string(
                key: "gesture.doubleTap.title",
                fallback: "双击看看"
            )
        case .longPress:
            CompanionLocalization.string(
                key: "gesture.longPress.title",
                fallback: "按住摸摸"
            )
        case .drag:
            CompanionLocalization.string(
                key: "gesture.drag.title",
                fallback: "拖我走走"
            )
        }
    }

    var systemImage: String {
        switch self {
        case .singleTap:
            "cursorarrow.click"
        case .doubleTap:
            "cursorarrow.click.2"
        case .longPress:
            "hand.tap.fill"
        case .drag:
            "arrow.up.and.down.and.arrow.left.and.right"
        }
    }
}
