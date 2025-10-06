//
//  ClaudeStreamingRequest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/9/25.
//

import SwiftUI

final actor ClaudeStreamingActor {
    // MARK: - Simple Task Throttling

    private var updateTask: Task<Void, Never>?

    /// Simple task-based throttling: if a task is running, just update the pending data
    /// Uses actor isolation to naturally handle concurrent access
    func updateGraphData(document: StitchDocumentViewModel,
                         mergedGraphEntity: GraphEntity) {
        // If task already running, just return (latest data stored above)
        guard updateTask == nil else { return }

        // Create new task since none running
        updateTask = Task(priority: .high) { [weak self, weak document] in
            // Perform actual update on main actor
            await MainActor.run { [weak document] in
                guard let document = document else { return }
                document.graph.update(from: mergedGraphEntity,
                                      fromAIStream: true)
                document.graph.updateGraphData(document)
            }

            // Clear task when done
            await self?.clearTask()
        }
    }

    /// Clear the task when completed (actor-isolated)
    private func clearTask() {
        updateTask = nil
    }
    
    /// Make a request to Claude's Messages endpoint
    func makeClaudeStreamingRequest(
        previewWindowPrompt: String,
        userPrompt: String,
        base64Image: String?,
        model: ClaudeModel,
        document: StitchDocumentViewModel,
        currentGraphEntity: GraphEntity,
        viewPortCenter: CGPoint,
        groupNodeFocused: UUID?
    ) async throws -> String {
        var currentGraphEntity = currentGraphEntity
        
        log("=== makeClaudeStreamingRequest STARTED ===")
        
        log("Making Claude request with model: \(model.rawValue)")
        
        guard let claudeAPIKey = StitchStore.claudeAPIKey, !claudeAPIKey.isEmpty else {
            log("ERROR: Claude API key not configured in settings")
            throw StitchAIManagerError.claudeAPIKeyNotSet
        }
        
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw StitchAIStreamingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("output-128k-2025-02-19,prompt-caching-2024-07-31", forHTTPHeaderField: "anthropic-beta")
        
        // Use static content for consistent caching (avoids UUID and non-deterministic issues)
        let stitchStaticContent = try loadStitchStaticPrompt()
        
        // Static content component (data glossary + fixed instructions)
        let staticSystemPrompt: [String: Any] = [
            "type": "text",
            "text": stitchStaticContent, // Use static content for consistent caching
            "cache_control": ["type": "ephemeral", "ttl": "1h"] // Cache control on large Stitch static content
        ]
        
        // Preview window constraints component (cacheable per session)
        let previewWindowSystemPrompt: [String: Any] = [
            "type": "text",
            "text": previewWindowPrompt, // Contains preview window constraints
            "cache_control": ["type": "ephemeral", "ttl": "1h"] // Cache preview window info for session
        ]
        
        var claudeBody: [String: Any] = [
            "model": model.rawValue, // Use the actual model parameter
            "max_tokens": model.maxTokens, // Model-specific maximum output tokens
            "system": [staticSystemPrompt, previewWindowSystemPrompt], // Multi-component cached system prompt
            "stream": true // Enable streaming for better UX
        ]
        
        // Add extended thinking for supported models
        let supportsThinking = model.supportsThinking
        
        if supportsThinking {
            claudeBody["thinking"] = [
                "type": "enabled",
                "budget_tokens": 3000  // Reduced budget for more concise thinking
            ]
            log("Extended thinking enabled for model: \(model.rawValue) with 3k token budget for terse reasoning")
        } else {
            log("Extended thinking not supported for model: \(model.rawValue)")
        }
        
        // Handle text + optional image input
        if let imageData = base64Image {
            claudeBody["messages"] = [[
                "role": "user",
                "content": [
                    ["type": "text", "text": userPrompt],
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": imageData
                        ],
                        "cache_control": ["type": "ephemeral", "ttl": "1h"] // Cache the image data for reuse
                    ]
                ]
            ]]
        } else {
            claudeBody["messages"] = [[
                "role": "user",
                "content": userPrompt
            ]]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: claudeBody)
        
        // Log request details for debugging including cache structure
        if let jsonData = request.httpBody {
            log("🔍 Total Claude request body: \(jsonData.count) bytes (\(jsonData.count/1024)KB)")
            log("📤 Using Claude model: \(model.rawValue)")
            
#if DEV_DEBUG
            // Log stitch static content stats for cache debugging
            let stitchTokenEstimate = stitchStaticContent.count / 3 // Rough token estimate
            log("📚 Stitch static system prompt stats:")
            log("   → Characters: \(stitchStaticContent.count)")
            log("   → Estimated tokens: ~\(stitchTokenEstimate)")
            log("   → Cache eligible: \(stitchTokenEstimate > 1024 ? "✅ YES" : "❌ NO") (>1024 tokens required)")
            
            // Log request structure for debugging (without sensitive content)
            log("🔍 Claude request structure:")
            log("   → Model: \(model.rawValue)")
            log("   → Max tokens: \(model.maxTokens) (model-specific limit)")
            log("   → Stream: \(claudeBody["stream"] ?? false)")
            log("   → Has thinking: \(claudeBody["thinking"] != nil)")
            if let systemArray = claudeBody["system"] as? [[String: Any]] {
                log("   → System components: \(systemArray.count)")
                for (index, component) in systemArray.enumerated() {
                    if let text = component["text"] as? String {
                        let charCount = text.count
                        let hasCache = component["cache_control"] != nil
                        log("     Component \(index + 1): \(charCount) chars, cached: \(hasCache)")
                    }
                }
            }
            if let messages = claudeBody["messages"] as? [[String: Any]] {
                log("   → Messages: \(messages.count)")
                for (index, message) in messages.enumerated() {
                    if let role = message["role"] as? String {
                        let contentType = message["content"] is String ? "text" : "multipart"
                        log("     Message \(index + 1): \(role) (\(contentType))")
                    }
                }
            }
#endif
        }
        
        // Track request timing
        let requestStartTime = Date()
        
        do {
            log("=== Starting Claude streaming request ===")
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                log("Claude request: No HTTP response")
                throw StitchAIStreamingError.other(URLError(.badServerResponse))
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                log("Claude streaming request failed with status: \(httpResponse.statusCode)")
                
                // Read error response body for detailed error information
                do {
                    let errorData = try await URLSession.shared.data(for: request).0
                    let errorMessage = parseClaudeErrorResponse(errorData, statusCode: httpResponse.statusCode)
                    log("Claude API Error Details: \(errorMessage)")
                    throw StitchAIStreamingError.apiError(httpResponse.statusCode, errorMessage)
                } catch let apiError as StitchAIStreamingError {
                    // Re-throw our custom error
                    throw apiError
                } catch {
                    // Fallback if we can't read the error response
                    log("Failed to read Claude error response: \(error)")
                    throw StitchAIStreamingError.apiError(httpResponse.statusCode, "HTTP \(httpResponse.statusCode) - Unable to read error details")
                }
            }
            
            log("Claude streaming response status: \(httpResponse.statusCode)")
            
            var accumulatedContent = ""
            var accumulatedThinking = ""
            var totalUsage: ClaudeUsage?
            
            var firstThinkingTime: Date?
            var firstContentTime: Date?
            var lineCount = 0
            var eventCount = 0
            
            // Debug: Track all thinking steps for debugging
            var allThinkingSteps: [String] = []
            
            log("🔄 Starting to process Claude streaming response...")
            
            for try await line in asyncBytes.lines {
                lineCount += 1
                
                // Skip empty lines
                guard !line.isEmpty else {
                    // log("📝 Skipping empty line \(lineCount)")
                    continue
                }
                
                // log("📝 Received line \(lineCount): \(line.prefix(100))\(line.count > 100 ? "..." : "")")
                
                // Parse SSE format: "data: {json}"
                let jsonString = line.hasPrefix("data: ") ? String(line.dropFirst(6)) : line
                
                //            log("🔍 Processing JSON string: \(jsonString.prefix(200))\(jsonString.count > 200 ? "..." : "")")
                
                // Handle stream completion
                if jsonString == "[DONE]" {
                    //                log("✅ Stream completion marker received")
                    break
                }
                
                // Parse JSON event
                guard let data = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    //                log("⚠️ Failed to parse JSON from line: \(line)")
                    continue
                }
                
                eventCount += 1
                let eventType = json["type"] as? String
                //            log("🎯 Event \(eventCount): \(eventType ?? "unknown") - JSON keys: \(json.keys.joined(separator: ", "))")
                
                switch eventType {
                case "message_start":
                    log("Claude stream started")
                    
                case "content_block_start":
                    if let contentBlock = json["content_block"] as? [String: Any],
                       let type = contentBlock["type"] as? String {
                        if type == "thinking" {
                            //                        log("🧠 Claude thinking block started")
                            if firstThinkingTime == nil {
                                firstThinkingTime = Date()
                                // let thinkingLatency = Date().timeIntervalSince(requestStartTime) * 1000
                                //                            log("⚡ Time to first thinking: \(String(format: "%.0f", thinkingLatency))ms")
                            }
                        } else if type == "text" {
                            //                        log("📝 Claude text content block started")
                            if firstContentTime == nil {
                                firstContentTime = Date()
                                // let contentLatency = Date().timeIntervalSince(requestStartTime) * 1000
                                //                            log("⚡ Time to first content: \(String(format: "%.0f", contentLatency))ms")
                            }
                        }
                    }
                    
                case "content_block_delta":
                    if let delta = json["delta"] as? [String: Any] {
                        //                    log("Delta received: \(delta)")
                        if let thinkingText = delta["thinking"] as? String {
                            // This is thinking content
                            // log("🧠 Thinking delta received: '\(thinkingText)' (length: \(thinkingText.count))")
                            accumulatedThinking += thinkingText
                            allThinkingSteps.append(thinkingText)
                            
                            // Update UI with thinking progress (just show raw content, no prefix)
                            
                            let latestAccumulatedThinking = accumulatedThinking
                            Task(priority: .high) { @MainActor [weak document] in
                                document?.streamingReasoningText = latestAccumulatedThinking
                            }
                        } else if let text = delta["text"] as? String {
                            // This is regular text content
                            // log("📝 Text delta received: '\(text)' (length: \(text.count))")
                            accumulatedContent += text
                            log("accumulated text: \n\(accumulatedContent)")

                            // Skip parsing if no ContentView present (explanatory text only)
                            guard accumulatedContent.contains("ContentView") else {
                                continue
                            }

                            // MARK: code building in-progress graphs is expensive, we delay work so long as no active update task is running
                            guard self.updateTask == nil else { break }

                            let codeParserResult = SwiftUIViewVisitor.parseSwiftUICode(accumulatedContent, isStreaming: true)
                            
                            // Syntax → Actions
                            let stitchActionsResult = try codeParserResult.deriveStitchActionsSync(
                                bindingDeclarations: codeParserResult.bindingDeclarations,
                                isStreaming: true)
                            
                            // Actions -> GraphEntity
                            let result = stitchActionsResult
                                .createAIGraph(from: currentGraphEntity,
                                               docId: currentGraphEntity.id,
                                               viewPortCenter: viewPortCenter,
                                               groupNodeFocused: groupNodeFocused,
                                               isStreaming: true)
                            
                            // Track new current graph
                            currentGraphEntity = result.graph
                            
                            // Updates graph on main actor
                            self.updateGraphData(document: document,
                                                 mergedGraphEntity: result.graph)
                            
                            //                        // Clear thinking text once content starts
                            //                        await MainActor.run {
                            //                            if !document.streamingReasoningText.isEmpty {
                            //                                document.streamingReasoningText = ""
                            //                                // log("📱 Cleared thinking text - switching to content")
                            //                            }
                            //                        }
                        } else {
                            //                        log("⚠️  Delta received but no 'thinking' or 'text' field found")
                        }
                    } else {
                        //                    log("⚠️  content_block_delta event with no delta field")
                    }
                    
                case "message_delta":
                    if let usage = json["usage"] as? [String: Any] {
                        totalUsage = try? JSONDecoder().decode(ClaudeUsage.self, from: JSONSerialization.data(withJSONObject: usage))
                    }
                    
                case "message_stop":
                    log("🏁 Claude stream completed - message_stop received")
                    
                    // Monitor cache performance
                    if let usage = totalUsage {
                        await monitorClaudeStreamingCachePerformance(usage: usage)
                    }
                    
                default:
                    log("❓ Unknown event type: \(eventType ?? "nil")")
                    continue
                }
            }
            
            log("🔚 Finished processing Claude stream - Total lines: \(lineCount), Events: \(eventCount)")
            
            log("Claude streaming completed successfully")
            log("Final content length: \(accumulatedContent.count) characters")
            log("Total thinking length: \(accumulatedThinking.count) characters")
            log("📝 Thinking steps received: \(allThinkingSteps.count)")
            
            if accumulatedContent.isEmpty && accumulatedThinking.isEmpty {
                log("⚠️ WARNING: No content or thinking received from Claude!")
                log("🔍 Stream summary: \(lineCount) lines processed, \(eventCount) events handled")
            }
            
