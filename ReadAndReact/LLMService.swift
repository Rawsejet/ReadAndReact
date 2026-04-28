//
//  LLMService.swift
//  ReadAndReact
//
//  Created by TJ Togatapola on 4/28/26.
//

import Foundation
import AppKit

/// Sends screenshots and a prompt to a vLLM server using the OpenAI-compatible
/// /v1/chat/completions endpoint with base64-encoded images.
struct LLMService {

    /// Sends all screenshots from the save directory to the vLLM endpoint with the given prompt.
    /// Screenshots are sent in order (SS_1, SS_2, ...) as base64-encoded images in a single user message.
    static func send(
        screenshotDirectory: String,
        screenshotCount: Int,
        prompt: String,
        endpoint: String,
        model: String
    ) async throws -> String {
        // Build the endpoint URL for chat completions
        let baseURL = endpoint.hasSuffix("/")
            ? String(endpoint.dropLast())
            : endpoint
        let urlString = "\(baseURL)/v1/chat/completions"

        guard let url = URL(string: urlString) else {
            throw LLMError.invalidURL(urlString)
        }

        // Build the content array: images first (in order), then the text prompt
        var contentItems: [[String: Any]] = []

        for i in 1...screenshotCount {
            let filename = "SS_\(i).png"
            let filePath = (screenshotDirectory as NSString).appendingPathComponent(filename)
            let fileURL = URL(fileURLWithPath: filePath)

            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }

            let imageData = try Data(contentsOf: fileURL)
            let base64String = imageData.base64EncodedString()
            let dataURI = "data:image/png;base64,\(base64String)"

            contentItems.append([
                "type": "image_url",
                "image_url": ["url": dataURI]
            ])
        }

        guard !contentItems.isEmpty else {
            throw LLMError.noScreenshots
        }

        // Add the text prompt
        contentItems.append([
            "type": "text",
            "text": prompt
        ])

        // Build the request body
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": contentItems
                ]
            ],
            "max_tokens": 4096
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer EMPTY", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        // Long timeout — large vision models can take a while
        request.timeoutInterval = 300

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw LLMError.serverError(statusCode: httpResponse.statusCode, body: body)
        }

        // Parse the OpenAI-compatible response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.parseError(String(data: data, encoding: .utf8) ?? "")
        }

        return content
    }
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case invalidURL(String)
    case noScreenshots
    case invalidResponse
    case serverError(statusCode: Int, body: String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid endpoint URL: \(url)"
        case .noScreenshots:
            return "No screenshot files found to send"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code, let body):
            return "Server error (\(code)): \(body)"
        case .parseError(let raw):
            return "Failed to parse response: \(raw.prefix(200))"
        }
    }
}
