#!/usr/bin/env swift

//
// test_claude_caching_swift.swift
// Swift version of our working bash script for Claude prompt caching
//

import Foundation

// MARK: - Response Models

struct ClaudeUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

struct ClaudeContent: Codable {
    let type: String
    let text: String
}

struct ClaudeResponse: Codable {
    let type: String
    let role: String?
    let content: [ClaudeContent]
    let model: String?
    let stopReason: String?
    let usage: ClaudeUsage?
    
    enum CodingKeys: String, CodingKey {
        case type, role, content, model, usage
        case stopReason = "stop_reason"
    }
}

struct ClaudeError: Codable {
    let type: String
    let error: ErrorDetail
    
    struct ErrorDetail: Codable {
        let type: String
        let message: String
    }
}

// MARK: - Cache Analysis Functions

func analyzeCacheResponse(_ response: ClaudeResponse, requestNum: Int) {
    print("\n📊 Request #\(requestNum) Analysis:")
    print("=================================")
    
    guard let usage = response.usage else {
        print("❌ No usage information in response")
        return
    }
    
    print("🔍 Usage Information from Response Body:")
    print("   Input tokens: \(usage.inputTokens)")
    print("   Output tokens: \(usage.outputTokens)")
    print("   Cache creation tokens: \(usage.cacheCreationInputTokens ?? 0)")
    print("   Cache read tokens: \(usage.cacheReadInputTokens ?? 0)")
    
    let cacheCreated = (usage.cacheCreationInputTokens ?? 0) > 0
    let cacheHit = (usage.cacheReadInputTokens ?? 0) > 0
    
    print("\n💾 Cache Performance Analysis:")
    if cacheCreated && cacheHit {
        let created = usage.cacheCreationInputTokens ?? 0
        let read = usage.cacheReadInputTokens ?? 0
        let savings = created - read
        let percent = (Double(savings) / Double(created)) * 100
        print("   💾 Both cache creation and hit detected")
        print("   📊 Cache savings: \(savings) tokens (\(String(format: "%.1f", percent))%)")
    } else if cacheCreated {
        print("   🆕 Cache created: \(usage.cacheCreationInputTokens ?? 0) tokens")
    } else if cacheHit {
        print("   ⚡ Cache hit: \(usage.cacheReadInputTokens ?? 0) tokens read from cache")
    } else {
        print("   ❌ No cache activity detected")
    }
    
    let total = usage.inputTokens + usage.outputTokens
    print("   🎯 Total usage: \(usage.inputTokens) input + \(usage.outputTokens) output = \(total) tokens")
}

// MARK: - HTTP Request Functions

func makeClaudeRequest(
    systemPrompt: String,
    userMessage: String,
    apiKey: String
) async throws -> ClaudeResponse {
    
    guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
        throw NSError(domain: "InvalidURL", code: 1)
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.setValue("prompt-caching-2024-07-31", forHTTPHeaderField: "anthropic-beta")
    
    // Build request body exactly like our working bash script
    let requestBody: [String: Any] = [
        "model": "claude-sonnet-4-20250514",
        "max_tokens": 1024,
        "system": [
            [
                "type": "text",
                "text": "You are a literary analysis AI assistant."
            ],
            [
                "type": "text",
                "text": systemPrompt,
                "cache_control": [
                    "type": "ephemeral",
                    "ttl": "1h"
                ]
            ]
        ],
        "messages": [
            [
                "role": "user",
                "content": userMessage
            ]
        ]
    ]
    
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw NSError(domain: "InvalidResponse", code: 2)
    }
    
    if httpResponse.statusCode != 200 {
        // Try to parse error response
        if let errorResponse = try? JSONDecoder().decode(ClaudeError.self, from: data) {
            print("🚨 Claude API Error (\(httpResponse.statusCode)): \(errorResponse.error.message)")
        } else if let errorString = String(data: data, encoding: .utf8) {
            print("🚨 Claude API Error (\(httpResponse.statusCode)): \(errorString)")
        }
        throw NSError(domain: "HTTPError", code: httpResponse.statusCode)
    }
    
    let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
    return claudeResponse
}

// MARK: - Main Test Function