#if DEV_DEBUG
            // Debug: log all thinking steps as formatted text block
            if !allThinkingSteps.isEmpty {
                log("🧠 All thinking deltas received as text block:")
                let formattedThinking = allThinkingSteps.joined(separator: " ")
                log("\(formattedThinking)")
            }
#endif
            
            return accumulatedContent
            
        } catch {
            await MainActor.run { [weak document] in
                document?.resetStreamingUIState()
            }
            
            // Log failure timing
            let failureDuration = Date().timeIntervalSince(requestStartTime)
            log("❌ Claude request failed after \(String(format: "%.2f", failureDuration)) seconds")
            
            log("Claude request failed: \(error)")
            throw error
        }
    }
}


/// Parse Claude API error response to extract detailed error information
func parseClaudeErrorResponse(_ errorData: Data, statusCode: Int) -> String {
    do {
        // Try to parse as JSON
        if let json = try JSONSerialization.jsonObject(with: errorData) as? [String: Any] {
            // Claude API error format: { "type": "error", "error": { "type": "...", "message": "..." } }
            if let error = json["error"] as? [String: Any] {
                let errorType = error["type"] as? String ?? "unknown"
                let errorMessage = error["message"] as? String ?? "No message provided"
                return "\(errorType): \(errorMessage)"
            }
            
            // Fallback: look for direct message field
            if let message = json["message"] as? String {
                return message
            }
            
            // If we can parse JSON but no recognized structure, return the raw JSON
            if let jsonString = String(data: errorData, encoding: .utf8) {
                return "Raw error response: \(jsonString)"
            }
        }
    } catch {
        // JSON parsing failed
        log("Failed to parse Claude error JSON: \(error)")
    }
    
    // Last resort: return raw string
    if let rawString = String(data: errorData, encoding: .utf8) {
        return "Raw error response: \(rawString)"
    }
    
    return "Unable to parse error response (HTTP \(statusCode))"
}

