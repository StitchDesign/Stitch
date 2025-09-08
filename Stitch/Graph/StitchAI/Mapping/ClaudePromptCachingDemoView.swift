//
//  ClaudePromptCachingDemoView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/7/25.
//

import SwiftUI

struct ClaudePromptCachingDemoView: View {
    @State private var userInput = "Tell me about the benefits of renewable energy"
    @State private var responseText = "No request made yet"
    @State private var isLoading = false
    @State private var cachePerformance = ""
    @State private var requestCount = 0
    
    // Load the actual austen_system_prompt.txt from app resources for realistic cache testing
    private var austenSystemPrompt: String {
        guard let path = Bundle.main.path(forResource: "austen_system_prompt", ofType: "txt"),
              let content = try? String(contentsOfFile: path) else {
            return "Error: Could not load austen_system_prompt.txt from app resources"
        }
        return content
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Claude Prompt Caching Demo")
                .font(.title)
                .padding()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("User Input:")
                    .font(.headline)
                TextField("Enter your question", text: $userInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            HStack(spacing: 15) {
                Button("Make First Request") {
                    makeClaudeRequest(isFirstRequest: true)
                }
                .disabled(isLoading)
                
                Button("Make Second Request") {
                    makeClaudeRequest(isFirstRequest: false)
                }
                .disabled(isLoading)
            }
            
            if isLoading {
                ProgressView("Making request...")
                    .padding()
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Cache Performance:")
                    .font(.headline)
                Text(cachePerformance)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Response:")
                        .font(.headline)
                    Text(responseText)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func makeClaudeRequest(isFirstRequest: Bool) {
        guard let secrets = try? Secrets(),
              let claudeAPIKey = secrets.claudeAPIKey,
              !claudeAPIKey.isEmpty else {
            responseText = "❌ Claude API key not configured"
            return
        }
        
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            responseText = "❌ Invalid Claude API URL"
            return
        }
        
        isLoading = true
        requestCount += 1
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        // Add beta header for prompt caching support
        request.setValue("prompt-caching-2024-07-31", forHTTPHeaderField: "anthropic-beta")
        // Create request body with proper cache control structure
        // Only cache the system prompt (which is large and static)
        // Do NOT cache the user input (which changes between requests)
        let systemPromptWithCache: [String: Any] = [
            "type": "text",
            "text": austenSystemPrompt,
            "cache_control": ["type": "ephemeral", "ttl": "1h"]
        ]
        
        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1024,
            "system": [systemPromptWithCache], // System prompt with cache control
            "messages": [
                [
                    "role": "user",
                    "content": userInput // User input is NOT cached (as it should be)
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let startTime = Date()
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    let duration = Date().timeIntervalSince(startTime)
                    
                    if let error = error {
                        self.responseText = "❌ Request failed: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        self.responseText = "❌ Invalid response"
                        return
                    }
                    
                    // Extract cache performance from response body (not headers)
                    self.analyzeCachePerformanceFromData(data: data, duration: duration, requestNumber: self.requestCount)
                    
                    guard let data = data else {
                        self.responseText = "❌ No data received"
                        return
                    }
                    
                    if httpResponse.statusCode == 200 {
                        self.handleSuccessResponse(data: data, duration: duration, isFirstRequest: isFirstRequest)
                    } else {
                        self.handleErrorResponse(data: data, statusCode: httpResponse.statusCode)
                    }
                }
            }.resume()
            
        } catch {
            isLoading = false
            responseText = "❌ Failed to encode request: \(error.localizedDescription)"
        }
    }
    
    private func analyzeCachePerformanceFromData(data: Data?, duration: TimeInterval, requestNumber: Int) {
        var cacheInfo: [String] = []
        
        cacheInfo.append("🔍 Request #\(requestNumber) completed in \(String(format: "%.2f", duration))s")
        
        guard let data = data else {
            cacheInfo.append("❌ No response data to analyze")
            self.cachePerformance = cacheInfo.joined(separator: "\n")
            return
        }
        
        do {
            // Parse response JSON to extract usage information
            guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let usage = jsonResponse["usage"] as? [String: Any] else {
                cacheInfo.append("❌ Could not parse usage data from response")
                self.cachePerformance = cacheInfo.joined(separator: "\n")
                return
            }
            
            // Extract cache and token data from usage object
            let inputTokens = usage["input_tokens"] as? Int ?? 0
            let outputTokens = usage["output_tokens"] as? Int ?? 0
            let cacheCreationInputTokens = usage["cache_creation_input_tokens"] as? Int ?? 0
            let cacheReadInputTokens = usage["cache_read_input_tokens"] as? Int ?? 0
            
            cacheInfo.append("📊 Usage Data from Response Body:")
            cacheInfo.append("   → Input tokens: \(inputTokens)")
            cacheInfo.append("   → Output tokens: \(outputTokens)")
            cacheInfo.append("   → Cache creation: \(cacheCreationInputTokens)")
            cacheInfo.append("   → Cache read: \(cacheReadInputTokens)")
            
            // Analyze cache performance
            let cacheCreated = cacheCreationInputTokens > 0
            let cacheHit = cacheReadInputTokens > 0
            
            if cacheCreated && cacheHit {
                cacheInfo.append("💾 CACHE: Both creation and hit detected")
                let savings = cacheCreationInputTokens - cacheReadInputTokens
                let savingsPercent = (Double(savings) / Double(cacheCreationInputTokens)) * 100
                cacheInfo.append("   📊 Savings: \(savings) tokens (\(String(format: "%.1f", savingsPercent))%)")
            } else if cacheCreated {
                cacheInfo.append("🆕 CACHE: New cache created")
                cacheInfo.append("   📝 Created: \(cacheCreationInputTokens) tokens")
            } else if cacheHit {
                cacheInfo.append("⚡ CACHE: Cache hit! Major token savings")
                cacheInfo.append("   📖 Read: \(cacheReadInputTokens) tokens from cache")
            } else {
                cacheInfo.append("❌ CACHE: No cache activity detected")
                cacheInfo.append("   → Cache may not be available for your account")
                cacheInfo.append("   → Or system prompt may be too small (<1024 tokens)")
            }
            
            // Log overall token usage
            let totalTokens = inputTokens + outputTokens
            cacheInfo.append("🎯 Total: \(inputTokens) input + \(outputTokens) output = \(totalTokens) tokens")
            
        } catch {
            cacheInfo.append("❌ Error parsing response JSON: \(error.localizedDescription)")
        }
        
        self.cachePerformance = cacheInfo.joined(separator: "\n")
    }
    
    private func handleSuccessResponse(data: Data, duration: TimeInterval, isFirstRequest: Bool) {
        do {
            if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = jsonResponse["content"] as? [[String: Any]],
               let firstContent = content.first,
               let text = firstContent["text"] as? String {
                
                let requestType = isFirstRequest ? "First" : "Second"
                self.responseText = """
                ✅ \(requestType) Request Successful (\(String(format: "%.2f", duration))s)
                
                \(text)
                """
            } else {
                self.responseText = "✅ Request successful but couldn't parse response"
            }
        } catch {
            self.responseText = "✅ Request successful but JSON parsing failed: \(error.localizedDescription)"
        }
    }
    
    private func handleErrorResponse(data: Data, statusCode: Int) {
        if let errorString = String(data: data, encoding: .utf8) {
            responseText = "❌ Request failed (\(statusCode)): \(errorString)"
        } else {
            responseText = "❌ Request failed with status code: \(statusCode)"
        }
    }
}

#Preview {
    ClaudePromptCachingDemoView()
}
