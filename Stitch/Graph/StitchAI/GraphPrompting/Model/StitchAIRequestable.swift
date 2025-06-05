//
//  StitchAIRequestable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/31/25.
//

import SwiftUI
import StitchSchemaKit

// If this is not a valid URL, we should not even be able to run the app.
let OPEN_AI_BASE_URL_STRING = "https://api.openai.com/v1/chat/completions"
let OPEN_AI_BASE_URL: URL = URL(string: OPEN_AI_BASE_URL_STRING)!

// Note: an event is usually not a long-lived data structure; but this is used for retry attempts.
/// Main event handler for initiating OpenAI API requests
protocol StitchAIRequestable: Sendable where InitialDecodedResult: Decodable, TokenDecodedResult: Decodable {
    associatedtype Body: StitchAIRequestBodyFormattable
    // Initial payload that's expected from OpenAI response
    associatedtype InitialDecodedResult
    // Final data type after all processing, may equal InitialDecodedResult
    associatedtype FinalDecodedResult
    // Type that's processed from streaming
    associatedtype TokenDecodedResult
    typealias ResponseFormat = Body.ResponseFormat
    
    var id: UUID { get }
    var userPrompt: String { get }             // User's input prompt
    var config: OpenAIRequestConfig { get } // Request configuration settings
    var body: Body { get }
    static var willStream: Bool { get }
    
    @MainActor
    func makeRequest(canShareAIRetries: Bool,
                     document: StitchDocumentViewModel)
    
    /// Validates a successfully decoded response and outputs a possibly different data structure.
    static func validateRepopnse(decodedResult: InitialDecodedResult) throws -> FinalDecodedResult
    
    @MainActor
    func onSuccessfulRequest(result: FinalDecodedResult,
                             aiManager: StitchAIManager,
                             document: StitchDocumentViewModel) throws
    
    @MainActor
    func onSuccessfulDecodingChunk(result: TokenDecodedResult,
                                   currentAttempt: Int)
}

extension StitchAIRequestable {
    func getPayloadData() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self.body)
    }
}

enum AIGraphCreationRequestError: Error {
    case emptySteps
    case validationFailed(StitchAIStepHandlingError)
}

struct AIGraphCreationRequest: StitchAIRequestable {
    typealias InitialDecodedResult = AIGraphCreationContentJSON
    
    private static let OPEN_AI_BASE_URL = "https://api.openai.com/v1/chat/completions"
    
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AIGraphCreationRequestBody
    static let willStream: Bool = true
    
    /// Initialize a new request with prompt and optional configuration
    @MainActor
    init(prompt: String,
         secrets: Secrets,
         config: OpenAIRequestConfig = .default,
         graph: GraphState) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.config = config