/// Monitor Claude prompt cache performance from streaming usage data in AIRequestFunctions
func monitorClaudeStreamingCachePerformance(usage: ClaudeUsage) async {
    
#if DEV_DEBUG || DEBUG
    // Extract cache and usage data
    let inputTokens = usage.inputTokens
    let outputTokens = usage.outputTokens
    let cacheCreationInputTokens = usage.cacheCreationInputTokens ?? 0
    let cacheReadInputTokens = usage.cacheReadInputTokens ?? 0
    
    log("🔍 Claude Streaming Response Usage Analysis for Cache Performance:")
    log("📊 Usage Statistics:")
    log("   → Input tokens: \(inputTokens)")
    log("   → Output tokens: \(outputTokens)")
    
    // Analyze cache performance
    log("💾 Cache Performance Analysis:")
    if cacheCreationInputTokens > 0 {
        log("   ✅ Cache created with \(cacheCreationInputTokens) tokens")
        
        // Calculate potential savings
        let potentialSavings = Double(cacheCreationInputTokens) * 0.9 // 90% cost reduction for cached tokens
        log("   💰 Potential future savings: \(String(format: "%.0f", potentialSavings)) token-equivalents per request")
    }
    
    if cacheReadInputTokens > 0 {
        let cachePercentage = (Double(cacheReadInputTokens) / Double(inputTokens)) * 100
        log("   🚀 Cache hit! \(cacheReadInputTokens) tokens read from cache (\(String(format: "%.1f", cachePercentage))%)")
        
        // Calculate actual savings
        let actualSavings = Double(cacheReadInputTokens) * 0.9 // 90% cost reduction for cached tokens
        log("   💰 Cost savings: ~\(String(format: "%.0f", actualSavings)) token-equivalents")
    } else if inputTokens >= 1024 {
        log("   ❓ No cache hits detected")
        log("   → Cache may still be warming up for future requests")
    } else {
        log("   📏 Prompt too small for caching (\(inputTokens) < 1024 tokens)")
        log("   → Claude caching requires ≥1024 tokens")
        log("   → Consider consolidating static content")
    }
    
    // Log overall token usage
    let totalTokens = inputTokens + outputTokens
    log("🎯 Total usage: \(inputTokens) input + \(outputTokens) output = \(totalTokens) tokens")
    
    // Log to server for analytics
    log("Claude streaming cache performance - Created: \(cacheCreationInputTokens), Read: \(cacheReadInputTokens), Total: \(totalTokens)")
#endif
}

