//
//  Stitch_AI_Metrics.swift
//  Stitch AI Metrics
//
//  Created by Elliot Boschwitz on 9/23/25.
//

import Testing
import SwiftUI
@testable import Stitch

@Suite("Claude Streaming Performance Metrics")
struct Stitch_AI_Metrics {
    
    // Sample base64 images for testing - realistic small images
    static let sampleImages = [
        // Small JPEG image (1x1 pixel)
        "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAACAAIDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k=",
        
        // Another small test image - 2x2 pixel
        "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAACAA0DASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k="
    ]
    
    // MARK: - Helper Methods
    
    /// Create a test document for Claude requests
    @MainActor
    static func createTestDocument() -> StitchDocumentViewModel {
        return StitchDocumentViewModel.createEmpty()
    }
    
    /// Check if Claude API key is configured
    static func hasValidAPIKey() -> Bool {
        guard let apiKey = StitchStore.claudeAPIKey, !apiKey.isEmpty else {
            print("⚠️ Claude API key not found in StitchStore.claudeAPIKey")
            return false
        }
        print("✅ Claude API key configured")
        return true
    }
    
    // MARK: - Performance Tests
    
    @Test("Claude Streaming Performance with Images - 5 Iterations")
    func claudeStreamingPerformanceMetrics() async throws {
        // Skip test if API key not configured
        guard Self.hasValidAPIKey() else {
            print("❌ Skipping test - Claude API key not configured in StitchStore")
            return
        }
        
        print("🚀 Starting Claude streaming performance metrics collection")
        print("📊 Running 5 iterations per image sample...")
        
        let document = await Self.createTestDocument()
        var allResults: [(String, TimeInterval, Int, String?)] = []
        
        // Test with each sample image
        for (imageIndex, base64Image) in Self.sampleImages.enumerated() {
            print("\n🖼️ Testing with sample image \(imageIndex + 1)")
            
            // Run 5 iterations for each image
            for iteration in 1...5 {
                let testName = "Image\(imageIndex + 1)_Iter\(iteration)"
                let startTime = Date()
                
                do {
                    // Call the actual makeClaudeStreamingRequest function
                    let response = try await makeClaudeStreamingRequest(
                        previewWindowPrompt: "Analyze this image and create appropriate processing nodes",
                        userPrompt: "What do you see in this image? Create nodes to process and transform this visual content.",
                        base64Image: base64Image,
                        model: .claude4Sonnet,
                        document: document
                    )
                    
                    let duration = Date().timeIntervalSince(startTime)
                    allResults.append((testName, duration, response.count, nil))
                    
                    let throughput = Double(response.count) / duration
                    print("✅ \(testName): \(String(format: "%.2f", duration))s, \(response.count) chars, \(String(format: "%.1f", throughput)) chars/sec")
                    
                    // Verify response quality
                    #expect(!response.isEmpty, "Response should not be empty")
                    #expect(response.count > 10, "Response should contain meaningful content")
                    
                } catch {
                    let duration = Date().timeIntervalSince(startTime)
                    let errorMessage = error.localizedDescription
                    allResults.append((testName, duration, 0, errorMessage))
                    
                    print("❌ \(testName): \(error)")
                }
                
                // Small delay between requests to be respectful to the API
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            }
        }
        
        // Generate comprehensive performance report
        Self.generatePerformanceReport(results: allResults)
        
        // Verify we got at least some successful results
        let successfulResults = allResults.filter { $0.3 == nil }
        #expect(successfulResults.count > 0, "At least some requests should succeed")
        
        // Performance assertions
        if !successfulResults.isEmpty {
            let avgDuration = successfulResults.reduce(0) { $0 + $1.1 } / Double(successfulResults.count)
            #expect(avgDuration < 30.0, "Average response time should be reasonable (under 30s)")
            
            let avgResponseLength = successfulResults.reduce(0) { $0 + $1.2 } / successfulResults.count
            #expect(avgResponseLength > 50, "Responses should have meaningful content")
        }
    }
    
