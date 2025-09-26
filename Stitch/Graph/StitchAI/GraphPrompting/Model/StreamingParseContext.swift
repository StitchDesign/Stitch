//
//  StreamingParseContext.swift
//  Stitch
//
//  Created by Claude on 9/25/25.
//

import Foundation

/// Tracks token accumulation and parse timing for eager streaming updates
struct StreamingParseContext {
    /// Total tokens received in this streaming session
    var totalTokenCount: Int = 0

    /// Token count at last successful parse attempt
    var lastParseTokenCount: Int = 0

    /// Number of parse attempts made during streaming
    var parseAttemptCount: Int = 0

    /// Number of successful parse attempts
    var successfulParseCount: Int = 0

    /// Token threshold for triggering eager parsing
    let eagerParseThreshold: Int

    init(eagerParseThreshold: Int = 300) {
        self.eagerParseThreshold = eagerParseThreshold
    }

    /// Determines if we should attempt an eager parse based on token accumulation
    mutating func shouldAttemptParse(newTokens: String) -> Bool {
        totalTokenCount += newTokens.count
        let tokensSinceLastParse = totalTokenCount - lastParseTokenCount

        if tokensSinceLastParse >= eagerParseThreshold {
            log("🔄 StreamingParseContext: Triggering eager parse at \(totalTokenCount) tokens (\(tokensSinceLastParse) since last)")
            return true
        }

        return false
    }

    /// Records the result of a parse attempt
    mutating func recordParseAttempt(success: Bool, tokenCount: Int? = nil) {
        parseAttemptCount += 1

        if success {
            successfulParseCount += 1
            lastParseTokenCount = tokenCount ?? totalTokenCount
            log("📊 StreamingParseContext: Parse #\(parseAttemptCount) SUCCESS - Success rate: \(successfulParseCount)/\(parseAttemptCount) (\(String(format: "%.1f", Double(successfulParseCount) / Double(parseAttemptCount) * 100))%)")
        } else {
            log("⚠️ StreamingParseContext: Parse #\(parseAttemptCount) FAILED - Success rate: \(successfulParseCount)/\(parseAttemptCount) (\(String(format: "%.1f", Double(successfulParseCount) / Double(parseAttemptCount) * 100))%)")
        }
    }

    /// Returns current streaming statistics
    func getStats() -> StreamingStats {
        return StreamingStats(
            totalTokens: totalTokenCount,
            parseAttempts: parseAttemptCount,
            successfulParses: successfulParseCount,
            successRate: parseAttemptCount > 0 ? Double(successfulParseCount) / Double(parseAttemptCount) : 0.0
        )
    }
}

/// Statistics about streaming parse performance
struct StreamingStats {
    let totalTokens: Int
    let parseAttempts: Int
    let successfulParses: Int
    let successRate: Double // 0.0 to 1.0

    var successRatePercentage: String {
        return String(format: "%.1f%%", successRate * 100)
    }
}

/// Result of attempting to parse streaming content
enum StreamingParseResult {
    case success(SwiftSyntaxActionsResult)
    case failed(Error)
    case incomplete(String) // Partial content that couldn't be parsed yet
}

extension StreamingParseContext {
    /// Attempts to parse the accumulated content, handling incomplete syntax gracefully
    @MainActor
    static func attemptParse(_ accumulatedContent: String, isComplete: Bool = false, document: StitchDocumentViewModel) async -> StreamingParseResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Show first 100 characters for debugging
        let contentPreview = accumulatedContent.prefix(100)
        log("🔄 Attempting to parse \(accumulatedContent.count) characters: \"\(contentPreview)\(accumulatedContent.count > 100 ? "..." : "")\"")

        do {
            // Use existing SwiftUI parser
            let codeParserResult = SwiftUIViewVisitor.parseSwiftUICode(accumulatedContent)

            // If we successfully parsed, convert to actions
            let actionsResult = try await codeParserResult.deriveStitchActions(
                bindingDeclarations: codeParserResult.bindingDeclarations,
                document: document // Use provided document
            )

            let parseTime = CFAbsoluteTimeGetCurrent() - startTime
            log("✅ Parse SUCCESS in \(String(format: "%.2f", parseTime * 1000))ms - Found \(actionsResult.graphData.patchNodes.count) patch nodes, \(actionsResult.graphData.layer_data_list.count) layer groups")

            // Debug: Log node IDs to track stability
            let nodeIds = actionsResult.graphData.patchNodes.map { $0.id }
            log("✅   Patch node IDs: \(nodeIds)")

            let layerIds = actionsResult.graphData.layer_data_list.map { UUID($0.node_id) ?? UUID() }
            log("✅   Layer IDs: \(layerIds)")

            return .success(actionsResult)

        } catch {
            let parseTime = CFAbsoluteTimeGetCurrent() - startTime

            if isComplete {
                // If this was supposed to be complete content, it's a real error
                log("❌ Parse FAILED (complete content) in \(String(format: "%.2f", parseTime * 1000))ms: \(error)")
                return .failed(error)
            } else {
                // During streaming, parse failures are expected for incomplete content
                log("⏳ Parse incomplete in \(String(format: "%.2f", parseTime * 1000))ms (expected during streaming): \(error)")
                return .incomplete(String(describing: error))
            }
        }
    }
}
