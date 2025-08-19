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
    @State private var prompt: String = "Write a short poem about coding"
    @State private var streamingResponse: String = ""
    @State private var isStreaming: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("OpenAI Streaming Demo")
                .font(.largeTitle)
                .padding()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("API Key:")
                    .font(.headline)
                SecureField("Enter OpenAI API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Prompt:")
                    .font(.headline)
                TextField("Enter your prompt", text: $prompt, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
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
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: 600)
    }
    
    private func startStreaming() {
        guard !apiKey.isEmpty else { return }
        
        isStreaming = true
        streamingResponse = ""
        
        Task {
            await performStreamingRequest()
        }
    }
    
    @MainActor
    private func performStreamingRequest() async {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            isStreaming = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "stream": true,
            "max_tokens": 1000
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                await MainActor.run {
                    streamingResponse = "Error: Invalid response"
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
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let firstChoice = choices.first,
                               let delta = firstChoice["delta"] as? [String: Any],
                               let content = delta["content"] as? String {
                                
                                await MainActor.run {
                                    streamingResponse += content
                                }
                            }
                        } catch {
                            // Skip malformed JSON chunks
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