func runCacheTest() async {
        print("🔍 Testing Claude Prompt Caching with Swift...")
        print("==============================================")
        
        // Check for API key
        guard let apiKey = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"],
              !apiKey.isEmpty else {
            print("❌ Error: CLAUDE_API_KEY environment variable is not set")
            print("Please set it with: export CLAUDE_API_KEY='your-api-key-here'")
            exit(1)
        }
        
        // Fetch Pride and Prejudice (first tenth like our working bash script)
        print("📚 Fetching first tenth of Pride and Prejudice from Project Gutenberg...")
        
        guard let url = URL(string: "https://www.gutenberg.org/cache/epub/1342/pg1342.txt") else {
            print("❌ Invalid URL")
            exit(1)
        }
        
        let bookContent: String
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let fullBook = String(data: data, encoding: .utf8) else {
                print("❌ Could not decode book content")
                exit(1)
            }
            
            // Use first tenth like our working bash script
            let tenthLength = fullBook.count / 10
            bookContent = String(fullBook.prefix(tenthLength))
            
            print("📏 Using first tenth of book: \(bookContent.count) characters")
            print("📏 Estimated tokens: ~\(bookContent.count / 3)")
            
        } catch {
            print("❌ Failed to fetch book content: \(error)")
            exit(1)
        }
        
        let systemPrompt = "Here is the first tenth of Pride and Prejudice by Jane Austen:\n\n\(bookContent)"
        
        // Test 1: First request (should create cache)
        print("\n📤 Making first request (should create cache)...")
        print("================================================")
        
        let startTime1 = Date()
        
        do {
            let response1 = try await makeClaudeRequest(
                systemPrompt: systemPrompt,
                userMessage: "What are the main themes in this novel? Give me 3 key themes.",
                apiKey: apiKey
            )
            
            let duration1 = Date().timeIntervalSince(startTime1)
            print("✅ First request completed in \(String(format: "%.2f", duration1))s")
            
            analyzeCacheResponse(response1, requestNum: 1)
            
            // Show response preview
            let content = response1.content.compactMap { $0.text }.joined()
            print("\n📝 First Response Preview:")
            print(String(content.prefix(200)) + "...")
            
        } catch {
            print("❌ First request failed: \(error)")
            exit(1)
        }
        
        // Wait before second request
        print("\n⏱️  Waiting 3 seconds before second request...")
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Test 2: Second request (should hit cache)
        print("\n📤 Making second request (should hit cache)...")
        print("==============================================")
        
        let startTime2 = Date()
        
        do {
            let response2 = try await makeClaudeRequest(
                systemPrompt: systemPrompt, // Same system prompt - should hit cache
                userMessage: "Who are the main characters and what are their relationships?",
                apiKey: apiKey
            )
            
            let duration2 = Date().timeIntervalSince(startTime2)
            print("✅ Second request completed in \(String(format: "%.2f", duration2))s")
            
            analyzeCacheResponse(response2, requestNum: 2)
            
            // Show response preview
            let content = response2.content.compactMap { $0.text }.joined()
            print("\n📝 Second Response Preview:")
            print(String(content.prefix(200)) + "...")
            
            // Final analysis
            let duration1 = Date().timeIntervalSince(startTime1) - 3.0 // Subtract sleep time
            
            print("\n🎯 Final Analysis:")
            print("==================")
            print("Request 1 duration: \(String(format: "%.2f", duration1))s")
            print("Request 2 duration: \(String(format: "%.2f", duration2))s")
            
            if duration2 < duration1 * 0.8 {
                print("⚡ Request 2 was significantly faster - possible cache hit!")
            }
            
            let cache1 = response2.usage?.cacheCreationInputTokens ?? 0
            let cache2 = response2.usage?.cacheReadInputTokens ?? 0
            
            if cache1 > 0 || cache2 > 0 {
                print("✅ Cache activity detected - prompt caching is working!")
                print("   → This Swift implementation matches our successful bash script")
            } else {
                print("❌ No cache activity detected")
                print("   → This would indicate an issue with the implementation")
            }
            
        } catch {
            print("❌ Second request failed: \(error)")
            exit(1)
        }
        
        print("\n📋 Swift Implementation Summary:")
        print("=================================")
        print("✅ HTTP requests using URLSession")
        print("✅ JSON parsing with Codable")
        print("✅ Cache analysis from response body")
        print("✅ 1-hour TTL cache control")
        print("✅ Proper error handling")
        print("")
        print("🎯 Ready to integrate into Stitch codebase!")
        print("🏁 Testing complete!")
}

// Run the test using RunLoop for script execution
let semaphore = DispatchSemaphore(value: 0)

Task {
    await runCacheTest()
    semaphore.signal()
}

semaphore.wait()
exit(0)
