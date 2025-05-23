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
    
    /// Default configuration with optimized retry settings
    static let `default` = OpenAIRequestConfig(
        maxRetries: 3,
        timeoutInterval: 60,
        retryDelay: 2,
        maxTimeoutErrors: 4
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
         systemPrompt: String) {
        self.prompt = prompt
        self.config = config
        self.systemPrompt = systemPrompt
    }
}

struct ChunkProcessed: StitchDocumentEvent {
    let newStep: Step
    let request: OpenAIRequest
    let currentAttempt: Int
    
    func handle(state: StitchDocumentViewModel) {
        log("ChunkProcessed: newStep: \(newStep)")
                
        state.visibleGraph.streamedSteps.append(newStep)
        log("ChunkProcessed: state.visibleGraph.streamedSteps is now: \(state.visibleGraph.streamedSteps)")
        
        state.llmRecording.actions = Array(state.visibleGraph.streamedSteps)
        log("ChunkProcessed: state.llmRecording.actions is now: \(state.llmRecording.actions)")
        
        do {
            
            try state.reapplyActions(isStreaming: true)
            log("ChunkProcessed: SUCCESSFULLY REAPPLIED LLM ACTIONS")
            
        } catch {
            
            log("ChunkProcessed: FAILED TO APPLY LLM ACTIONS: error: \(error) for request \(request)")
                    
            guard let aiManager = state.aiManager else {
                fatalErrorIfDebug("handleErrorWhenApplyingChunk: no ai manager")
                return
            }
            
            // Cancel the current task
            aiManager.currentTask?.cancel()
            
            //
            aiManager.currentTask = nil
            
            // Start a new task with the incremented retry count
                    
//            await Self.handleErrorWhenApplyingChunk(
//                error: error,
//                request: request,
//                currentAttempt: currentAttempt,
//                state: state)
            
        }
    }
    
    // some of this logic
    @MainActor
    private static func handleErrorWhenApplyingChunk(error: Error,
                                                     request: OpenAIRequest,
                                                     currentAttempt: Int,
                                                     state: StitchDocumentViewModel) async throws {
        
        guard let aiManager = state.aiManager else {
            fatalErrorIfDebug("handleErrorWhenApplyingChunk: no ai manager")
            return
        }
        
        if let error = (error as? StitchAIManagerError) {
            log("StitchAIManager error parsing steps: \(error.description)")
                        
            let availableNodeTypes = NodeType.allCases
                .filter { $0 != .none }
                .map { $0.display }
                .joined(separator: ", ")
            
            let errorMessage = switch error {
            case .nodeTypeParsing(let nodeType):
                "Invalid node type '\(nodeType)'. Available types are: [\(availableNodeTypes)]"
            case .portTypeDecodingError(let port):
                "Invalid port type '\(port)'. Check node's available port types in schema."
            case .actionValidationError(let msg):
                "Action validation failed: \(msg). Ensure actions match schema specifications."
            default:
                error.description
            }
            
            let lastError = "Try again, there were failures parsing the result. \(errorMessage)"
            
            try await aiManager.retryMakeOpenAIStreamingRequest(
                request,
                currentAttempts: currentAttempt,
                lastError: lastError,
                document: state)
        } else {
            log("StitchAIManager unknown error parsing steps: \(error.localizedDescription)")
            
            let lastError = "Try again, there were failures parsing the result. You may have tried to add incorrect nodes or port types. Available node types: [\(NodeType.allCases.filter { $0 != .none }.map { $0.display }.joined(separator: ", "))]"
            
            try await aiManager.retryMakeOpenAIStreamingRequest(
                request,
                currentAttempts: currentAttempt,
                lastError: lastError,
                document: state)
        }
        
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func handleErrorWhenMakingOpenAIStreamingRequest(_ error: Error, _ request: OpenAIRequest) {
        
        let document = self
        
        // Reset recording state
        document.llmRecording = .init()

        // TODO: comment below is slightly obscure -- what's going on here?
        // Reset checks which would later break new recording mode
        document.insertNodeMenuState = InsertNodeMenuState()
        
        if let error = error as? StitchAIManagerError,
           error.shouldDisplayModal {
            
            document.showErrorModal(
                message: error.description,
                userPrompt: request.prompt
            )
        } else {
            document.showErrorModal(
                message: "StitchAI handleRequest unknown error: \(error)",
                userPrompt: request.prompt
            )
        }
    }
}

extension Array where Element == Step {
    
    // Note: each Step could throw its own error; we just return the first error we encounter
    func convertSteps() -> Result<[any StepActionable], StitchAIStepHandlingError> {
        
        var convertedSteps = [any StepActionable]()
        
        for step in self {
            switch step.convertToType() {
            case .failure(let error):
                // Return first error we encounter
                return .failure(error)
            case .success(let converted):
                convertedSteps.append(converted)
            }
        }
        
        return .success(convertedSteps)
    }
    
    mutating func append(_ stepType: StepTypeAction) {
        self.append(stepType.toStep())
    }
    
    func containsNewNode(from id: NodeId) -> Bool {
        self.contains(where: { step in
            if step.stepType == .addNode,
               let addActionNodeId = step.nodeId {
                return addActionNodeId.value == id
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
            children: \(children?.description ?? "nil")
        )
        """
    }
}


extension StitchDocumentViewModel {
    @MainActor func handleStitchAIError(_ error: Error) {
        log("Error generating graph with StitchAI: \(error)", .logToServer)
        self.insertNodeMenuState.show = false
        self.insertNodeMenuState.isGeneratingAIResult = false
    }
}
