//
//  StreamingParseContext.swift
//  Stitch
//
//  Created by Claude on 9/25/25.
//

import Foundation

/// Tracks token accumulation and parse timing for eager streaming updates
@MainActor
class StreamingParseContext: @unchecked Sendable {
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

    /// Queue of pending parse results waiting to be applied
    private var pendingResults: [(result: SwiftSyntaxActionsResult, isStreaming: Bool)] = []

    /// Whether an animation is currently in progress
    private var isAnimating: Bool = false

    init(eagerParseThreshold: Int = 500) {
        self.eagerParseThreshold = eagerParseThreshold
    }

    /// Determines if we should attempt an eager parse based on token accumulation
    func shouldAttemptParse(newTokens: String) -> Bool {
        totalTokenCount += newTokens.count
        let tokensSinceLastParse = totalTokenCount - lastParseTokenCount

        if tokensSinceLastParse >= eagerParseThreshold {
            log("🔄 StreamingParseContext: Triggering eager parse at \(totalTokenCount) tokens (\(tokensSinceLastParse) since last)")
            return true
        }

        return false
    }

    /// Records the result of a parse attempt
    func recordParseAttempt(success: Bool, tokenCount: Int? = nil) {
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

    /// Adds a parse result to the queue for processing
    func enqueue(_ result: SwiftSyntaxActionsResult, isStreaming: Bool = true) {
        pendingResults.append((result: result, isStreaming: isStreaming))
        log("📥 StreamingParseContext: Enqueued parse result (streaming: \(isStreaming)). Queue size: \(pendingResults.count)")
    }

    /// Checks if we can apply the next result (no animation in progress)
    func canProcessNext() -> Bool {
        return !isAnimating && !pendingResults.isEmpty
    }

    /// Dequeues and returns the next result to process, marking animation as in progress
    func dequeueNext() -> (result: SwiftSyntaxActionsResult, isStreaming: Bool)? {
        guard canProcessNext() else { return nil }

        let item = pendingResults.removeFirst()
        isAnimating = true
        log("📤 StreamingParseContext: Dequeued parse result (streaming: \(item.isStreaming)). Queue size: \(pendingResults.count), animation started")
        return item
    }

    /// Marks animation as complete, allowing next result to be processed
    func markAnimationComplete() {
        isAnimating = false
        log("✅ StreamingParseContext: Animation complete. Queue size: \(pendingResults.count)")
    }

    /// Processes the queue, applying results with 1 second delay between animations
    func processQueue(document: StitchDocumentViewModel) {
        guard let item = dequeueNext() else { return }

        // Apply the result immediately
        Task { @MainActor in
            var mutableResult = item.result
            await mutableResult.applyPartialAIGraph(
                to: document,
                viewStatePatchConnections: item.result.graphData.viewStatePatchConnections,
                isStreaming: item.isStreaming
            )

            // Wait 1 second for animation to complete, then process next
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.markAnimationComplete()

                // Continue processing if there are more items in queue
                if self.canProcessNext() {
                    self.processQueue(document: document)
                }
            }
        }
    }

    /// Processes final result after streaming completes, waiting for queue to finish first
    func processFinalResult(_ result: SwiftSyntaxActionsResult, document: StitchDocumentViewModel) {
        // Add final result to queue with isStreaming: false
        enqueue(result, isStreaming: false)

        // Process the queue (will handle the final result after any pending ones)
        if canProcessNext() {
            processQueue(document: document)
        }
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
