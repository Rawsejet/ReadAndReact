//
//  ReadAndReactApp.swift
//  ReadAndReact
//
//  Created by TJ Togatapola on 4/28/26.
//

import SwiftUI

@main
struct ReadAndReactApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var captureState = CaptureState()

    var body: some Scene {
        Window("ReadAndReact Control Panel", id: "control-panel") {
            ControlPanelView()
                .environmentObject(captureState)
                .frame(minWidth: 480, minHeight: 600)
                .onAppear {
                    connectPanel()
                }
        }
        .defaultSize(width: 520, height: 700)
    }

    private func connectPanel() {
        // If the panel is already created, connect it now
        if let panel = appDelegate.overlayPanel {
            captureState.overlayPanel = panel
            print("Overlay panel connected to CaptureState")
        } else {
            // Panel not yet created — register a callback
            appDelegate.onPanelReady = { panel in
                captureState.overlayPanel = panel
                print("Overlay panel connected to CaptureState (via callback)")
            }
        }
    }
}
