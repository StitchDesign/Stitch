//
//  StreamingDemoView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/19/25.
//

import SwiftUI
import Foundation

// MARK: Relevant OpenAI docs, the response.reasoning_* objects for the Responses endpoint: https://platform.openai.com/docs/api-reference/responses_streaming/response/reasoning_text

struct StreamingDemoView: View {
    
    @State private var apiKey: String = ""
    @State private var prompt: String = "In SwiftUI, create 100 rectangles that are all different colors."
    @State private var streamingResponse: String = ""
    @State private var reasoningStepsList: [String] = []
    @State private var isStreaming: Bool = false
    @FocusState private var isFocused: Bool
    @FocusState private var apiKeyFocused: Bool
    
    private var reasoningSteps: String {
        reasoningStepsList.joined(separator: "\n")
    }
    
    private let selectedModel: String = "o4-mini"
    
    private var searchBar: some View {
        VStack(spacing: .zero) {
            TextField("Enter AI prompt...", text: $prompt)
                .focused($isFocused)
                .frame(height: INSERT_NODE_MENU_SEARCH_BAR_HEIGHT)
                .frame(width: INSERT_NODE_MENU_WIDTH)
                .padding(.leading, 16)
                .padding(.trailing, 60)
                .overlay(alignment: .center) {
                    HStack {
                        Spacer()
                        if isStreaming {
                            ProgressView()
                                .scaleEffect(1.5)
                        } else {
                            Button(action: startStreaming) {
                                Image(systemName: "play.fill")
                            }
                            .frame(width: 36, height: 36)
                            .buttonStyle(.borderless)
                            .disabled(apiKey.isEmpty)
                        }
                    }
                    .padding(.trailing, 20)
                }
                .font(.system(size: 24))
                .disableAutocorrection(true)
                .onSubmit {
                    startStreaming()
                }
                .onAppear {
                    self.isFocused = true
                }
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var reasoningSection: some View {
        Group {
            if isStreaming && reasoningSteps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("🤔 Thinking...")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    HStack {
                        ProgressView()
                        Text("Processing your request...")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .frame(minHeight: 60)
                }
            }
        }
    }
    
    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Response:")
                .font(.headline)
            
            ScrollView {
                Text(streamingResponse.isEmpty ? "Response will appear here..." : streamingResponse)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 150)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("OpenAI Responses API Demo")
                .font(.largeTitle)
                .padding(.top)
                        
            searchBar
            
            reasoningSection
            
            responseSection
            
            Spacer()
        }
        .padding()
    }
    
    private func startStreaming() {
        guard !apiKey.isEmpty else { return }
        
        isStreaming = true
        streamingResponse = ""
        reasoningStepsList = []
        isFocused = false
        apiKeyFocused = false
        
        Task {
            await performStreamingRequest()
        }
    }
    
    @MainActor
    private func performStreamingRequest() async {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            isStreaming = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var requestBody: [String: Any] = [
            "model": selectedModel,
            "input": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "stream": true
        ]
        
        // Add reasoning parameter for reasoning models
        requestBody["reasoning"] = [
            "summary": "auto",
            "effort": "medium"
        ]
        
        prompt = "Thinking..."
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    streamingResponse = "Error: No HTTP response"
                    isStreaming = false
                }
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                await MainActor.run {
                    streamingResponse = "Error: HTTP \(httpResponse.statusCode)"
                    isStreaming = false
                }
                return
            }
            
            for try await line in asyncBytes.lines {
                if line.hasPrefix("data: ") {
                    let dataString = String(line.dropFirst(6))
                    
                    if dataString == "[DONE]" {
                        break
                    }
                    
                    if let data = dataString.data(using: .utf8) {
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                // Handle Responses API streaming events
                                if let eventType = json["type"] as? String {
                                    switch eventType {
                                    case "response.output_text.delta":
                                        if let delta = json["delta"] as? String {
                                            await MainActor.run {
                                                streamingResponse += delta
                                            }
                                        }
                                    
                                    case "response.reasoning_summary_text.delta":
                                        if let delta = json["delta"] as? String {
                                            print("🧠 REASONING_DELTA: '\(delta)'")
                                            await MainActor.run {
                                                // Accumulate reasoning deltas in real-time
                                                if reasoningStepsList.isEmpty {
                                                    reasoningStepsList.append(delta)
                                                } else {
                                                    reasoningStepsList[reasoningStepsList.count - 1] += delta
                                                }
                                                // Update prompt to show reasoning steps
                                                if !reasoningSteps.isEmpty {
                                                    prompt = reasoningSteps
                                                }
                                            }
                                        }
                                    
                                    case "response.reasoning_summary_part.done":
                                        print("🧠 Received reasoning summary part")
                                        if let part = json["part"] as? [String: Any],
                                           let text = part["text"] as? String {
                                            print("🧠 Reasoning part text: \(text)")
                                            await MainActor.run {
                                                if reasoningStepsList.last != text {
                                                    reasoningStepsList.append(text)
                                                    print("🧠 Added reasoning step, total count: \(reasoningStepsList.count)")
                                                }
                                                // Update prompt to show reasoning steps
                                                if !reasoningSteps.isEmpty {
                                                    prompt = reasoningSteps
                                                }
                                            }
                                        }
                                    
                                    case "response.reasoning_summary_text.done":
                                        print("🧠 Received reasoning summary text")
                                        if let text = json["text"] as? String {
                                            print("🧠 Reasoning text: \(text)")
                                            await MainActor.run {
                                                if reasoningStepsList.last != text {
                                                    reasoningStepsList.append(text)
                                                    print("🧠 Added reasoning step, total count: \(reasoningStepsList.count)")
                                                }
                                                // Update prompt to show reasoning steps
                                                if !reasoningSteps.isEmpty {
                                                    prompt = reasoningSteps
                                                }
                                            }
                                        }
                                    
                                    case "response.completed":
                                        await MainActor.run {
                                            isStreaming = false
                                        }
                                    
                                    case "error":
                                        if let error = json["error"] as? [String: Any] {
                                            await MainActor.run {
                                                streamingResponse = "API Error: \(error)"
                                                isStreaming = false
                                            }
                                        }
                                    case "response.output_item.done":
                                        print("🧠 Received output item done")
                                        // Extract reasoning summary from completed item
                                        if let outputItem = json["output_item"] as? [String: Any],
                                           let outputType = outputItem["type"] as? String,
                                           outputType == "reasoning",
                                           let summary = outputItem["summary"] as? [[String: Any]] {
                                            print("🧠 Found reasoning output item")
                                            var summaryText = ""
                                            for summaryPart in summary {
                                                if let text = summaryPart["text"] as? String {
                                                    summaryText += text
                                                }
                                            }
                                            if !summaryText.isEmpty {
                                                print("🧠 Output item reasoning: \(summaryText)")
                                                await MainActor.run {
                                                    if reasoningStepsList.last != summaryText {
                                                        reasoningStepsList.append(summaryText)
                                                        print("🧠 Added reasoning step from output item, total count: \(reasoningStepsList.count)")
                                                    }
                                                    // Update prompt to show reasoning steps
                                                    if !reasoningSteps.isEmpty {
                                                        prompt = reasoningSteps
                                                    }
                                                }
                                            }
                                        }
                                    
                                    default:
                                        // Log any reasoning-related events we might be missing
                                        if eventType.contains("reasoning") {
                                            print("🧠 Unhandled reasoning event: \(eventType)")
                                            print("🧠 Event data: \(json)")
                                        }
                                    }
                                }
                            }
                        } catch {
                            // Ignore JSON parsing errors
                        }
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                streamingResponse = "Error: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isStreaming = false
        }
    }
    
}