extension GraphEntity {
    /// Merge an in-progress (streamed) graph into the current graph by matching incoming
    /// nodes to existing ones. If IDs match, they are considered the same. Otherwise, we
    /// attempt a heuristic match based on node kind, patch/layer/component specifics,
    /// title similarity, parent group, and canvas proximity.
    ///
    /// - Parameter inProgressGraph: The newly parsed/streamed graph snapshot.
    /// - Returns: A new `GraphEntity` with nodes replaced/added based on matches.
    func mergeWithStreamedGraph(_ inProgressGraph: GraphEntity,
                                lastStreamedLayerId: UUID?,
                                isLayerStreamingComplete: Bool,
                                isFullStreamComplete: Bool) -> GraphEntity {
        var merged = self
        
        // Fast lookup of existing nodes by id
        let existingNodesMap: [UUID: NodeEntity] = merged.nodes.reduce(into: [UUID: NodeEntity]()) { result, node in
            result[node.id] = node
        }
        
        // Used for similarity checks
        let currentSidebarList = self.orderedSidebarLayers.flattenedItems
        let inProgressSidebarList = inProgressGraph.orderedSidebarLayers.flattenedItems
        
        // Tracks available candidate nodes for matching, removed when in use
        var candidateCurrentPatchNodes = self.nodes.filter { $0.kind.isPatch }.toSet
        var candidateCurrentLayerNodes = self.nodes.filter { $0.kind.isLayer }.toSet
        
        // Input data for calculating similarity score
        let inProgressLayerIndexOf = inProgressSidebarList
            .enumerated()
            .reduce(into: [UUID: Int]()) { result, data in
                result.updateValue(data.0, forKey: data.1.id)
        }
        
        let currentLayerIndexOf = currentSidebarList
            .enumerated()
            .reduce(into: [UUID: Int]()) { result, data in
                result.updateValue(data.0, forKey: data.1.id)
        }
        
        // Tracks which existing node ids have already been matched to avoid duplicates
        var claimedExistingIds = Set<UUID>()
        
        // Tracks new/replaced nodes by id
        var newNodesMap = [UUID: NodeEntity]()
        
        // Tracks changed node Ids
        // key: streamed id, value: current id (we convert everything to current graph data)
        var changedNodeIds = [UUID: UUID]()
        
        // Reuse existing node if data incomplete
        let useStreamedNode = { (current: NodeEntity, streamed: NodeEntity) -> Bool in
            let streamedNodeMatchesIncompleteLayer = streamed.id == lastStreamedLayerId
            
            // Only use current data when layer streaming is incomplete and not last node
            let useCurrent = !isLayerStreamingComplete && !streamedNodeMatchesIncompleteLayer

            // Remove candidate
            if current.kind.isPatch {
                candidateCurrentPatchNodes.remove(current)
            } else {
                candidateCurrentLayerNodes.remove(current)
            }
            
            return !useCurrent
        }
        
        for streamed in inProgressGraph.nodes {
            // 1) Exact id match: replace directly
            if let existing = existingNodesMap[streamed.id] {
                if useStreamedNode(existing, streamed) {
                    newNodesMap[streamed.id] = streamed
                    claimedExistingIds.insert(streamed.id)
                    
                    // Track same ID--needed for copy logic
//                    changedNodeIds.updateValue(streamed.id, forKey: streamed.id)
                }
                
                continue
            }
            
            // Prefer the tighter candidate set first
            var bestScore = Int.min
            var bestId: UUID?
            
            func consider(_ candidates: Set<NodeEntity>) {
                for candidate in candidates {
                    if claimedExistingIds.contains(candidate.id) { continue }
                    let score = similarityScore(between: streamed,
                                                and: candidate,
                                                aLayerIndexOf: inProgressLayerIndexOf,
                                                bLayerIndexOf: currentLayerIndexOf)
                    if score > bestScore {
                        bestScore = score
                        bestId = candidate.id
                    }
                }
            }
            
            consider(streamed.kind.isPatch ? candidateCurrentPatchNodes : candidateCurrentLayerNodes)
            
            // 3) Apply threshold and either replace matched node or add as new
            let threshold = 40
            if let matchedId = bestId,
                bestScore >= threshold,
               let existing = existingNodesMap[matchedId] {
                // We choose to retain IDs already existing rather use the new ID so that update methods can continue to be used.
                changedNodeIds.updateValue(matchedId, forKey: streamed.id)
                
                if useStreamedNode(existing, streamed) {
                    newNodesMap[matchedId] = streamed
                    claimedExistingIds.insert(matchedId)
                }
            } else {
                // New node — append as-is
                newNodesMap[streamed.id] = streamed
                
                // Track same ID--needed for copy logic
//                changedNodeIds.updateValue(streamed.id, forKey: streamed.id)
            }
        }

        // Start from existing map and overlay new/replaced nodes (avoids extra dictionary merges)
        var resultMap: [UUID: NodeEntity]
        
        if isFullStreamComplete {
            // Only use new data
            resultMap = newNodesMap
        } else {
            // Merge existing and new data
            resultMap = existingNodesMap
            for (id, node) in newNodesMap {
                resultMap[id] = node
            }
        }
        
        // Update changed node IDs to include existing nodes not yet tracked by streamed nodes
//        existingNodesMap.keys.forEach { nodeId in
//            // Existing node is saved as a value because that's what we're changing to
//            if !changedNodeIds.values.contains(nodeId) {
//                changedNodeIds.updateValue(nodeId, forKey: nodeId)
//            }
//        }
        
        // Creates map used specifically for copy data functions
        // This ensures `createCopy` will use a real ID instead of nil for some parent groups
        let copyNodesIdMap = merged.nodes.reduce(into: changedNodeIds) { result, node in
            // Skip if already tracked
            if !claimedExistingIds.contains(node.id) {
                result.updateValue(node.id, forKey: node.id)
            }
        }
        
        merged.nodes = Array(resultMap.values)
        
        //

        // Update all node references within the graph to use the new IDs
        //        merged = merged.replaceNodeIdReference(idMap: changedNodeIds)
        merged.nodes = merged.nodes.createCopy(mappableData: copyNodesIdMap,
                                               copiedNodeIds: Set(copyNodesIdMap.keys))

        if isFullStreamComplete {
            // Use exact streamed data except for some IDs
            merged.orderedSidebarLayers = inProgressGraph.orderedSidebarLayers
                .createCopy(mappableData: copyNodesIdMap)
        } else {
            // Iterate through in-progress sidebar data to ensure each entry is accounted for in our existing set. If not, we need to update our sidebar data.
            merged.orderedSidebarLayers = inProgressGraph.orderedSidebarLayers
                .merge(with: self.orderedSidebarLayers,
                       changedNodeIds: changedNodeIds)  // only use specifically the changed node ids
        }
        // let currentLog = self.nodes.reduce(into: "mergeWithStreamedGraph: current nodes:") { stringBuilder, node in
        //     stringBuilder += "\n\(node.id):\tkind: \(node.kind)\tlayer group: \(node.layerNodeEntity?.layerGroupId?.uuidString ?? "nil")"
        // }
        // log(currentLog)

        // let inProgressLog = merged.nodes.reduce(into: "mergeWithStreamedGraph: new nodes:") { stringBuilder, node in
        //     stringBuilder += "\n\(node.id):\tkind: \(node.kind)\tlayer group: \(node.layerNodeEntity?.layerGroupId?.uuidString ?? "nil")"
        // }
        // log(inProgressLog)
        
        let sidebarLog = merged.orderedSidebarLayers
            .createLogMessage("mergeWithStreamedGraph sidebar:")
        log(sidebarLog)

#if DEBUG || DEV_DEBUG
        let layerNodes = merged.nodes.compactMap(\.layerNodeEntity)
        let sidebarItems = merged.orderedSidebarLayers.flattenedItems
        
        let layerNodesCount = layerNodes.count
        let sidebarCount = sidebarItems.count
        let layerNodesSet = Set(layerNodes.map(\.id))
        let sidebarItemsSet = Set(sidebarItems.map(\.id))

        assertInDebug(layerNodesCount == sidebarCount)
        assertInDebug(layerNodesSet == sidebarItemsSet)
#endif
        return merged
    }
    