    @Test("Claude Streaming Text-Only Performance Comparison")
    func claudeStreamingTextOnlyComparison() async throws {
        guard Self.hasValidAPIKey() else {
            print("❌ Skipping test - Claude API key not configured")
            return
        }
        
        print("📝 Running text-only performance comparison...")
        
        let document = await Self.createTestDocument()
        var textResults: [(String, TimeInterval, Int, String?)] = []
        
        // Run 5 text-only requests for comparison
        for iteration in 1...5 {
            let testName = "TextOnly_\(iteration)"
            let startTime = Date()
            
            do {
                let response = try await makeClaudeStreamingRequest(
                    previewWindowPrompt: "Create basic text processing nodes",
                    userPrompt: "Create a text node that displays 'Hello World' with custom styling and formatting options",
                    base64Image: nil, // No image for text-only comparison
                    model: .claude4Sonnet,
                    document: document
                )
                
                let duration = Date().timeIntervalSince(startTime)
                textResults.append((testName, duration, response.count, nil))
                
                print("✅ \(testName): \(String(format: "%.2f", duration))s, \(response.count) chars")
                
                #expect(!response.isEmpty, "Text-only response should not be empty")
                
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                textResults.append((testName, duration, 0, error.localizedDescription))
                
                print("❌ \(testName): \(error)")
            }
            
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        }
        
        // Generate text-only comparison report
        Self.generateTextOnlyReport(results: textResults)
        
        let successfulTextResults = textResults.filter { $0.3 == nil }
        #expect(successfulTextResults.count > 0, "At least some text-only requests should succeed")
    }
    
