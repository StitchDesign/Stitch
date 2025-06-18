//
//  AIGraphCreationRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

enum AIGraphCreationRequestError: Error {
    case emptySteps
    case validationFailed(StitchAIStepHandlingError)
}

// Helpful util
func structuredOutputsSchemaAsString() -> String  {
    let structuredOutputs = CurrentAIGraphCreationResponseFormat.AIGraphCreationResponseFormat().json_schema.schema
    return try! structuredOutputs.encodeToPrintableString()
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
        self.body = try AIGraphCreationRequestBody(secrets: secrets,
                                                   userPrompt: prompt)
    }
    
    @MainActor
    static func createAndMakeRequest(prompt: String,
                                     aiManager: StitchAIManager,
                                     document: StitchDocumentViewModel) throws {
        guard let aiManager = document.aiManager else {
            fatalErrorIfDebug("GenerateAINode: no aiManager")
            return
        }
        
        let graph = document.visibleGraph
        
        do {
            let request = try AIGraphCreationRequest(prompt: prompt,
                                                     secrets: aiManager.secrets,
                                                     graph: graph)
                        
            // Wipe current task; maybe share user-prompt
            aiManager.prepareRequest(
                userPrompt: prompt,
                requestId: request.id,
                document: document)
            
            aiManager.currentTask = .init(task: aiManager.getOpenAITask(
                request: request,
                attempt: 0,
                document: document,
                canShareAIRetries: StitchStore.canShareAIData))
            
        } catch {
            fatalErrorIfDebug("Unable to generate Stitch AI prompt with error: \(error.localizedDescription)")
        }
    }
        
    static func validateResponse(decodedResult: AIGraphCreationContentJSON) throws -> [any StepActionable] {
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
    func onSuccessfulDecodingChunk(result: Step,
                                   currentAttempt: Int) {
        dispatch(ChunkProcessed(
            newStep: result,
            request: self,
            currentAttempt: currentAttempt
        ))
    }
    
    static func buildResponse(from streamingChunks: [Step]) throws -> AIGraphCreationContentJSON {
        .init(steps: streamingChunks)
    }
}

// NOTE: used by graph-generation, ai-javascript-node, etc.
extension StitchAIManager {
    /// Clears state and may log to Supabase.
    @MainActor
    func prepareRequest(userPrompt: String,
                        requestId: UUID,
                        document: StitchDocumentViewModel) {
        
        print("🤖 🔥 GENERATE AI NODE - STARTING AI GENERATION MODE 🔥 🤖")
        print("🤖 Prompt: \(userPrompt)")
        
        // Only log pre-request user prompts if we're in a release build and user has granted permissions
#if RELEASE || DEV_DEBUG
        if StitchStore.canShareAIData {
            Task(priority: .background) { [weak document] in
                
#if !STITCH_AI_V1
                guard let document = document,
                      let aiManager = document.aiManager else {
                    return
                }
                try? await aiManager.uploadUserPromptRequestToSupabase(
                    prompt: userPrompt,
                    requestId: requestId,
                    tableName: tableName)
#else
                let userPromptData = AIGraphCreationSupabase.UserPrompt(
                    request_id: requestId,
                    user_prompt: userPrompt
                )
                try await userPromptData.uploadToSupabase(client: aiManager.postgrest)
#endif
            }
        }
#endif
        
        // Make sure current task is completely wiped
        self.cancelCurrentRequest()
        self.currentTask = nil
        
        // Clear previous streamed steps
        document.llmRecording.streamedSteps = .init()
        
        // Clear the previous actions
        document.llmRecording.actions = .init()
        
        // Set flag to indicate this is from AI generation
        document.insertNodeMenuState.isFromAIGeneration = true
        
        print("🤖 isFromAIGeneration set to: \(document.insertNodeMenuState.isFromAIGeneration)")
        
        // Track initial graph state
        document.llmRecording.initialGraphState = document.visibleGraph.createSchema()
    }
}

extension CurrentStep.Step {
    // Note: it's slightly awkward in Swift to handle protocol-implementing concrete types
    func parseAsStepAction() -> Result<any StepActionable, StitchAIStepHandlingError> {
        switch self.stepType {
        case .addNode:
            return StepActionAddNode.fromStep(self).map { $0 as any StepActionable}
        case .connectNodes:
            return StepActionConnectionAdded.fromStep(self).map { $0 as any StepActionable}
        case .changeValueType:
            return StepActionChangeValueType.fromStep(self).map { $0 as any StepActionable}
        case .setInput:
            return StepActionSetInput.fromStep(self).map { $0 as any StepActionable}
        case .sidebarGroupCreated:
            return StepActionLayerGroupCreated.fromStep(self).map { $0 as any StepActionable}
//        case .editJSNode:
//            return StepActionEditJSNode.fromStep(self).map { $0 as any StepActionable}
        }
    }
}