    // MARK: - Similarity Heuristics

    /// Computes a similarity score between two nodes. Higher is better.
    /// Prioritizes node kind (patch/layer/group/component), then patch/layer/component
    /// specific identifiers, title similarity, shared parent group, and canvas proximity.
    private func similarityScore(between a: NodeEntity,
                                 and b: NodeEntity,
                                 aLayerIndexOf: [UUID: Int],
                                 bLayerIndexOf: [UUID: Int]) -> Int {
        
        // Exact id match is handled earlier, but keep a guard here for completeness
        if a.id == b.id { return 1_000 }
        
        var score = 0
        
        // Deep-type specific checks
        switch (a.nodeTypeEntity, b.nodeTypeEntity) {
        case (.patch(let ap), .patch(let bp)) where ap.patch == bp.patch:
            if ap.patch == bp.patch { score += 40 }
            if ap.userVisibleType == bp.userVisibleType { score += 10 }

            // Enhanced input-based scoring for better patch node differentiation
            score += calculateInputSimilarityScore(ap.inputs, bp.inputs)

        case (.layer(let al), .layer(let bl)) where al.layer == bl.layer:
            guard let aIndex = aLayerIndexOf.get(a.id),
                  let bIndex = bLayerIndexOf.get(b.id) else {
                fatalErrorIfDebug()
                return 0
            }
            
            // Index closeness: prefer nodes that appear near the same relative order
            score += indexClosenessScore(aIndex, bIndex)

            if al.layer == bl.layer { score += 40 }
            
        case (.component(let ac), .component(let bc)):
            if ac.componentId == bc.componentId { score += 50 } // strong signal
            if ac.canvasEntity.parentGroupNodeId == bc.canvasEntity.parentGroupNodeId { score += 5 }
            let aPos = ac.canvasEntity.position
            let bPos = bc.canvasEntity.position
            score += proximityScore(aPos, bPos)
            
        case (.group(let ag), .group(let bg)):
            if ag.parentGroupNodeId == bg.parentGroupNodeId { score += 5 }
            score += proximityScore(ag.position, bg.position)
            
        default:
            // Different kinds guarded above, but keep a safe default
            break
        }
        
        return score
    }
    
