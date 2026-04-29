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
    static func send(
        screenshotDirectory: String,
        screenshotCount: Int,
        prompt: String,
        endpoint: String,
        model: String
    ) async throws -> String {
        // 1. Build the URL safely
        guard let baseURL = URL(string: endpoint) else {
            throw LLMError.invalidURL(endpoint)
        }
        let url = baseURL.appendingPathComponent("v1/chat/completions")

        // 2. Build the content items (Images then Text)
        var contentItems: [ChatContentItem] = []

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

            contentItems.append(.imageURL(url: dataURI))
        }

        guard !contentItems.isEmpty else {
            throw LLMError.noScreenshots
        }

        contentItems.append(.text(prompt))

        // 3. Construct the type-safe request body
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                .init(role: .user, content: contentItems)
            ],
            maxTokens: 4096
        )

        // 4. Perform the Network Request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer EMPTY", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 300
        
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw LLMError.serverError(statusCode: httpResponse.statusCode, body: body)
        }

        // 5. Parse the response using Codable
        do {
            let result = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            return result.choices.first?.message.content ?? ""
        } catch {
            throw LLMError.parseError(String(data: data, encoding: .utf8) ?? "Unknown decoding error")
        }
    }
}

// MARK: - Request/Response Models

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [Message]
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxTokens = "max_tokens"
    }
}

private struct Message: Encodable {
    let role: Role
    let content: [ChatContentItem]

    enum Role: String, Encodable {
        case user, assistant, system
    }
}

private enum ChatContentItem: Encodable {
    case text(String)
    case imageURL(url: String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageURL(let url):
            try container.encode("image_url", forKey: .type)
            let imageURLContainer = ImageURLContainer(url: url)
            try container.encode(imageURLContainer, forKey: .imageURL)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, text, imageURL = "image_url"
    }

    private struct ImageURLContainer: Encodable {
        let url: String
    }
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
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
