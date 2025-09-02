//
//  AICodeGenRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

// fka `AICodeGenFromGraphRequest`
struct AICodeGenWithImageRequest: StitchAICodeCreator {
    static let type = StitchAIRequestBuilder_V0.StitchAIRequestType.userPrompt
    
    let id: UUID
    let userPrompt: String
    let swiftUICodeOfGraph: String
    let base64Image: String?
    
    @MainActor
    init(prompt: String,
         swiftUICodeOfGraph: String,
         base64Image: String? = nil) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        self.userPrompt = prompt
        self.swiftUICodeOfGraph = swiftUICodeOfGraph
        self.base64Image = base64Image
    }
    
    @MainActor
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager,
                    dataGlossaryPrompt: String) async throws -> String {
        log("AICodeGenWithImageRequest.createCode initial code:\n\(self.swiftUICodeOfGraph)")
        
        let editInputs = StitchAIRequestBuilder_V0.EditCodeParams(
            source_code: swiftUICodeOfGraph,
            user_prompt: userPrompt)
        
        // If we have an image, use the vision request; otherwise use the regular request
        if let imageData = base64Image {
            // Validate parameters for the selected model
            let selectedModel = document.openaiModel.asOpenAIModel
            let validatedVerbosity = OpenAIModelConstraints.validateVerbosity(for: selectedModel, requestedVerbosity: document.openaiVerbosity)
            let validatedReasoningEffort = OpenAIModelConstraints.validateReasoningEffort(for: selectedModel, requestedEffort: document.openaiReasoningEffort)
            
            // Debug print OpenAI configuration
            log("🤖 Vision Request - Model: \(document.openaiModel), Verbosity: \(validatedVerbosity) (requested: \(document.openaiVerbosity)), Reasoning Effort: \(validatedReasoningEffort) (requested: \(document.openaiReasoningEffort))")
            
            // TODO: consolidate `OpenAIVisionChatCompletionRequest` and `OpenAIChatCompletionRequest`
            // Request for code edit with image
            let visionEditRequest = try OpenAIVisionChatCompletionRequest(
                id: self.id,
                requestType: Self.type,
                dataGlossaryPrompt: dataGlossaryPrompt,
                assistantPrompt: try StitchAIManager.aiCodeEditSystemPromptGenerator(requestType: Self.type, previewWindowSize: document.previewWindowSize, previewWindowBackgroundColor: document.previewWindowBackgroundColor),
                textInput: try editInputs.encodeToString(),
                base64Image: imageData,
                model: document.openaiModel,
                verbosity: validatedVerbosity,
                reasoningEffort: validatedReasoningEffort,
                willStream: false)
            
            let startTime = CFAbsoluteTimeGetCurrent()
            let codeEditResult = try await visionEditRequest
                .request(document: document,
                         aiManager: aiManager)
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            log("⏱️ OpenAI Vision Request completed in \(String(format: "%.2f", duration)) seconds")
            
            return codeEditResult
        } else {
            // Validate parameters for the selected model
            let selectedModel = document.openaiModel.asOpenAIModel
            let validatedVerbosity = OpenAIModelConstraints.validateVerbosity(for: selectedModel, requestedVerbosity: document.openaiVerbosity)
            let validatedReasoningEffort = OpenAIModelConstraints.validateReasoningEffort(for: selectedModel, requestedEffort: document.openaiReasoningEffort)
            
            // Debug print OpenAI configuration
            log("🤖 Regular Request - Model: \(document.openaiModel), Verbosity: \(validatedVerbosity) (requested: \(document.openaiVerbosity)), Reasoning Effort: \(validatedReasoningEffort) (requested: \(document.openaiReasoningEffort))")
            
            // Fallback to regular text-only request
            let codeEditRequest = try OpenAIChatCompletionRequest(
                id: self.id,
                requestType: Self.type,
                dataGlossaryPrompt: dataGlossaryPrompt,
                assistantPrompt: try StitchAIManager.aiCodeEditSystemPromptGenerator(requestType: Self.type, previewWindowSize: document.previewWindowSize, previewWindowBackgroundColor: document.previewWindowBackgroundColor),
                inputs: editInputs,
                model: document.openaiModel,
                verbosity: validatedVerbosity,
                reasoningEffort: validatedReasoningEffort)
            
            let startTime = CFAbsoluteTimeGetCurrent()
            let codeEditResult = try await codeEditRequest
                .request(document: document,
                         aiManager: aiManager)
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            log("⏱️ OpenAI Regular Request completed in \(String(format: "%.2f", duration)) seconds")
            
            return codeEditResult
        }
    }
}

