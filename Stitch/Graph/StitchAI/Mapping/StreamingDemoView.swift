//
//  StreamingDemoView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/19/25.
//

import SwiftUI
import Foundation

struct StreamingDemoView: View {
    
    @State private var apiKey: String = ""
    
    @State private var prompt: String = "In SwiftUI, create 100 rectangles that are all different colors."
    
    @State private var selectedModel: String = "o4-mini"
    
    @State private var streamingResponse: String = ""
    @State private var reasoningSteps: String = ""
    
    @State private var showReasoningSteps: Bool = true
    
    @State private var isStreaming: Bool = false
    
    private let availableModels = [
        "o3-mini": "o3-mini (Reasoning)",
        "o4-mini": "o4-mini (Reasoning)"
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("OpenAI Responses API Demo")
                .font(.largeTitle)
                .padding()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("API Key:")
                    .font(.headline)
                SecureField("Enter OpenAI API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Model:")
                    .font(.headline)
                Picker("Select Model", selection: $selectedModel) {
                    ForEach(availableModels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        Text(value).tag(key)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Prompt:")
                    .font(.headline)
                TextField("Enter your prompt", text: $prompt, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
            }
            
            if isReasoningModel(selectedModel) {
                Toggle("Show Thinking Steps", isOn: $showReasoningSteps)
                    .font(.headline)
            }
            
            Button(action: startStreaming) {
                HStack {
                    if isStreaming {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isStreaming ? "Streaming..." : "Start Streaming")
                }
            }
            .disabled(apiKey.isEmpty || isStreaming)
            .buttonStyle(.borderedProminent)
            
            HStack {
                if isReasoningModel(selectedModel) && showReasoningSteps && !reasoningSteps.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("🤔 Thinking Steps:")
                            .font(.headline)
                            .foregroundColor(.blue)
                        ScrollView {
                            Text(reasoningSteps)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                .font(.system(.body, design: .monospaced))
                        }
                        .frame(minHeight: 150)
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Response:")
                        .font(.headline)
                    ScrollView {
                        Text(streamingResponse.isEmpty ? "Response will appear here..." : streamingResponse)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(minHeight: 200)
                }
            }
           
            
            Spacer()
        }
        .padding()
//        .frame(maxWidth: 600)
    }
    
    private func startStreaming() {
        guard !apiKey.isEmpty else { return }
        
        isStreaming = true
        streamingResponse = ""
        reasoningSteps = ""
        
        Task {
            await performStreamingRequest()
        }
    }
    
    private func isReasoningModel(_ model: String) -> Bool {
        true
        // return model.contains("o3") || model.contains("o4")
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
        if isReasoningModel(selectedModel) {
            requestBody["reasoning"] = [
                "summary": "auto",
                "effort": "medium"
            ]
        }
        
        print("DEBUG: Request URL: \(url)")
        print("DEBUG: Request Body: \(requestBody)")
        
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
            
            print("DEBUG: HTTP Status Code: \(httpResponse.statusCode)")
            print("DEBUG: HTTP Headers: \(httpResponse.allHeaderFields)")
            
            guard httpResponse.statusCode == 200 else {
                // Read error response body
                let errorData = try await URLSession.shared.data(for: request).0
                let errorString = String(data: errorData, encoding: .utf8) ?? "No error body"
                print("DEBUG: Error response body: \(errorString)")
                
                await MainActor.run {
                    streamingResponse = "Error: HTTP \(httpResponse.statusCode)\nHeaders: \(httpResponse.allHeaderFields)\nBody: \(errorString)"
                    isStreaming = false
                }
                return
            }
            
            for try await line in asyncBytes.lines {
                print("DEBUG: Raw line received: '\(line)'")
                
                if line.hasPrefix("data: ") {
                    let dataString = String(line.dropFirst(6))
                    print("DEBUG: Data string: '\(dataString)'")
                    
                    if dataString == "[DONE]" {
                        print("DEBUG: Received [DONE], breaking")
                        break
                    }
                    
                    if let data = dataString.data(using: .utf8) {
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                print("DEBUG: Parsed JSON: \(json)")
                                
                                // Handle Responses API streaming events
                                if let eventType = json["type"] as? String {
                                    print("DEBUG: Event type: \(eventType)")
                                    
                                    switch eventType {
                                    case "response.output_text.delta":
                                        if let delta = json["delta"] as? String {
                                            print("DEBUG: Text delta: '\(delta)'")
                                            await MainActor.run {
                                                streamingResponse += delta
                                            }
                                        }
                                    // Reasoning Summary Part Events
                                    case "response.reasoning_summary_part.added":
                                        print("DEBUG: 🧠 Reasoning summary part added: \(json)")
                                    case "response.reasoning_summary_part.done":
                                        print("DEBUG: 🧠 Reasoning summary part done: \(json)")
                                        if let part = json["part"] as? [String: Any],
                                           let text = part["text"] as? String {
                                            print("DEBUG: 🧠 Reasoning summary part text: '\(text)'")
                                            await MainActor.run {
                                                reasoningSteps += text
                                            }
                                        }
                                    
                                    // Reasoning Summary Text Events  
                                    case "response.reasoning_summary_text.delta":
                                        if let delta = json["delta"] as? String {
                                            print("DEBUG: 🧠 Reasoning summary text delta: '\(delta)'")
                                            await MainActor.run {
                                                reasoningSteps += delta
                                            }
                                        }
                                    case "response.reasoning_summary_text.done":
                                        if let text = json["text"] as? String {
                                            print("DEBUG: 🧠 Reasoning summary text done: '\(text)'")
                                            await MainActor.run {
                                                reasoningSteps = text
                                            }
                                        }
                                    
                                    // Raw Reasoning Text Events
                                    case "response.reasoning_text.delta":
                                        if let delta = json["delta"] as? String {
                                            print("DEBUG: 🧠 Reasoning text delta: '\(delta)'")
                                            await MainActor.run {
                                                // Only use raw reasoning if we don't have summary
                                                if reasoningSteps.isEmpty {
                                                    reasoningSteps += delta
                                                }
                                            }
                                        }
                                    case "response.reasoning_text.done":
                                        if let text = json["text"] as? String {
                                            print("DEBUG: 🧠 Reasoning text done: '\(text)'")
                                            await MainActor.run {
                                                // Only use raw reasoning if we don't have summary
                                                if reasoningSteps.isEmpty {
                                                    reasoningSteps = text
                                                }
                                            }
                                        }
                                    case "response.created":
                                        print("DEBUG: Response started")
                                        // Don't set initial thinking message - only show if we actually get reasoning events
                                    case "response.completed":
                                        print("DEBUG: Response completed")
                                        await MainActor.run {
                                            isStreaming = false
                                        }
                                    case "error":
                                        if let error = json["error"] as? [String: Any] {
                                            print("DEBUG: Error event: \(error)")
                                            await MainActor.run {
                                                streamingResponse = "API Error: \(error)"
                                                isStreaming = false
                                            }
                                        }
                                    // Additional reasoning and output events
                                    case "response.output_item.added":
                                        print("DEBUG: Output item added: \(json)")
                                        // Check if this is a reasoning item
                                        if let outputItem = json["output_item"] as? [String: Any],
                                           let outputType = outputItem["type"] as? String,
                                           outputType == "reasoning" {
                                            print("DEBUG: 🧠 REASONING ITEM DETECTED!")
                                        }
                                    case "response.output_item.done":
                                        print("DEBUG: Output item done: \(json)")
                                        // Extract reasoning summary from completed item
                                        if let outputItem = json["output_item"] as? [String: Any],
                                           let outputType = outputItem["type"] as? String,
                                           outputType == "reasoning",
                                           let summary = outputItem["summary"] as? [[String: Any]] {
                                            var summaryText = ""
                                            for summaryPart in summary {
                                                if let text = summaryPart["text"] as? String {
                                                    summaryText += text
                                                }
                                            }
                                            if !summaryText.isEmpty {
                                                print("DEBUG: 🧠 REASONING SUMMARY: '\(summaryText)'")
                                                await MainActor.run {
                                                    reasoningSteps = summaryText
                                                }
                                            }
                                        }
                                    case "response.content_part.added":
                                        print("DEBUG: Content part added: \(json)")
                                    case "response.content_part.done":
                                        print("DEBUG: Content part done: \(json)")
                                    case "response.text.done":
                                        print("DEBUG: Text done: \(json)")
                                    case "response.refusal.delta":
                                        print("DEBUG: Refusal delta: \(json)")
                                    case "response.refusal.done":
                                        print("DEBUG: Refusal done: \(json)")
                                    default:
                                        print("DEBUG: ⚠️  UNHANDLED EVENT TYPE: \(eventType)")
                                        print("DEBUG: 📋 FULL EVENT DATA: \(json)")
                                        
                                        // Check if there's any reasoning-related content in unhandled events
                                        if eventType.contains("reasoning") || eventType.contains("thinking") || eventType.contains("chain") {
                                            print("DEBUG: 🧠 POTENTIAL REASONING EVENT DETECTED!")
                                        }
                                    }
                                } else {
                                    print("DEBUG: No 'type' field found in JSON")
                                }
                            }
                        } catch {
                            print("DEBUG: JSON parsing error: \(error)")
                            print("DEBUG: Failed to parse data: '\(dataString)'")
                        }
                    }
                } else if !line.isEmpty {
                    print("DEBUG: Non-data line: '\(line)'")
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