        // Construct http payload
        self.body = AIGraphCreationRequestBody(secrets: secrets,
                                               userPrompt: prompt)
    }
    
    @MainActor
    static func createAndMakeRequest(prompt: String,
                                     canShareAIRetries: Bool,
                                     aiManager: StitchAIManager,
                                     document: StitchDocumentViewModel) throws {
        guard let secrets = document.aiManager?.secrets else {
            fatalErrorIfDebug("GenerateAINode: no aiManager")
            return
        }
        
        let graph = document.visibleGraph
        
        do {
            let request = try AIGraphCreationRequest(prompt: prompt,
                                                     secrets: secrets,
                                                     graph: graph)
            
            Task(priority: .high) { [weak document] in
                guard let document = document,
                      let aiManager = document.aiManager else {
                    fatalErrorIfDebug()
                    return
                }
                
                try await aiManager.uploadUserPromptRequestToSupabase(
                    prompt: prompt,
                    requestId: request.id)
            }
            
            request.makeRequest(canShareAIRetries: canShareAIRetries,
                                document: document)
        } catch {
            fatalErrorIfDebug("Unable to generate Stitch AI prompt with error: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func makeRequest(canShareAIRetries: Bool,
                     document: StitchDocumentViewModel) {
        print("🤖 🔥 GENERATE AI NODE - STARTING AI GENERATION MODE 🔥 🤖")
        print("🤖 Prompt: \(self.userPrompt)")
        
        guard let aiManager = document.aiManager else {
            fatalErrorIfDebug("GenerateAINode: no aiManager")
            return
        }
        
        // Make sure current task is completely wiped
        aiManager.cancelCurrentRequest()
        aiManager.currentTask = nil
        
        // Clear previous streamed steps
        document.llmRecording.streamedSteps = .init()
        
        // Clear the previous actions
        document.llmRecording.actions = .init()
                
        // Set loading state
        withAnimation { // added
            document.insertNodeMenuState.isGeneratingAIResult = true
        }
        
        // Set flag to indicate this is from AI generation
        document.insertNodeMenuState.isFromAIGeneration = true
        
        print("🤖 isFromAIGeneration set to: \(document.insertNodeMenuState.isFromAIGeneration)")
        
        // Track initial graph state
        document.llmRecording.initialGraphState = document.visibleGraph.createSchema()
        
        // Create the task and set it on the manager
        aiManager.currentTask = CurrentAITask(task: aiManager.getOpenAITask(
            request: self,
            attempt: 1,
            document: document,
            canShareAIRetries: canShareAIRetries))
    }
    
    static func validateRepopnse(decodedResult: AIGraphCreationContentJSON) throws -> [any StepActionable] {
        let convertedSteps = decodedResult.steps.map { $0.parseAsStepAction() }
        
        // Catch steps that didn't convert
        let nonConvertedSteps = convertedSteps.compactMap { $0.error }
        guard nonConvertedSteps.isEmpty else {
            log("makeNonStreamedRequest: empty results")
            throw AIGraphCreationRequestError.emptySteps
        }
        
        return convertedSteps.compactMap(\.value)
    }
    
    @MainActor
    func onSuccessfulRequest(result: [any StepActionable],
                             aiManager: StitchAIManager,
                             document: StitchDocumentViewModel) throws {
        if let error = document.validateAndApplyActions(result) {
            fatalErrorIfDebug(error.description)
            throw AIGraphCreationRequestError.validationFailed(error)
        }
        
        aiManager.openAIStreamingCompleted(originalPrompt: self.userPrompt,
                                           request: self,
                                           document: document)
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: Step,
                                   currentAttempt: Int) {
        dispatch(ChunkProcessed(
            newStep: result,
            request: self,
            currentAttempt: currentAttempt
        ))
    }
}

struct AIEditJSNodeRequest: StitchAIRequestable {
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AIEditJsNodeRequestBody
    static let willStream: Bool = false
    
    // Tracks origin node of request
    let nodeId: NodeId
    
    enum EditJSNodeRequestError: Error {
        case noNodeFound
    }
    
    @MainActor
    init(prompt: String,
         config: OpenAIRequestConfig = .default,
         document: StitchDocumentViewModel,
         nodeId: NodeId) throws {
        guard let secrets = document.aiManager?.secrets else {
            throw StitchAIManagerError.secretsNotFound
        }
        
        self.init(prompt: prompt,
                  secrets: secrets,
                  config: config,
                  graph: document.visibleGraph,
                  nodeId: nodeId)
    }
    
    @MainActor
    init(prompt: String,
         secrets: Secrets,
         config: OpenAIRequestConfig = .default,
         graph: GraphState,
         nodeId: NodeId) {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.config = config
        self.nodeId = nodeId
        
        // Construct http payload
        self.body = AIEditJsNodeRequestBody(secrets: secrets,
                                            userPrompt: prompt)
    }
    
    @MainActor
    func makeRequest(canShareAIRetries: Bool,
                     document: StitchDocumentViewModel) {
        guard let aiManager = document.aiManager else {
            fatalErrorIfDebug("GenerateAINode: no aiManager")
            return
        }
        
        // Create the task and set it on the manager
        aiManager.currentTask = CurrentAITask(task: aiManager.getOpenAITask(
            request: self,
            attempt: 1,
            document: document,
            canShareAIRetries: canShareAIRetries))
    }
    
    static func validateRepopnse(decodedResult: JavaScriptNodeSettingsAI) throws -> JavaScriptNodeSettings {
        .init(script: decodedResult.script,
              inputDefinitions: try decodedResult.input_definitions.map(JavaScriptPortDefinition.init),
              outputDefinitions: try decodedResult.output_definitions.map(JavaScriptPortDefinition.init))
    }
    
    @MainActor
    func onSuccessfulRequest(result: JavaScriptNodeSettings,
                             aiManager: StitchAIManager,
                             document: StitchDocumentViewModel) throws {
        guard let patchNode = document.visibleGraph.getNode(self.nodeId)?.patchNode else {
            log("EditJSNodeRequest error: no node found.")
            throw EditJSNodeRequestError.noNodeFound
        }
        
        return patchNode.processNewJavascript(response: result)
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: JavaScriptNodeSettings,
                                   currentAttempt: Int) {
        fatalErrorIfDebug("No JavaScript node support for streaming.")
    }
}