extension StitchAICodeCreator {
    @MainActor
    func getRequestTask(userPrompt: String,
                        document: StitchDocumentViewModel) throws -> Task<Result<AIGraphData_V0.GraphData, any Error>, Never> {
        log("getRequestTask: user prompt: \(userPrompt)")
        
        let dataGlossaryPrompt = try StitchAIManager
            .stitchAIDataGlossarySystemPrompt(graph: document.visibleGraph)
        let request = self
        
        return Task(priority: .high) { [weak document] in
            guard let document = document,
                  let aiManager = document.aiManager else {
                log("getRequestTask: AICodeGenRequest: getRequestTask: no document or ai manager", .logToServer)
                
                if let document: StitchDocumentViewModel = document {
                    return .failure(StitchStore.displayError(failure: StitchAIManagerError.secretsNotFound,
                                                             document: document))
                } else {
                    return .failure(StitchAIManagerError.secretsNotFound)
                }
            }
            
            do {
                var actionsResult = try await request
                    .processRequest(userPrompt: userPrompt,
                                    document: document,
                                    aiManager: aiManager,
                                    dataGlossaryPrompt: dataGlossaryPrompt)
                
                logToServerIfRelease("SUCCESS Patch Builder:\n\((try? actionsResult.graphData.encodeToPrintableString()) ?? "")")
                
                DispatchQueue.main.async { [weak document] in
                    guard let document = document else { return }
                    
                    Task(priority: .high) {
                        await actionsResult
                            .applyAIGraph(to: document,
                                          viewStatePatchConnections: actionsResult.graphData .viewStatePatchConnections,
                                          requestType: Self.type)
                    }
                    
                    document.aiManager?.currentTask = nil
                    document.insertNodeMenuState.show = false
                }
                
                return .success(actionsResult.graphData)
            } catch {
                return .failure(StitchStore.displayError(failure: error,
                                                         document: document))
            }
        }
    }

    @MainActor
    private func processRequest(userPrompt: String,
                                document: StitchDocumentViewModel,
                                aiManager: StitchAIManager,
                                dataGlossaryPrompt: String) async throws -> SwiftSyntaxActionsResult {
        logToServerIfRelease("SUCCESS: userPrompt: \(userPrompt)")
        
        let swiftUICode = try await self
            .createCode(document: document,
                        aiManager: aiManager,
                        dataGlossaryPrompt: dataGlossaryPrompt)

        logToServerIfRelease("StitchAICodeCreator swiftUICode:\n\(swiftUICode)")
        
//        guard let parsedVarBody = VarBodyParser.extract(from: swiftUICode) else {
//            logToServerIfRelease("SwiftUISyntaxError.couldNotParseVarBody.localizedDescription: \(SwiftUISyntaxError.couldNotParseVarBody.localizedDescription)")
//            throw SwiftUISyntaxError.couldNotParseVarBody
//        }
        
//        logToServerIfRelease("parsedVarBody:\n\(parsedVarBody)")
        

        let codeParserResult = SwiftUIViewVisitor.parseSwiftUICode(swiftUICode)
        
        logToServerIfRelease("StitchAICodeCreator codeParserResult:\n\(codeParserResult)")
        
        let actionsResult = codeParserResult.deriveStitchActions(bindingDeclarations: codeParserResult.bindingDeclarations)
        
        print("Derived Stitch layer data:\n\((try? actionsResult.encodeToPrintableString()) ?? "")")
        
        return actionsResult
    }
}

extension StitchStore {
    @MainActor
    static func displayError(failure: any Error,
                             document: StitchDocumentViewModel) -> any Error {
        log("AICodeGenRequest: getRequestTask: request.request: failure: \(failure.localizedDescription)", .logToServer)
        print(failure.localizedDescription)
        document.aiManager?.currentTask = nil
        document.insertNodeMenuState.show = false
        
        // Display error
        document.storeDelegate?.alertState.stitchFileError = .unknownError("\(failure)")
        return failure
    }
}
