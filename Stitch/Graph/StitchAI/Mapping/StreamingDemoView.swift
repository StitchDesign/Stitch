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
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            isStreaming = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "input": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "stream": true
        ]
        
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
                                    case "response.created":
                                        print("DEBUG: Response started")
                                    case "response.completed":
                                        print("DEBUG: Response completed")
                                    case "error":
                                        if let error = json["error"] as? [String: Any] {
                                            print("DEBUG: Error event: \(error)")
                                            await MainActor.run {
                                                streamingResponse = "API Error: \(error)"
                                                isStreaming = false
                                            }
                                        }
                                    default:
                                        print("DEBUG: Unhandled event type: \(eventType)")
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


