//
//  AppDelegate.swift
//  ReadAndReact
//
//  Created by TJ Togatapola on 4/28/26.
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    var overlayPanel: OverlayPanel?

    /// Called back by ReadAndReactApp once CaptureState is ready
    var onPanelReady: ((OverlayPanel) -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request screen capture permission early
        let hasAccess = CGPreflightScreenCaptureAccess()
        if !hasAccess {
            CGRequestScreenCaptureAccess()
            print("Screen recording permission requested — user must grant it in System Settings.")
        } else {
            print("Screen recording permission already granted.")
        }

        // Create and show the overlay panel
        let panel = OverlayPanel()
        panel.orderFront(nil)
        self.overlayPanel = panel

        // Notify if anyone is waiting
        onPanelReady?(panel)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