    @Test("Claude Streaming Quick Performance Check")
    func claudeStreamingQuickCheck() async throws {
        guard Self.hasValidAPIKey() else {
            print("❌ Skipping quick check - Claude API key not configured")
            return
        }
        
        print("⚡ Running quick Claude streaming performance check...")
        
        let document = await Self.createTestDocument()
        let startTime = Date()
        
        do {
            let response = try await makeClaudeStreamingRequest(
                previewWindowPrompt: "Create a simple node",
                userPrompt: "Create a basic text node with 'Quick Test'",
                base64Image: nil,
                model: .claude4Sonnet,
                document: document
            )
            
            let duration = Date().timeIntervalSince(startTime)
            let throughput = Double(response.count) / duration
            
            print("✅ Quick check completed: \(String(format: "%.2f", duration))s, \(response.count) chars, \(String(format: "%.1f", throughput)) chars/sec")
            
            // Basic performance expectations
            #expect(!response.isEmpty, "Response should not be empty")
            #expect(duration < 30.0, "Quick check should complete in reasonable time")
            #expect(response.count > 10, "Should get meaningful response")
            
        } catch {
            print("❌ Quick check failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Reporting Functions
    
    static func generatePerformanceReport(results: [(String, TimeInterval, Int, String?)]) {
        print("\n📊 CLAUDE STREAMING PERFORMANCE METRICS REPORT")
        print(String(repeating: "=", count: 60))
        
        guard !results.isEmpty else {
            print("❌ No results to analyze")
            return
        }
        
        let successfulResults = results.filter { $0.3 == nil }
        let failedResults = results.filter { $0.3 != nil }
        
        print("📈 Overall Statistics:")
        print("   • Total requests: \(results.count)")
        print("   • Successful: \(successfulResults.count)")
        print("   • Failed: \(failedResults.count)")
        
        if !successfulResults.isEmpty {
            let durations = successfulResults.map { $0.1 }
            let responseLengths = successfulResults.map { $0.2 }
            
            let avgDuration = durations.reduce(0, +) / Double(durations.count)
            let minDuration = durations.min() ?? 0
            let maxDuration = durations.max() ?? 0
            let avgResponseLength = responseLengths.reduce(0, +) / responseLengths.count
            
            print("   • Success rate: \(String(format: "%.1f", Double(successfulResults.count) / Double(results.count) * 100))%")
            print("   • Average duration: \(String(format: "%.2f", avgDuration))s")
            print("   • Fastest request: \(String(format: "%.2f", minDuration))s")
            print("   • Slowest request: \(String(format: "%.2f", maxDuration))s")
            print("   • Average response length: \(avgResponseLength) characters")
            
            let avgThroughput = Double(avgResponseLength) / avgDuration
            print("   • Average throughput: \(String(format: "%.1f", avgThroughput)) chars/sec")
            
            // Calculate consistency (standard deviation)
            let variance = durations.map { pow($0 - avgDuration, 2) }.reduce(0, +) / Double(durations.count)
            let stdDev = sqrt(variance)
            print("   • Response time consistency: ±\(String(format: "%.2f", stdDev))s")
            
            // Group by image sample
            let imageGroups = Dictionary(grouping: successfulResults) { result in
                if result.0.hasPrefix("Image1") { return "Sample Image 1" }
                else if result.0.hasPrefix("Image2") { return "Sample Image 2" }
                else { return "Other" }
            }
            
            if imageGroups.count > 1 {
                print("\n🖼️ Performance by Image Sample:")
                for (imageName, imageResults) in imageGroups.sorted(by: { $0.key < $1.key }) {
                    let imageDurations = imageResults.map { $0.1 }
                    let imageAvg = imageDurations.reduce(0, +) / Double(imageDurations.count)
                    let imageMin = imageDurations.min() ?? 0
                    let imageMax = imageDurations.max() ?? 0
                    print("   • \(imageName): avg \(String(format: "%.2f", imageAvg))s, range \(String(format: "%.2f", imageMin))s-\(String(format: "%.2f", imageMax))s")
                }
            }
            
            print("\n🎯 Performance Insights:")
            if avgDuration < 3.0 {
                print("   ✅ Excellent performance - responses under 3 seconds")
            } else if avgDuration < 5.0 {
                print("   👍 Good performance - responses under 5 seconds")
            } else if avgDuration < 10.0 {
                print("   ⚠️  Moderate performance - consider optimization")
            } else {
                print("   🐌 Slow performance - needs investigation")
            }
            
            if stdDev < 0.5 {
                print("   🎯 Excellent consistency - very stable response times")
            } else if stdDev < 1.0 {
                print("   👍 Good consistency - reasonably stable response times")
            } else {
                print("   ⚠️  Variable response times - investigate network conditions")
            }
        }
        
        if !failedResults.isEmpty {
            print("\n❌ Error Analysis:")
            let errorGroups = Dictionary(grouping: failedResults, by: { $0.3 ?? "Unknown error" })
            for (error, errorResults) in errorGroups {
                print("   • \(error): \(errorResults.count) occurrence(s)")
            }
        }
        
        print("\n📄 CSV Export Data:")
        print("Test Name,Duration (s),Response Length,Throughput (chars/s),Error")
        for (name, duration, length, error) in results {
            let throughput = length > 0 ? Double(length) / duration : 0
            let errorText = error ?? ""
            print("\(name),\(String(format: "%.2f", duration)),\(length),\(String(format: "%.1f", throughput)),\(errorText)")
        }
    }
    
    static func generateTextOnlyReport(results: [(String, TimeInterval, Int, String?)]) {
        print("\n📝 TEXT-ONLY PERFORMANCE COMPARISON")
        print(String(repeating: "=", count: 45))
        
        let successfulResults = results.filter { $0.3 == nil }
        
        guard !successfulResults.isEmpty else {
            print("❌ No successful text-only results to analyze")
            return
        }
        
        let durations = successfulResults.map { $0.1 }
        let avgDuration = durations.reduce(0, +) / Double(durations.count)
        let minDuration = durations.min() ?? 0
        let maxDuration = durations.max() ?? 0
        
        print("📈 Text-Only Performance:")
        print("   • Average duration: \(String(format: "%.2f", avgDuration))s")
        print("   • Fastest: \(String(format: "%.2f", minDuration))s")
        print("   • Slowest: \(String(format: "%.2f", maxDuration))s")
        print("   • Success rate: \(successfulResults.count)/\(results.count)")
        
        print("\n💡 Compare these results with image request metrics to measure image processing overhead.")
        print("   • Expected: Text-only requests should be faster due to no image processing")
        print("   • Use this baseline to understand image analysis impact on response times")
    }
}
