//
//  ScreenshotService.swift
//  ReadAndReact
//
//  Created by TJ Togatapola on 4/28/26.
//

import AppKit
import ScreenCaptureKit

/// Captures the screen region defined by the overlay panel,
/// excluding the overlay itself, using ScreenCaptureKit.
class ScreenshotService {

    private let overlayWindowNumber: Int

    init(overlayPanel: OverlayPanel?) {
        self.overlayWindowNumber = overlayPanel?.windowNumber ?? 0
    }

    /// Captures the screen content underneath the overlay panel's frame.
    ///
    /// First hides the overlay, captures the rect using SCScreenshotManager,
    /// then re-shows the overlay. This guarantees the overlay border is not
    /// included in the screenshot.
    func captureRegion(of panel: OverlayPanel) async -> NSImage? {
        // Hide the overlay so it doesn't appear in the capture
        panel.orderOut(nil)

        // Small delay to let the window server
        // remove the overlay from the composited screen
        try? await Task.sleep(for: .milliseconds(50))

        do {
            // Panel frame is in AppKit coordinates (origin bottom-left).
            // SCScreenshotManager.captureImage(in:) takes a rect in
            // screen-space points (origin top-left for CG).
            let panelFrame = panel.frame
            guard let screen = NSScreen.main else {
                panel.orderFront(nil)
                return nil
            }
            let screenHeight = screen.frame.height

            let captureRect = CGRect(
                x: panelFrame.origin.x,
                y: screenHeight - panelFrame.origin.y - panelFrame.height,
                width: panelFrame.width,
                height: panelFrame.height
            )

            let cgImage = try await SCScreenshotManager.captureImage(in: captureRect)

            // Re-show the overlay
            panel.orderFront(nil)

            return NSImage(cgImage: cgImage, size: NSSize(width: panelFrame.width, height: panelFrame.height))
        } catch {
            print("ScreenshotService error: \(error)")
            // Make sure overlay comes back even on error
            panel.orderFront(nil)
            return nil
        }
    }
}