    /// Scores proximity between two points. Closer yields higher score.
    private func proximityScore(_ a: CGPoint, _ b: CGPoint) -> Int {
        let dx = a.x - b.x
        let dy = a.y - b.y
        let d2 = dx*dx + dy*dy // squared distance
        // Thresholds squared: 20^2, 80^2, 160^2, 320^2
        if d2 < 400 { return 10 }
        else if d2 < 6400 { return 6 }
        else if d2 < 25600 { return 3 }
        else if d2 < 102400 { return 1 }
        else { return 0 }
    }
    
    /// Scores closeness between two indices. Smaller differences yield higher scores.
    private func indexClosenessScore(_ aIndex: Int, _ bIndex: Int) -> Int {
        let diff = abs(aIndex - bIndex)
        if diff == 0 { return 10 }
        else if diff == 1 { return 7 }
        else if diff <= 3 { return 4 }
        else if diff <= 7 { return 2 }
        else if diff <= 15 { return 1 }
        else { return 0 }
    }

    /// Comprehensive input similarity scoring for patch nodes (max ~25 points)
    private func calculateInputSimilarityScore(_ aInputs: [NodePortInputEntity],
                                               _ bInputs: [NodePortInputEntity]) -> Int {
        guard !aInputs.isEmpty && !bInputs.isEmpty else { return 0 }

        var score = 0

        // 1. Input count similarity (max 8 points)
        let inputCountDiff = abs(aInputs.count - bInputs.count)
        if inputCountDiff == 0 {
            score += 8
        } else if inputCountDiff <= 1 {
            score += 5
        } else if inputCountDiff <= 2 {
            score += 2
        }

        // 2. Connection pattern similarity (max 7 points)
        let minCount = min(aInputs.count, bInputs.count)
        var connectionMatches = 0
        for i in 0..<minCount {
            let aIsConnected = isInputConnected(aInputs[i].portData)
            let bIsConnected = isInputConnected(bInputs[i].portData)
            if aIsConnected == bIsConnected {
                connectionMatches += 1
            }
        }
        let connectionSimilarity = Double(connectionMatches) / Double(minCount)
        score += Int(connectionSimilarity * 7.0)

        // 3. Value type similarity for direct values (max 6 points)
        var typeMatches = 0
        for i in 0..<minCount {
            if let aValueType = getPortValueType(from: aInputs[i].portData),
               let bValueType = getPortValueType(from: bInputs[i].portData),
               aValueType == bValueType {
                typeMatches += 1
            }
        }
        let typeSimilarity = Double(typeMatches) / Double(minCount)
        score += Int(typeSimilarity * 6.0)

        // 4. Direct value comparison for exact matches (max 4 points)
        var exactMatches = 0
        for i in 0..<minCount {
            if arePortValuesEqual(aInputs[i].portData, bInputs[i].portData) {
                exactMatches += 1
            }
        }
        let exactSimilarity = Double(exactMatches) / Double(minCount)
        score += Int(exactSimilarity * 4.0)

        return score
    }

