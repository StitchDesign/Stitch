//
//  OpenAIRequestHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/7/25.
//

import Foundation

/// Configuration settings for OpenAI API requests
struct OpenAIRequestConfig {
    let maxRetries: Int        // Maximum number of retry attempts for failed requests
    let timeoutInterval: TimeInterval   // Request timeout duration in seconds
    let retryDelay: TimeInterval       // Delay between retry attempts
    let maxTimeoutErrors: Int  // Maximum number of timeout errors before showing alert
    let stream: Bool           // Whether to stream the response
    
    /// Default configuration with optimized retry settings
    static let `default` = OpenAIRequestConfig(
        maxRetries: 3,
        timeoutInterval: 60,
        retryDelay: 2,
        maxTimeoutErrors: 4,
        stream: true
    )
}



// Note: an event is usually not a long-lived data structure; but this is used for retry attempts.
/// Main event handler for initiating OpenAI API requests
struct OpenAIRequest {
    private let OPEN_AI_BASE_URL = "https://api.openai.com/v1/chat/completions"
    let prompt: String             // User's input prompt
    let systemPrompt: String       // System-level instructions loaded from file
    let config: OpenAIRequestConfig // Request configuration settings
    
    /// Initialize a new request with prompt and optional configuration
    @MainActor
    init(prompt: String,
         config: OpenAIRequestConfig = .default,
         graph: GraphState) throws {
        self.prompt = prompt
        self.config = config
        
        // Load system prompt from bundled file
        let loadedPrompt = try StitchAIManager.systemPrompt(graph: graph)
        self.systemPrompt = loadedPrompt
    }
}


extension [[String]] {
    func megajoin() -> String {
        self.map { $0.joined() }.joined()
    }
}

struct ChunkProcessed: GraphEvent {
    let newStep: Step
    
    func handle(state: GraphState) {
        log("ChunkProcessed: newStep: \(newStep)")
        state.streamedSteps.append(newStep)
        log("ChunkProcessed: state.streamedSteps is now: \(state.streamedSteps)")
    }
}

/// Helper struct to process streaming chunks
struct StreamingChunkProcessor {
    
    
    static func getStepsFromJoinedString(message: String) throws -> [Step]? {
        // Decode the chunk
        guard let data = message.data(using: .utf8) else {
            throw StitchAIManagerError.invalidStreamingData
        }
        
        let response: ContentJSON = try JSONDecoder().decode(ContentJSON.self, from: data)
        return response.steps
//        
////        guard let choice =
////              let content = try? choice.message.parseContent() else {
////        
////            return nil
////        }
//        
//        return content.steps
    }
    
    /// Process a chunk of data from the stream
    static func processChunk(_ chunk: String) throws -> [Step]? {
        // Remove "data: " prefix if present
        let jsonString = chunk.hasPrefix("data: ") ?
        String(chunk.dropFirst(6)) : chunk
        
        // Skip "[DONE]" message
        guard jsonString != "[DONE]" else {
            return nil
        }
        
        // Decode the chunk
        guard let data = jsonString.data(using: .utf8) else {
            throw StitchAIManagerError.invalidStreamingData
        }
        
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let choice = response.choices.first,
              let content = try? choice.message.parseContent() else {
            return nil
        }
        
        return content.steps
    }
}

extension Array where Element == Step {
    func convertSteps() throws -> [any StepActionable] {
        let convertedSteps: [any StepActionable] = try self.map { step in
            try step.convertToType()
        }
        return convertedSteps
    }
    
    mutating func append(_ stepType: StepTypeAction) {
        self.append(stepType.toStep())
    }
    
    func containsNewNode(from id: NodeId) -> Bool {
        self.contains(where: { step in
            if let convertedStep = try? step.convertToType(),
               let addStep = convertedStep as? StepActionAddNode {
                return addStep.nodeId == id
            }
            
            return false
        })
    }
}

extension Data {
    /// Parse OpenAI response data into step actions
    func getOpenAISteps() throws -> LLMStepActions {
        log("StitchAI Parsing JSON")
        
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: self)
        
        guard let firstChoice = response.choices.first else {
            throw StitchAIManagerError.emptySuccessfulResponse
        }
        
        let contentJSON = try firstChoice.message.parseContent()
        log("StitchAI JSON parsing succeeded")
        return contentJSON.steps
    }
}

extension Stitch.Step: CustomStringConvertible {
    /// Provides detailed string representation of a Step
    public var description: String {
        return """
        Step(
            stepType: "\(stepType)",
            nodeId: \(nodeId?.value.uuidString ?? "nil"),
            nodeName: \(nodeName?.asNodeKind.asLLMStepNodeName ?? "nil"),
            port: \(port?.asLLMStepPort() ?? "nil"),
            fromNodeId: \(fromNodeId?.value.uuidString ?? "nil"),
            toNodeId: \(toNodeId?.value.uuidString ?? "nil"),
            value: \(String(describing: value)),
            nodeType: \(valueType?.display ?? "nil")
        )
        """
    }
}


extension StitchDocumentViewModel {
    @MainActor func handleError(_ error: Error) {
        log("Error generating graph with StitchAI: \(error)", .logToServer)
        self.insertNodeMenuState.show = false
        self.insertNodeMenuState.isGeneratingAINode = false
    }
}
