//
//  OverlayPanel.swift
//  ReadAndReact
//
//  Created by TJ Togatapola on 4/28/26.
//

import AppKit

// MARK: - OverlayPanel

/// A transparent, borderless, floating panel that defines the screen capture region.
/// The interior passes through all mouse events to apps underneath.
/// The border and corner handles are interactive for dragging and resizing.
class OverlayPanel: NSPanel {

    init() {
        super.init(
            contentRect: NSRect(x: 200, y: 200, width: 600, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        becomesKeyOnlyIfNeeded = true

        let overlayView = OverlayContentView()
        contentView = overlayView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - OverlayContentView

/// Custom view that draws the capture region border and handles hit-testing
/// so that the interior is click-through while the border is interactive.
class OverlayContentView: NSView {

    private let borderWidth: CGFloat = 3.0
    private let handleSize: CGFloat = 12.0
    private let hitMargin: CGFloat = 14.0

    private var dragType: DragType = .none
    private var initialMouseLocation: NSPoint = .zero
    private var initialFrame: NSRect = .zero

    enum DragType {
        case none, move
        case resizeTopLeft, resizeTopRight, resizeBottomLeft, resizeBottomRight
        case resizeTop, resizeBottom, resizeLeft, resizeRight
    }

    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()

        // Draw the dashed border
        let borderRect = bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        let borderPath = NSBezierPath(rect: borderRect)
        borderPath.lineWidth = borderWidth
        NSColor.systemGreen.withAlphaComponent(0.85).setStroke()
        let dashPattern: [CGFloat] = [8, 4]
        borderPath.setLineDash(dashPattern, count: 2, phase: 0)
        borderPath.stroke()

        // Draw resize handles at corners
        for corner in [Corner.topLeft, .topRight, .bottomLeft, .bottomRight] {
            drawHandle(at: cornerRect(for: corner))
        }
    }

    private func drawHandle(at rect: NSRect) {
        let path = NSBezierPath(ovalIn: rect)
        NSColor.systemGreen.withAlphaComponent(0.9).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    private func cornerRect(for corner: Corner) -> NSRect {
        let size = handleSize
        let half = size / 2
        switch corner {
        case .topLeft:
            return NSRect(x: -half, y: bounds.maxY - half, width: size, height: size)
        case .topRight:
            return NSRect(x: bounds.maxX - half, y: bounds.maxY - half, width: size, height: size)
        case .bottomLeft:
            return NSRect(x: -half, y: -half, width: size, height: size)
        case .bottomRight:
            return NSRect(x: bounds.maxX - half, y: -half, width: size, height: size)
        }
    }

    // MARK: - Hit Testing

    /// Return nil for the interior so events pass through to apps underneath.
    /// Return self for border/handle regions so we can handle drag and resize.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)

        // Allow hits slightly outside bounds for the outer edge of the border hit zone
        let expandedBounds = bounds.insetBy(dx: -hitMargin, dy: -hitMargin)
        guard expandedBounds.contains(localPoint) else { return nil }

        if isOnHandle(localPoint) || isOnBorder(localPoint) {
            return self
        }
        return nil
    }

    private func isOnHandle(_ point: NSPoint) -> Bool {
        let expandedSize = handleSize + hitMargin
        for corner in [Corner.topLeft, .topRight, .bottomLeft, .bottomRight] {
            let rect = cornerRect(for: corner).insetBy(dx: -hitMargin / 2, dy: -hitMargin / 2)
            let expanded = NSRect(
                x: rect.origin.x - (expandedSize - rect.width) / 2,
                y: rect.origin.y - (expandedSize - rect.height) / 2,
                width: expandedSize,
                height: expandedSize
            )
            if expanded.contains(point) {
                return true
            }
        }
        return false
    }

    private func isOnBorder(_ point: NSPoint) -> Bool {
        let outerRect = bounds.insetBy(dx: -hitMargin, dy: -hitMargin)
        let innerRect = bounds.insetBy(dx: hitMargin, dy: hitMargin)
        return outerRect.contains(point) && !innerRect.contains(point)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        let location = convert(event.locationInWindow, from: nil)
        initialMouseLocation = window.convertPoint(toScreen: event.locationInWindow)
        initialFrame = window.frame
        dragType = determineDragType(at: location)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window else { return }
        let currentMouse = window.convertPoint(toScreen: event.locationInWindow)
        let dx = currentMouse.x - initialMouseLocation.x
        let dy = currentMouse.y - initialMouseLocation.y

        let minSize: CGFloat = 80

        switch dragType {
        case .move:
            window.setFrameOrigin(NSPoint(
                x: initialFrame.origin.x + dx,
                y: initialFrame.origin.y + dy
            ))

        case .resizeBottomLeft:
            let newWidth = max(minSize, initialFrame.width - dx)
            let newHeight = max(minSize, initialFrame.height - dy)
            let newX = initialFrame.origin.x + (initialFrame.width - newWidth)
            let newY = initialFrame.origin.y + (initialFrame.height - newHeight)
            window.setFrame(NSRect(x: newX, y: newY, width: newWidth, height: newHeight), display: true)

        case .resizeBottomRight:
            let newWidth = max(minSize, initialFrame.width + dx)
            let newHeight = max(minSize, initialFrame.height - dy)
            let newY = initialFrame.origin.y + (initialFrame.height - newHeight)
            window.setFrame(NSRect(x: initialFrame.origin.x, y: newY, width: newWidth, height: newHeight), display: true)

        case .resizeTopLeft:
            let newWidth = max(minSize, initialFrame.width - dx)
            let newHeight = max(minSize, initialFrame.height + dy)
            let newX = initialFrame.origin.x + (initialFrame.width - newWidth)
            window.setFrame(NSRect(x: newX, y: initialFrame.origin.y, width: newWidth, height: newHeight), display: true)

        case .resizeTopRight:
            let newWidth = max(minSize, initialFrame.width + dx)
            let newHeight = max(minSize, initialFrame.height + dy)
            window.setFrame(NSRect(x: initialFrame.origin.x, y: initialFrame.origin.y, width: newWidth, height: newHeight), display: true)

        case .resizeLeft:
            let newWidth = max(minSize, initialFrame.width - dx)
            let newX = initialFrame.origin.x + (initialFrame.width - newWidth)
            window.setFrame(NSRect(x: newX, y: initialFrame.origin.y, width: newWidth, height: initialFrame.height), display: true)

        case .resizeRight:
            let newWidth = max(minSize, initialFrame.width + dx)
            window.setFrame(NSRect(x: initialFrame.origin.x, y: initialFrame.origin.y, width: newWidth, height: initialFrame.height), display: true)

        case .resizeTop:
            let newHeight = max(minSize, initialFrame.height + dy)
            window.setFrame(NSRect(x: initialFrame.origin.x, y: initialFrame.origin.y, width: initialFrame.width, height: newHeight), display: true)

        case .resizeBottom:
            let newHeight = max(minSize, initialFrame.height - dy)
            let newY = initialFrame.origin.y + (initialFrame.height - newHeight)
            window.setFrame(NSRect(x: initialFrame.origin.x, y: newY, width: initialFrame.width, height: newHeight), display: true)

        case .none:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        dragType = .none
    }

    // MARK: - Cursor

    override func resetCursorRects() {
        let cSize = handleSize + hitMargin

        // Corner rects — resize cursor
        let blRect = NSRect(x: 0, y: 0, width: cSize, height: cSize)
        let brRect = NSRect(x: bounds.maxX - cSize, y: 0, width: cSize, height: cSize)
        let tlRect = NSRect(x: 0, y: bounds.maxY - cSize, width: cSize, height: cSize)
        let trRect = NSRect(x: bounds.maxX - cSize, y: bounds.maxY - cSize, width: cSize, height: cSize)

        addCursorRect(blRect, cursor: .crosshair)
        addCursorRect(brRect, cursor: .crosshair)
        addCursorRect(tlRect, cursor: .crosshair)
        addCursorRect(trRect, cursor: .crosshair)

        // Edge rects (between corners) — open hand for move/drag
        let topRect = NSRect(x: cSize, y: bounds.maxY - hitMargin, width: bounds.width - 2 * cSize, height: hitMargin * 2)
        let bottomRect = NSRect(x: cSize, y: -hitMargin, width: bounds.width - 2 * cSize, height: hitMargin * 2)
        let leftRect = NSRect(x: -hitMargin, y: cSize, width: hitMargin * 2, height: bounds.height - 2 * cSize)
        let rightRect = NSRect(x: bounds.maxX - hitMargin, y: cSize, width: hitMargin * 2, height: bounds.height - 2 * cSize)

        addCursorRect(topRect, cursor: .openHand)
        addCursorRect(bottomRect, cursor: .openHand)
        addCursorRect(leftRect, cursor: .openHand)
        addCursorRect(rightRect, cursor: .openHand)
    }

    // MARK: - Helpers

    private func determineDragType(at point: NSPoint) -> DragType {
        // Corner zones are square regions at each corner — these trigger resize
        let cornerZone = handleSize + hitMargin

        let inLeftCorner = point.x < cornerZone
        let inRightCorner = point.x > bounds.width - cornerZone
        let inBottomCorner = point.y < cornerZone
        let inTopCorner = point.y > bounds.height - cornerZone

        // Check corners first (resize)
        if inBottomCorner && inLeftCorner { return .resizeBottomLeft }
        if inBottomCorner && inRightCorner { return .resizeBottomRight }
        if inTopCorner && inLeftCorner { return .resizeTopLeft }
        if inTopCorner && inRightCorner { return .resizeTopRight }

        // Everything else on the border is a move (drag)
        return .move
    }
}
