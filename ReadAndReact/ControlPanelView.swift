//
//  ControlPanelView.swift
//  ReadAndReact
//
//  Created by TJ Togatapola on 4/28/26.
//

import SwiftUI

struct ControlPanelView: View {
    @EnvironmentObject var captureState: CaptureState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ReadAndReact")
                .font(.title)
                .fontWeight(.bold)

            // MARK: - Screenshot Settings
            GroupBox("Screenshot Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Interval (seconds):")
                        TextField("5", value: $captureState.intervalSeconds, format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                        Spacer()
                        Toggle("Overlay", isOn: $captureState.isOverlayVisible)
                            .onChange(of: captureState.isOverlayVisible) {
                                captureState.updateOverlayVisibility()
                            }
                    }

                    HStack {
                        Text("Save to:")
                        TextField("Path", text: $captureState.savePath)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1)
                        Button("Browse…") {
                            chooseSaveDirectory()
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            captureState.startCapture()
                        } label: {
                            Label("Play", systemImage: "play.fill")
                        }
                        .disabled(captureState.isCapturing)
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button {
                            captureState.stopCapture()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .disabled(!captureState.isCapturing)
                        .buttonStyle(.borderedProminent)
                        .tint(.red)

                        Button {
                            captureState.clearScreenshots()
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                        .disabled(captureState.isCapturing || captureState.screenshotCount == 0)
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }

                    Divider()

                    HStack {
                        Text("Screenshots: \(captureState.screenshotCount)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()

                        // Thumbnail indicator
                        if let thumbnail = captureState.lastScreenshotThumbnail {
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 75)
                                .border(Color.green, width: 2)
                                .shadow(radius: 2)
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 100, height: 75)
                                .overlay(
                                    Text("No capture")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                )
                        }
                    }
                }
                .padding(8)
            }

            // MARK: - LLM Configuration
            GroupBox("LLM Configuration") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Endpoint:")
                        TextField("http://localhost:8000", text: $captureState.llmEndpoint)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("Model:")
                        TextField("google/gemma-4-31b-it", text: $captureState.llmModel)
                            .textFieldStyle(.roundedBorder)
                    }

                    Text("Prompt:")
                    TextEditor(text: $captureState.llmPrompt)
                        .frame(minHeight: 80)
                        .font(.body)
                        .border(Color.gray.opacity(0.3), width: 1)

                    HStack {
                        Button {
                            captureState.sendToLLM()
                        } label: {
                            Label("Send to LLM", systemImage: "paperplane.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(captureState.screenshotCount == 0 || captureState.isSendingToLLM || captureState.llmPrompt.isEmpty)

                        if captureState.isSendingToLLM {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.leading, 4)
                        }

                        Spacer()
                    }
                }
                .padding(8)
            }

            // MARK: - LLM Response
            GroupBox("LLM Response") {
                ScrollView {
                    Text(captureState.llmResponse.isEmpty ? "No response yet." : captureState.llmResponse)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .foregroundColor(captureState.llmResponse.isEmpty ? .secondary : .primary)
                }
                .frame(minHeight: 120, maxHeight: 300)
                .padding(8)
            }

            // MARK: - Status
            HStack {
                Circle()
                    .fill(captureState.isCapturing ? Color.green : (captureState.isSendingToLLM ? Color.orange : Color.gray))
                    .frame(width: 8, height: 8)
                Text(captureState.statusMessage)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Spacer()
        }
        .padding()
    }

    private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            captureState.savePath = url.path
        }
    }
}
