import AppKit
import CompanionContracts
import SwiftUI

struct PetInteractionSurface: NSViewRepresentable {
    let allowsWindowDrag: Bool
    let delaysSingleClick: Bool
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void
    let onHover: (Bool, CGPoint) -> Void
    let onPointerMove: (CGPoint) -> Void
    let onPressChanged: (Bool) -> Void
    let onLongPressBegan: () -> Void
    let onLongPressEnded: () -> Void
    let onDragChanged: (CGSize, Bool, CGPoint) -> Void
    let onDragEnded: (CGSize, CGSize, PetDockEdge?) -> Void

    func makeNSView(context: Context) -> PetInteractionNSView {
        let view = PetInteractionNSView()
        view.toolTip = "单击、双击、长按抚摸；拖动和甩动都有音画反馈"
        configure(view)
        return view
    }

    func updateNSView(
        _ nsView: PetInteractionNSView,
        context: Context
    ) {
        configure(nsView)
    }

    private func configure(_ view: PetInteractionNSView) {
        view.allowsWindowDrag = allowsWindowDrag
        view.delaysSingleClick = delaysSingleClick
        view.onSingleClick = onSingleClick
        view.onDoubleClick = onDoubleClick
        view.onHover = onHover
        view.onPointerMove = onPointerMove
        view.onPressChanged = onPressChanged
        view.onLongPressBegan = onLongPressBegan
        view.onLongPressEnded = onLongPressEnded
        view.onDragChanged = onDragChanged
        view.onDragEnded = onDragEnded
    }
}

final class PetInteractionNSView: NSView {
    var allowsWindowDrag = true
    var delaysSingleClick = true
    var onSingleClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onHover: ((Bool, CGPoint) -> Void)?
    var onPointerMove: ((CGPoint) -> Void)?
    var onPressChanged: ((Bool) -> Void)?
    var onLongPressBegan: (() -> Void)?
    var onLongPressEnded: (() -> Void)?
    var onDragChanged: ((CGSize, Bool, CGPoint) -> Void)?
    var onDragEnded: ((CGSize, CGSize, PetDockEdge?) -> Void)?

    private var pendingSingleClick: DispatchWorkItem?
    private var pendingLongPress: DispatchWorkItem?
    private var trackingAreaReference: NSTrackingArea?
    private var mouseDownGlobal = CGPoint.zero
    private var startingWindowOrigin = CGPoint.zero
    private var lastGlobal = CGPoint.zero
    private var lastTimestamp: TimeInterval = 0
    private var latestVelocity = CGSize.zero
    private var isDraggingGesture = false
    private var isMovingWindow = false
    private var longPressTriggered = false

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [
                .mouseEnteredAndExited,
                .mouseMoved,
                .activeAlways,
                .inVisibleRect
            ],
            owner: self
        )
        addTrackingArea(area)
        trackingAreaReference = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?(true, normalizedPoint(for: event))
    }

    override func mouseMoved(with event: NSEvent) {
        onPointerMove?(normalizedPoint(for: event))
    }

    override func mouseExited(with event: NSEvent) {
        if !isDraggingGesture {
            onHover?(false, .zero)
        }
    }

    override func mouseDown(with event: NSEvent) {
        pendingSingleClick?.cancel()
        pendingSingleClick = nil
        pendingLongPress?.cancel()

        mouseDownGlobal = NSEvent.mouseLocation
        lastGlobal = mouseDownGlobal
        startingWindowOrigin = window?.frame.origin ?? .zero
        lastTimestamp = event.timestamp
        latestVelocity = .zero
        isDraggingGesture = false
        isMovingWindow = false
        longPressTriggered = false
        onPressChanged?(true)

        let work = DispatchWorkItem { [weak self] in
            guard
                let self,
                !self.isDraggingGesture,
                self.window != nil
            else { return }
            self.longPressTriggered = true
            NSHapticFeedbackManager.defaultPerformer.perform(
                .alignment,
                performanceTime: .now
            )
            self.onLongPressBegan?()
        }
        pendingLongPress = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72, execute: work)
    }

    override func mouseDragged(with event: NSEvent) {
        let global = NSEvent.mouseLocation
        let translation = CGSize(
            width: global.x - mouseDownGlobal.x,
            height: global.y - mouseDownGlobal.y
        )
        let distance = hypot(translation.width, translation.height)
        if distance > 6 {
            pendingLongPress?.cancel()
            pendingLongPress = nil
            isDraggingGesture = true
        }

        let interval = max(event.timestamp - lastTimestamp, 0.001)
        latestVelocity = CGSize(
            width: (global.x - lastGlobal.x) / interval,
            height: (global.y - lastGlobal.y) / interval
        )
        lastGlobal = global
        lastTimestamp = event.timestamp

        let wasMovingWindow = isMovingWindow
        isMovingWindow = allowsWindowDrag && distance > 24
        if isMovingWindow, !wasMovingWindow {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .levelChange,
                performanceTime: .now
            )
        }
        if isMovingWindow, let window {
            window.setFrameOrigin(
                CGPoint(
                    x: startingWindowOrigin.x + translation.width,
                    y: startingWindowOrigin.y + translation.height
                )
            )
        }
        onDragChanged?(
            translation,
            isMovingWindow,
            normalizedPoint(for: event)
        )
    }

    override func mouseUp(with event: NSEvent) {
        pendingLongPress?.cancel()
        pendingLongPress = nil
        onPressChanged?(false)

        let global = NSEvent.mouseLocation
        let translation = CGSize(
            width: global.x - mouseDownGlobal.x,
            height: global.y - mouseDownGlobal.y
        )

        if longPressTriggered {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .generic,
                performanceTime: .now
            )
            onLongPressEnded?()
            resetGestureState()
            return
        }

        if isDraggingGesture {
            let edge = isMovingWindow ? dockWindowIfNeeded() : nil
            NSHapticFeedbackManager.defaultPerformer.perform(
                edge == nil ? .generic : .alignment,
                performanceTime: .now
            )
            onDragEnded?(translation, latestVelocity, edge)
            resetGestureState()
            return
        }

        if event.clickCount >= 2 {
            pendingSingleClick?.cancel()
            pendingSingleClick = nil
            if delaysSingleClick {
                onDoubleClick?()
            }
            resetGestureState()
            return
        }

        if !delaysSingleClick {
            onSingleClick?()
            resetGestureState()
            return
        }

        pendingSingleClick?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onSingleClick?()
            self?.pendingSingleClick = nil
        }
        pendingSingleClick = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + NSEvent.doubleClickInterval,
            execute: work
        )
        resetGestureState()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    private func normalizedPoint(for event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.width > 0, bounds.height > 0 else { return .zero }
        return CGPoint(
            x: (point.x / bounds.width) * 2 - 1,
            y: (point.y / bounds.height) * 2 - 1
        )
    }

    private func dockWindowIfNeeded() -> PetDockEdge? {
        guard let window else { return nil }
        let visible = window.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? CompanionWindowPolicy.fallbackVisibleFrame
        let result = CompanionWindowPolicy.dockedPetOrigin(
            window.frame.origin,
            visibleFrame: visible,
            windowFrameSize: window.frame.size
        )
        window.setFrameOrigin(result.origin)
        PetWindowPositionStore.save(result.origin)
        return result.edge.map { edge in
            switch edge {
            case .left: .left
            case .right: .right
            case .top: .top
            case .bottom: .bottom
            }
        }
    }

    private func resetGestureState() {
        isDraggingGesture = false
        isMovingWindow = false
        longPressTriggered = false
    }
}