    /// Checks if an input port is connected to another node
    private func isInputConnected(_ portData: NodeConnectionType) -> Bool {
        switch portData {
        case .values:
            return false
        case .upstreamConnection:
            return true
        }
    }

    /// Extracts the PortValue type from a NodeConnectionType for comparison
    private func getPortValueType(from portData: NodeConnectionType) -> String? {
        switch portData {
        case .values(let values):
            return values.first?.typeName
        case .upstreamConnection:
            return nil
        }
    }

    /// Compares two NodeConnectionType instances for value equality
    private func arePortValuesEqual(_ a: NodeConnectionType, _ b: NodeConnectionType) -> Bool {
        switch (a, b) {
        case (.values(let aValues), .values(let bValues)):
            return aValues == bValues
        case (.upstreamConnection(let aCoord), .upstreamConnection(let bCoord)):
            return aCoord == bCoord
        default:
            return false
        }
    }
}

extension PortValue {
    /// Returns the type name for similarity comparison
    var typeName: String {
        switch self {
        case .string: return "string"
        case .bool: return "bool"
        case .number: return "number"
        case .color: return "color"
        case .position: return "position"
        case .size: return "size"
        case .point3D: return "point3D"
        case .point4D: return "point4D"
        case .pulse: return "pulse"
        case .asyncMedia: return "asyncMedia"
        case .json: return "json"
        case .transform: return "transform"
        case .anchoring: return "anchoring"
        case .cameraDirection: return "cameraDirection"
        case .assignedLayer: return "assignedLayer"
        case .layerDimension: return "layerDimension"
        case .plane: return "plane"
        case .networkRequestType: return "networkRequestType"
        case .none: return "none"
        case .textTransform: return "textTransform"
        case .dateAndTimeFormat: return "dateAndTimeFormat"
        case .scrollMode: return "scrollMode"
        case .textAlignment: return "textAlignment"
        case .textVerticalAlignment: return "textVerticalAlignment"
        case .fitStyle: return "fitStyle"
        case .animationCurve: return "animationCurve"
        case .lightType: return "lightType"
        case .layerStroke: return "layerStroke"
        case .textDecoration: return "textDecoration"
        case .blendMode: return "blendMode"
        case .strokeLineCap: return "strokeLineCap"
        case .strokeLineJoin: return "strokeLineJoin"
        case .contentMode: return "contentMode"
        case .delayStyle: return "delayStyle"
        case .shapeCoordinates: return "shapeCoordinates"
        case .shapeCommand: return "shapeCommand"
        case .spacing: return "spacing"
        case .padding: return "padding"
        case .sizingScenario: return "sizingScenario"
        case .cameraOrientation: return "cameraOrientation"
        case .deviceOrientation: return "deviceOrientation"
        case .vnImageCropOption: return "vnImageCropOption"
        case .orientation: return "orientation"
        case .mapType: return "mapType"
        case .progressIndicatorStyle: return "progressIndicatorStyle"
        case .mobileHapticStyle: return "mobileHapticStyle"
        case .scrollJumpStyle: return "scrollJumpStyle"
        case .scrollDecelerationRate: return "scrollDecelerationRate"
        case .deviceAppearance: return "deviceAppearance"
        case .materialThickness: return "materialThickness"
        case .pinTo: return "pinTo"
        default: return "unknown"
        }
    }
}

extension SidebarLayerList {
    /// BFS search with potentially incomplete streamed data. BFS ensures groups are made so that children can be added to existing data.
    func merge(with existingData: Self,
               changedNodeIds: [UUID: UUID]) -> Self {
        let existingDataMap = existingData.flattenedItems
            .reduce(into: [UUID: SidebarLayerData]()) { result, sidebarLayerData in
                result.updateValue(sidebarLayerData, forKey: sidebarLayerData.id)
            }
        
        var existingNodeIds = Set(existingDataMap.keys)
        
        return self.merge(with: existingData,
                          existingDataMap: existingDataMap,
                          changedNodeIds: changedNodeIds,
                          existingNodeIds: &existingNodeIds)
    }
    
