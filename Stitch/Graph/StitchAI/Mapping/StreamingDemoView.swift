//
//  StreamingDemoView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/19/25.
//

import SwiftUI
import Foundation
import Shimmer

// MARK: Relevant OpenAI docs, the response.reasoning_* objects for the Responses endpoint: https://platform.openai.com/docs/api-reference/responses_streaming/response/reasoning_text

// Shimmer helpers defined in `InsertNodeMenuSearchbar.swift`

struct StreamingDemoView: View {
    
    @State private var prompt: String = "In SwiftUI, make 100 rectangles, different colors."
    @State private var streamingResponse: String = ""
    @State private var reasoningStepsList: [String] = []
    @State private var accumulatedReasoning: String = ""
    @State private var extractedHeadersCount: Int = 0
    @State private var isStreaming: Bool = false
    @FocusState private var isFocused: Bool
    @FocusState private var apiKeyFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    private var lightModeShimmerConfig: CustomShimmerConfig {
        CustomShimmerConfig(
            tint: .white.opacity(0.15),
            highlight: .white,
            blur: 5
        )
    }
    
    private var reasoningSteps: String {
        let k = reasoningStepsList.joined() //.joined(separator: "\n")
        print("reasoningSteps: \(k)")
        return k
        
    }
    
    private let selectedModel: String = "o4-mini"
    
    private var searchBar: some View {
        ZStack(alignment: .leading) {
            if isStreaming {
                // Show Text view when streaming for content transitions
                Text(prompt)
                    .contentTransition(.numericText())
                    .animation(.default, value: self.prompt)
                    .frame(height: INSERT_NODE_MENU_SEARCH_BAR_HEIGHT)
                    .frame(width: INSERT_NODE_MENU_WIDTH, alignment: .leading)
                    .padding(.leading, 16)
                    .padding(.trailing, 60)
                    .font(.system(size: 24))
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                    .modifier(HybridShimmerModifier(colorScheme: colorScheme, lightModeConfig: lightModeShimmerConfig))
                    .overlay(alignment: .center) {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.5)
                        }
                        .padding(.trailing, 20)
                    }
            } else {
                // Show TextField when not streaming for input
                TextField("Enter AI prompt...", text: $prompt)
                    .focused($isFocused)
                    .frame(height: INSERT_NODE_MENU_SEARCH_BAR_HEIGHT)
                    .frame(width: INSERT_NODE_MENU_WIDTH, alignment: .leading)
                    .padding(.leading, 16)
                    .padding(.trailing, 60)
                    .font(.system(size: 24))
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .disableAutocorrection(true)
                    .onSubmit {
                        startStreaming()
                    }
                    .onAppear {
                        self.isFocused = true
                    }
                    .overlay(alignment: .center) {
                        HStack {
                            Spacer()
                            Button(action: startStreaming) {
                                Image(systemName: "play.fill")
                            }
                            .frame(width: 36, height: 36)
                            .buttonStyle(.borderless)
                            .disabled(apiKey.isEmpty)
                        }
                        .padding(.trailing, 20)
                    }
            }
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .frame(height: INSERT_NODE_MENU_SEARCH_BAR_HEIGHT)
        .frame(width: INSERT_NODE_MENU_WIDTH, alignment: .leading)
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
        accumulatedReasoning = ""
        extractedHeadersCount = 0
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
        
        withAnimation {
            prompt = "Thinking..."
        }
        
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
                                                // Accumulate deltas unchanged
                                                accumulatedReasoning += delta
                                                
                                                // Extract just the first header (text between first ** markers)
                                                let boldPattern = #"\*\*(.*?)\*\*"#
                                                let regex = try? NSRegularExpression(pattern: boldPattern, options: [])
                                                let range = NSRange(location: 0, length: accumulatedReasoning.utf16.count)
                                                
                                                if let matches = regex?.matches(in: accumulatedReasoning, options: [], range: range),
                                                   let firstMatch = matches.first,
                                                   let headerRange = Range(firstMatch.range(at: 1), in: accumulatedReasoning) {
                                                    let headerText = String(accumulatedReasoning[headerRange])
                                                    print("🧠 EXTRACTED_HEADER: '\(headerText)'")
                                                    
                                                    withAnimation {
                                                        prompt = headerText
                                                    }
                                                }
                                            }
                                        }
                                    
                                    case "response.reasoning_summary_part.done":
                                        print("🧠 Received reasoning summary part done")
                                    
                                    case "response.reasoning_summary_text.done":
                                        print("🧠 Received reasoning summary text done")
                                    
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


