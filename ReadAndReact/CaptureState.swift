//
//  CaptureState.swift
//  ReadAndReact
//
//  Created by TJ Togatapola on 4/28/26.
//

import SwiftUI
import Combine

/// Observable state model shared between the control panel and capture engine.
@MainActor
class CaptureState: ObservableObject {

    @Published var intervalSeconds: Int = 5
    @Published var isCapturing: Bool = false
    @Published var savePath: String = {
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/ReadAndReact_Screenshots")
        return desktop.path
    }()
    @Published var screenshotCount: Int = 0
    @Published var lastScreenshotThumbnail: NSImage? = nil
    @Published var llmPrompt: String = ""
    @Published var llmEndpoint: String = "http://localhost:8000"
    @Published var llmModel: String = "google/gemma-4-31b-it"
    @Published var llmResponse: String = ""
    @Published var isSendingToLLM: Bool = false
    @Published var statusMessage: String = "Ready"

    /// Set by AppDelegate after the overlay panel is created
    var overlayPanel: OverlayPanel?

    private var captureTimer: Timer?
    private var screenshotService: ScreenshotService?

    // MARK: - Capture Control

    func startCapture() {
        guard !isCapturing else { return }
        guard let panel = overlayPanel else {
            statusMessage = "Error: Overlay panel not available"
            print("startCapture failed: overlayPanel is nil")
            return
        }
        print("startCapture: panel frame = \(panel.frame), savePath = \(savePath)")

        // Check screen recording permission
        if !CGPreflightScreenCaptureAccess() {
            statusMessage = "⚠ Screen recording permission not granted. Go to System Settings > Privacy & Security > Screen Recording, enable this app, then restart it."
            print("WARNING: Screen recording permission not granted")
            CGRequestScreenCaptureAccess()
            return
        }

        // Reset counter
        screenshotCount = 0
        isCapturing = true
        statusMessage = "Capturing..."

        // Ensure save directory exists
        try? FileManager.default.createDirectory(
            atPath: savePath,
            withIntermediateDirectories: true
        )

        screenshotService = ScreenshotService(overlayPanel: panel)

        // Take one immediately, then schedule repeating
        Task { await takeScreenshot() }
        captureTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalSeconds), repeats: true) { _ in
            Task { @MainActor [weak self] in
                await self?.takeScreenshot()
            }
        }
    }

    func stopCapture() {
        captureTimer?.invalidate()
        captureTimer = nil
        isCapturing = false
        statusMessage = "Stopped. \(screenshotCount) screenshot\(screenshotCount == 1 ? "" : "s") taken."
    }

    // MARK: - Screenshot

    private func takeScreenshot() async {
        guard let panel = overlayPanel, let service = screenshotService else { return }

        screenshotCount += 1
        let filename = "SS_\(screenshotCount).png"
        let fullPath = (savePath as NSString).appendingPathComponent(filename)

        if let image = await service.captureRegion(of: panel) {
            // Save as PNG
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                statusMessage = "Error: could not convert screenshot to PNG"
                return
            }
            do {
                let fileURL = URL(fileURLWithPath: fullPath)
                try pngData.write(to: fileURL)
                lastScreenshotThumbnail = image
                statusMessage = "Captured \(filename)"
                print("Saved screenshot to: \(fullPath)")
            } catch {
                statusMessage = "Error saving \(filename): \(error.localizedDescription)"
                print("Save error: \(error)")
            }
        } else {
            statusMessage = "Failed to capture screenshot. Check screen recording permission in System Settings > Privacy & Security > Screen Recording."
            print("captureRegion returned nil — screen recording permission may be missing")
        }
    }

    // MARK: - LLM

    func sendToLLM() {
        guard !isSendingToLLM else { return }
        guard screenshotCount > 0 else {
            statusMessage = "No screenshots to send"
            return
        }
        guard !llmPrompt.isEmpty else {
            statusMessage = "Please enter a prompt"
            return
        }

        isSendingToLLM = true
        llmResponse = ""
        statusMessage = "Sending \(screenshotCount) screenshot(s) to LLM..."

        Task {
            do {
                let response = try await LLMService.send(
                    screenshotDirectory: savePath,
                    screenshotCount: screenshotCount,
                    prompt: llmPrompt,
                    endpoint: llmEndpoint,
                    model: llmModel
                )
                llmResponse = response
                statusMessage = "LLM response received"
            } catch {
                llmResponse = "Error: \(error.localizedDescription)"
                statusMessage = "LLM request failed"
            }
            isSendingToLLM = false
        }
    }
}
