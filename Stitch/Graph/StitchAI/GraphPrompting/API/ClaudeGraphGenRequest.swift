//
//  ClaudeStreamingRequest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/9/25.
//

import SwiftUI

final actor ClaudeStreamingActor {
    // MARK: - Simple Task Throttling

    private var pendingGraphUpdate: GraphEntity?
    private var updateTask: Task<Void, Never>?

    /// Simple task-based throttling: if a task is running, just update the pending data
    /// Uses actor isolation to naturally handle concurrent access
    func updateGraphData(document: StitchDocumentViewModel,
                         mergedGraphEntity: GraphEntity) {
        // Always store the latest graph update
        pendingGraphUpdate = mergedGraphEntity

        // If task already running, just return (latest data stored above)
        guard updateTask == nil else { return }

        // Create new task since none running
        updateTask = Task(priority: .high) { [weak self, weak document] in
            // Get the latest pending update from actor
            let latestGraphEntity = await self?.getPendingGraphUpdate()
            guard let latestGraphEntity = latestGraphEntity else { return }

            // Perform actual update on main actor
            await MainActor.run { [weak document] in
                guard let document = document else { return }
                document.graph.update(from: latestGraphEntity,
                                      fromAIStream: true)
                document.graph.updateGraphData(document)
            }

            // Clear task when done
            await self?.clearTask()
        }
    }

    /// Get the latest pending graph update (actor-isolated)
    private func getPendingGraphUpdate() -> GraphEntity? {
        return pendingGraphUpdate
    }

    /// Clear the task when completed (actor-isolated)
    private func clearTask() {
        updateTask = nil
        pendingGraphUpdate = nil
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
                    let errorMessage = await parseClaudeErrorResponse(errorData, statusCode: httpResponse.statusCode)
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
                            print("accumulated text: \n\(accumulatedContent)")
                            
                            let codeParserResult = SwiftUIViewVisitor.parseSwiftUICode(accumulatedContent, isStreaming: true)
                            
                            // Syntax → Actions
                            let stitchActionsResult = try codeParserResult.deriveStitchActionsSync(
                                bindingDeclarations: codeParserResult.bindingDeclarations,
                                isStreaming: true)
                            
                            // Actions -> GraphEntity
                            let result = stitchActionsResult
                                .createAIGraph(docId: currentGraphEntity.id,
                                               viewPortCenter: viewPortCenter,
                                               groupNodeFocused: groupNodeFocused,
                                               isStreaming: true)
                            
                            let inProgressParsedGraphEntity = result.graph
                            
                            // Computes similarity scores with in-progress parsed data to map to existing nodes
                            let mergedGraphEntity = currentGraphEntity
                                .mergeWithStreamedGraph(inProgressParsedGraphEntity)
                            
                            // Updates graph on main actor
                            self.updateGraphData(document: document,
                                                 mergedGraphEntity: mergedGraphEntity)
                            
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
@MainActor
func parseClaudeErrorResponse(_ errorData: Data, statusCode: Int) async -> String {
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
    func mergeWithStreamedGraph(_ inProgressGraph: GraphEntity) -> GraphEntity {
        var merged = self

        // Fast lookup of existing nodes by id
        let existingNodesMap: [UUID: NodeEntity] = merged.nodes.reduce(into: [UUID: NodeEntity]()) { result, node in
            result[node.id] = node
        }

        // Track existing nodes by coarse keys to reduce candidate set for matching
        // Also partition by kind for a broader fallback
        var indexByKey = [String: [NodeEntity]]()
        var indexByKind = [String: [NodeEntity]]()

        for node in merged.nodes {
            let key = coarseMatchKey(for: node)
            indexByKey[key, default: []].append(node)

            let kind = nodeKindKey(node)
            indexByKind[kind, default: []].append(node)
        }

        // Tracks which existing node ids have already been matched to avoid duplicates
        var claimedExistingIds = Set<UUID>()

        // Tracks new/replaced nodes by id
        var newNodesMap = [UUID: NodeEntity]()
        
        // Tracks changed node Ids
        var changedNodeIds = [UUID: UUID]()

        for streamed in inProgressGraph.nodes {
            // 1) Exact id match: replace directly
            if existingNodesMap[streamed.id] != nil {
                newNodesMap[streamed.id] = streamed
                claimedExistingIds.insert(streamed.id)
                continue
            }

            // 2) Coarse candidate selection using indexed keys
            let key = coarseMatchKey(for: streamed)
            let kind = nodeKindKey(streamed)
            let primaryCandidates = indexByKey[key] ?? []
            let fallbackCandidates = indexByKind[kind] ?? []

            // Prefer the tighter candidate set first
            var bestScore = Int.min
            var bestId: UUID?

            func consider(_ candidates: [NodeEntity]) {
                for candidate in candidates {
                    if claimedExistingIds.contains(candidate.id) { continue }
                    let score = similarityScore(between: streamed, and: candidate)
                    if score > bestScore {
                        bestScore = score
                        bestId = candidate.id
                    }
                }
            }

            consider(primaryCandidates)
            if bestId == nil { // only consider broad set if no good specific candidates
                consider(fallbackCandidates)
            }

            // 3) Apply threshold and either replace matched node or add as new
            let threshold = 40
            if let matchedId = bestId, bestScore >= threshold {
                // We choose to retain IDs already existing rather use the new ID so that update methods can continue to be used.
                changedNodeIds.updateValue(matchedId, forKey: streamed.id)
                
                let newStreamed = NodeEntity(id: matchedId,
                                             nodeTypeEntity: streamed.nodeTypeEntity,
                                             title: streamed.title)
                newNodesMap[matchedId] = newStreamed
                claimedExistingIds.insert(matchedId)
            } else {
                // New node — append as-is
                newNodesMap[streamed.id] = streamed
            }
        }

        // Start from existing map and overlay new/replaced nodes (avoids extra dictionary merges)
        var resultMap = existingNodesMap
        for (id, node) in newNodesMap {
            resultMap[id] = node
        }

        merged.nodes = Array(resultMap.values)

        // Update all node references within the graph to use the new IDs
//        merged = merged.replaceNodeIdReference(idMap: changedNodeIds)
        merged.nodes = merged.nodes.createCopy(mappableData: changedNodeIds,
                                               copiedNodeIds: .init())

        return merged
    }

    /// Builds a coarse key to quickly narrow down matching candidates.
    /// The key considers node kind, a type identifier, parent group, and a coarse position bucket.
    private func coarseMatchKey(for node: NodeEntity) -> String {
        switch node.nodeTypeEntity {
        case .patch(let p):
            let patchId = String(describing: p.patch)
            let group = p.canvasEntity.parentGroupNodeId?.uuidString ?? "nil"
            let inputs = p.inputs.count
            let b = positionBucket(p.canvasEntity.position)
            return "patch|\(patchId)|g:\(group)|i:\(inputs)|b:\(b.x)_\(b.y)"

        case .layer(let l):
            let layerId = String(describing: l.layer)
            let group = l.layerGroupId?.uuidString ?? "nil"
            return "layer|\(layerId)|g:\(group)"

        case .component(let c):
            let comp = c.componentId.uuidString
            let group = c.canvasEntity.parentGroupNodeId?.uuidString ?? "nil"
            let b = positionBucket(c.canvasEntity.position)
            return "component|\(comp)|g:\(group)|b:\(b.x)_\(b.y)"

        case .group(let g):
            let group = g.parentGroupNodeId?.uuidString ?? "nil"
            let b = positionBucket(g.position)
            return "group|g:\(group)|b:\(b.x)_\(b.y)"
        }
    }

    /// Coarse position bucketing to avoid expensive global proximity checks during indexing.
    private func positionBucket(_ p: CGPoint, size: CGFloat = 80) -> (x: Int, y: Int) {
        let bx = Int(floor(p.x / size))
        let by = Int(floor(p.y / size))
        return (bx, by)
    }

    /// Attempts to find an existing node id that best matches the incoming node.
    /// Returns `nil` if no sufficiently good match is found.
    ///
    /// - Parameters:
    ///   - incoming: The newly parsed node to match.
    ///   - alreadyMatched: A set of existing node ids already claimed by other matches.
    /// - Returns: The id of the best-matching existing node, if any.
    func matchExistingNodeId(for incoming: NodeEntity, excluding alreadyMatched: Set<UUID> = []) -> UUID? {
        // Quick exit: if any existing node shares the same id (should have been caught above)
        if self.nodes.contains(where: { $0.id == incoming.id }) {
            return incoming.id
        }

        // Score all candidates that are not already matched
        var bestScore = Int.min
        var bestId: UUID?

        for existing in self.nodes where !alreadyMatched.contains(existing.id) {
            let score = similarityScore(between: incoming, and: existing)
            if score > bestScore {
                bestScore = score
                bestId = existing.id
            }
        }

        // Require a minimum score to avoid spurious matches
        let threshold = 40
        return bestScore >= threshold ? bestId : nil
    }

    // MARK: - Similarity Heuristics

    /// Computes a similarity score between two nodes. Higher is better.
    /// Prioritizes node kind (patch/layer/group/component), then patch/layer/component
    /// specific identifiers, title similarity, shared parent group, and canvas proximity.
    private func similarityScore(between a: NodeEntity, and b: NodeEntity) -> Int {
        // Exact id match is handled earlier, but keep a guard here for completeness
        if a.id == b.id { return 1_000 }

        var score = 0

        // 1) Node kind match (patch/layer/group/component)
        let aKind = nodeKindKey(a)
        let bKind = nodeKindKey(b)
        if aKind == bKind { score += 30 } else { return 0 } // different kinds are unlikely matches

        // 2) Deep-type specific checks
        switch (a.nodeTypeEntity, b.nodeTypeEntity) {
        case (.patch(let ap), .patch(let bp)):
            if ap.patch == bp.patch { score += 40 }
            if ap.userVisibleType == bp.userVisibleType { score += 10 }
            if ap.inputs.count == bp.inputs.count { score += 5 }

            // Parent grouping
            if ap.canvasEntity.parentGroupNodeId == bp.canvasEntity.parentGroupNodeId { score += 5 }

            // Canvas position proximity
            if let aPos = Optional(ap.canvasEntity.position), let bPos = Optional(bp.canvasEntity.position) {
                score += proximityScore(aPos, bPos)
            }

        case (.layer(let al), .layer(let bl)):
            if al.layer == bl.layer { score += 40 }
            if al.layerGroupId == bl.layerGroupId { score += 5 }
            // Layers don't have a single canonical canvas position; skip positional score

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

        // 3) Title similarity (cheap heuristic)
        let aTitle = a.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let bTitle = b.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !aTitle.isEmpty && aTitle == bTitle { score += 6 }
        else if !aTitle.isEmpty && !bTitle.isEmpty && (aTitle.contains(bTitle) || bTitle.contains(aTitle)) {
            score += 3
        }

        return score
    }

    /// Returns a simple key describing the top-level kind for matching purposes.
    private func nodeKindKey(_ node: NodeEntity) -> String {
        switch node.nodeTypeEntity {
        case .patch: return "patch"
        case .layer: return "layer"
        case .group: return "group"
        case .component: return "component"
        }
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
}
