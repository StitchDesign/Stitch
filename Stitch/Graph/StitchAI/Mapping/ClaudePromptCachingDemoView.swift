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
    
    // Large system prompt to ensure it meets the minimum cacheable token requirement (1024+ tokens)
    private let largeSystemPrompt = """
    You are Claude, an AI assistant created by Anthropic. You are helpful, harmless, and honest. 
    
    Your primary objective is to be as helpful as possible to humans while being safe and truthful. You should provide accurate, relevant, and useful information to the best of your knowledge and abilities.
    
    Key principles that guide your responses:
    1. Accuracy: Provide factual and correct information. If you're uncertain about something, acknowledge your uncertainty.
    2. Helpfulness: Focus on being genuinely useful to the human asking the question.
    3. Safety: Avoid providing information that could be used to cause harm.
    4. Honesty: Be truthful and transparent about your capabilities and limitations.
    5. Respect: Treat all humans with respect and dignity.
    
    When answering questions:
    - Be clear and concise while being thorough
    - Use examples when helpful
    - Break down complex topics into understandable parts
    - Ask clarifying questions if the request is ambiguous
    - Provide multiple perspectives on controversial topics
    - Cite sources when possible and relevant
    
    Areas where you excel:
    - General knowledge and information lookup
    - Writing assistance and editing
    - Analysis and reasoning
    - Mathematical calculations and problem solving
    - Code writing and debugging in many programming languages
    - Creative tasks like brainstorming and storytelling
    - Language translation and learning support
    - Research assistance and summarization
    
    Important limitations to remember:
    - Your training data has a knowledge cutoff, so very recent information may not be available
    - You cannot browse the internet or access real-time information
    - You cannot remember previous conversations unless they're part of the current session
    - You cannot learn or update your knowledge from conversations
    - You cannot access external systems, files, or databases
    - You cannot perform actions in the physical world
    
    Communication style:
    - Adapt your tone to match the context and user's needs
    - Be professional yet approachable
    - Use clear, well-structured language
    - Provide relevant examples and analogies when helpful
    - Be patient and supportive when helping with learning
    - Show enthusiasm for interesting topics while remaining balanced
    
    Ethics and safety guidelines:
    - Do not provide instructions for illegal activities
    - Avoid generating harmful, offensive, or inappropriate content
    - Respect intellectual property and copyright
    - Do not pretend to be a human or claim to have human experiences
    - Be transparent about being an AI
    - Protect user privacy and confidentiality
    
    Remember: Your goal is to be maximally helpful while remaining safe, honest, and respectful. Always strive to provide value to the human you're assisting.
    """
    
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
        
        // Create request body with proper cache control structure
        // Only cache the system prompt (which is large and static)
        // Do NOT cache the user input (which changes between requests)
        let systemPromptWithCache: [String: Any] = [
            "type": "text",
            "text": largeSystemPrompt,
            "cache_control": ["type": "ephemeral"]
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
                    
                    // Extract cache performance headers
                    self.analyzeCachePerformance(headers: httpResponse.allHeaderFields, duration: duration, requestNumber: self.requestCount)
                    
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
    
    private func analyzeCachePerformance(headers: [AnyHashable: Any], duration: TimeInterval, requestNumber: Int) {
        var cacheInfo: [String] = []
        
        cacheInfo.append("🔍 Request #\(requestNumber) completed in \(String(format: "%.2f", duration))s")
        
        // Look for cache-related headers
        var cacheCreated = false
        var cacheHit = false
        var inputTokens: Int? = nil
        var outputTokens: Int? = nil
        var cacheCreationInputTokens: Int? = nil
        var cacheReadInputTokens: Int? = nil
        
        for (key, value) in headers {
            let keyString = String(describing: key).lowercased()
            let valueString = String(describing: value)
            
            // Check for usage headers
            if keyString.contains("anthropic-billing-input-tokens") {
                inputTokens = Int(valueString)
            } else if keyString.contains("anthropic-billing-output-tokens") {
                outputTokens = Int(valueString)
            } else if keyString.contains("anthropic-billing-cache-creation-input-tokens") {
                cacheCreationInputTokens = Int(valueString)
                cacheCreated = true
            } else if keyString.contains("anthropic-billing-cache-read-input-tokens") {
                cacheReadInputTokens = Int(valueString)
                cacheHit = true
            }
        }
        
        // Analyze cache performance
        if cacheCreated && cacheHit {
            cacheInfo.append("💾 CACHE: Both creation and hit detected")
            if let created = cacheCreationInputTokens, let read = cacheReadInputTokens {
                let savings = created - read
                let savingsPercent = (Double(savings) / Double(created)) * 100
                cacheInfo.append("   📊 Savings: \(savings) tokens (\(String(format: "%.1f", savingsPercent))%)")
            }
        } else if cacheCreated {
            cacheInfo.append("🆕 CACHE: New cache created")
            if let tokens = cacheCreationInputTokens {
                cacheInfo.append("   📝 Created: \(tokens) tokens")
            }
        } else if cacheHit {
            cacheInfo.append("⚡ CACHE: Cache hit! Major savings")
            if let tokens = cacheReadInputTokens {
                cacheInfo.append("   📖 Read: \(tokens) tokens")
            }
        } else {
            cacheInfo.append("❌ CACHE: No cache headers detected - cache may not be working")
        }
        
        // Log overall token usage
        if let input = inputTokens, let output = outputTokens {
            cacheInfo.append("🎯 Tokens: \(input) input + \(output) output = \(input + output) total")
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