    // Build list off of in progress data
    // Update visitedId to visitedIds
    // If any in progress data is using an existing id, change the ID and recursively merge children data
    // After inProgres data has been exausted, append in-order existing elements
        // Remove any elements already tracked
    /// BFS search with potentially incomplete streamed data. BFS ensures groups are made so that children can be added to existing data.
    private func merge(with existingData: Self,
                       existingDataMap: [UUID: SidebarLayerData],
                       changedNodeIds: [UUID: UUID],
                       existingNodeIds: inout Set<UUID>) -> Self {
        let inProgressData = self.compactMap { inProgressItem -> SidebarLayerData? in
            var inProgressItem = inProgressItem
            
            if let changedNodeId = changedNodeIds.get(inProgressItem.id) {
                guard let existingData = existingDataMap.get(changedNodeId) else {
                    fatalErrorIfDebug()
                    return inProgressItem
                }
                
                // Skip if existing nodes not tracked--this means we've already considered this node
//                guard existingNodeIds.contains(changedNodeId) else {
//                    return nil
//                }
                
                // Existing node becomes accounted for, remove so we don't dupe
                existingNodeIds.remove(existingData.id)
                
                // Change ID
                inProgressItem = .init(id: changedNodeId,
                                       children: inProgressItem.children,
                                       isExpandedInSidebar: inProgressItem.isExpandedInSidebar)
                
                // Merge children of data that's getting replaced with the in progress streamed data
                inProgressItem.children = inProgressItem.children?
                    .merge(with: existingData.children ?? [],
                           existingDataMap: existingDataMap,
                           changedNodeIds: changedNodeIds,
                           existingNodeIds: &existingNodeIds)
            }
            
            else {
                //                visitedNodeIds.insert(inProgressItem.id)
                
                // Merge children data but don't add unused existing data at lower hierarchies
                inProgressItem.children = inProgressItem.children?
                    .merge(with: [],
                           existingDataMap: existingDataMap,
                           changedNodeIds: changedNodeIds,
                           existingNodeIds: &existingNodeIds)
            }
            
            return inProgressItem
        }
        
        // Append any unused existing data
        let unusedExistingData = existingData.compactMap { existingItem -> SidebarLayerData? in
            guard existingNodeIds.contains(existingItem.id) else {
                return nil
            }
            
            // Skip existing nodes that inProgressData had planned to already remove
            let replacedByInProgressData = changedNodeIds.values.contains(existingItem.id)
            if replacedByInProgressData {
                return nil
            }
            
            var existingItem = existingItem
            
            if let existingItemChildren = existingItem.children {
                existingItem.children = SidebarLayerList()
                    .merge(with: existingItemChildren,
                           existingDataMap: existingDataMap,
                           changedNodeIds: changedNodeIds,
                           existingNodeIds: &existingNodeIds)
            }
            
            return existingItem
        }
        
        // Append existing data after in progress parsing
        return inProgressData + unusedExistingData
    }
    
    
//    /// BFS search with potentially incomplete streamed data. BFS ensures groups are made so that children can be added to existing data.
//    mutating private func merge(with inProgressData: Self,
//                                changedNodeIds: [UUID: UUID],
//                                existingNodeIds: Set<UUID>,
//                                parentLayerId: UUID? = nil,
//                                visitedNodeIds: inout Set<UUID>) {
//        var queue = self
//        var finalList = Self()
//        
//        while let inProgressItem = queue.popFirst() {
//            guard let changedNodeId = changedNodeIds.get(inProgressItem.id) else {
//                fatalErrorIfDebug("We should have an id")
//                continue
//            }
//            
//            if visitedNodeIds.contains(changedNodeId) {
//                // Remove from here if already visited--valid situation if we already added nested data that used this layer
//                let _  = self.remove(at: index)
//                continue
//            }
//            
//            visitedNodeIds.insert(changedNodeId)
//            
//            // Change ID
//            let inProgressItem = SidebarLayerData(id: changedNodeId,
//                                                  children: inProgressItem.children,
//                                                  isExpandedInSidebar: inProgressItem.isExpandedInSidebar)
//            
//            // Continue if already accounted for (sometimes changedNodeId isn't changed)
//            if !existingNodeIds.contains(changedNodeId) {
////                // Remove item and all of its children if already existing in sidebar
////                self.removeSidebarLayerData(changedNodeId)
//                                
//                // If parent is existing node, add in-place using existing index
//                self.insertSidebarLayerData(inProgressItem,
//                                            parentId: parentLayerId,
//                                            index: index)
//                
//                #if DEBUG
//                let list = self.flattenedItems.map(\.id)
//                let set = Set(list)
//                assertInDebug(list.count == set.count)
//                #endif
//            }
//            
//            // Now recursively BFS--do not skip this step!
//            if let children = inProgressItem.children {
//                self.merge(with: children,
//                           changedNodeIds: changedNodeIds,
//                           existingNodeIds: existingNodeIds,
//                           parentLayerId: changedNodeId,
//                           visitedNodeIds: &visitedNodeIds)
//            }
//        }
//    }
}
