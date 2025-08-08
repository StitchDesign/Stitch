//
//  AICodeGenRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

struct AICodeGenFromGraphRequest: StitchAICodeCreator {
    static let type = StitchAIRequestBuilder_V0.StitchAIRequestType.userPrompt
    
    let id: UUID
    let userPrompt: String             // User's input prompt
    let swiftUICodeOfGraph: String
    
    @MainActor
    init(prompt: String,
         swiftUICodeOfGraph: String) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.swiftUICodeOfGraph = swiftUICodeOfGraph
    }
    
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager,
                    dataGlossaryPrompt: String) async throws -> String {
        log("AICodeGenFromGraphRequest.createCode initial code:\n\(self.swiftUICodeOfGraph)")
        
        let editInputs = StitchAIRequestBuilder_V0.EditCodeParams(
            source_code: swiftUICodeOfGraph,
            user_prompt: userPrompt)
        
        // Request for code edit
        let codeEditRequest = try OpenAIChatCompletionRequest(
            id: self.id,
            requestType: Self.type,
            dataGlossaryPrompt: dataGlossaryPrompt,
            assistantPrompt: try StitchAIManager.aiCodeEditSystemPromptGenerator(requestType: Self.type),
            inputs: editInputs)
        
        let codeEditResult = try await codeEditRequest
            .request(document: document,
                     aiManager: aiManager)
        
        return codeEditResult
    }
}

struct AICodeGenWithImageRequest: StitchAICodeCreator {
    static let type = StitchAIRequestBuilder_V0.StitchAIRequestType.imagePrompt
    
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
    
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager,
                    dataGlossaryPrompt: String) async throws -> String {
        log("AICodeGenWithImageRequest.createCode initial code:\n\(self.swiftUICodeOfGraph)")
        
        let editInputs = StitchAIRequestBuilder_V0.EditCodeParams(
            source_code: swiftUICodeOfGraph,
            user_prompt: userPrompt)
        
        // If we have an image, use the vision request; otherwise use the regular request
        if let imageData = base64Image {
            // Request for code edit with image
            let visionEditRequest = try OpenAIVisionChatCompletionRequest(
                id: self.id,
                requestType: Self.type,
                dataGlossaryPrompt: dataGlossaryPrompt,
                assistantPrompt: try StitchAIManager.aiCodeEditSystemPromptGenerator(requestType: Self.type),
                textInput: try editInputs.encodeToString(),
                base64Image: imageData)
            
            let codeEditResult = try await visionEditRequest
                .request(document: document,
                         aiManager: aiManager)
            
            return codeEditResult
        } else {
            // Fallback to regular text-only request
            let codeEditRequest = try OpenAIChatCompletionRequest(
                id: self.id,
                requestType: Self.type,
                dataGlossaryPrompt: dataGlossaryPrompt,
                assistantPrompt: try StitchAIManager.aiCodeEditSystemPromptGenerator(requestType: Self.type),
                inputs: editInputs)
            
            let codeEditResult = try await codeEditRequest
                .request(document: document,
                         aiManager: aiManager)
            
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
                let actionsResult = try await request
                    .processRequest(userPrompt: userPrompt,
                                    document: document,
                                    aiManager: aiManager,
                                    dataGlossaryPrompt: dataGlossaryPrompt)
                
                let graphData = actionsResult.graphData
                let allDiscoveredErrors = actionsResult.caughtErrors
                
                logToServerIfRelease("SUCCESS Patch Builder:\n\((try? graphData.encodeToPrintableString()) ?? "")")
                
                DispatchQueue.main.async { [weak document] in
                    guard let document = document else { return }
                    
                    do {
                        try graphData
                            .applyAIGraph(to: document,
                                          viewStatePatchConnections: actionsResult.graphData .viewStatePatchConnections,
                                          requestType: Self.type)
                        
#if STITCH_AI_TESTING || DEBUG || DEV_DEBUG
                        // Display parsing warnings
                        if !allDiscoveredErrors.isEmpty {
                            let caughtErrorsString = allDiscoveredErrors.reduce(into: "") { stringBuilder, error in
                                stringBuilder += "\n\(error)"
                            }
                            
                            document.storeDelegate?.alertState.stitchFileError = .unknownError("Warnings for the following unknown concepts:\(caughtErrorsString)")
                        }
#endif
                        
                    } catch {
                        logToServerIfRelease("Error applying AI graph: \(error.localizedDescription)")
                        document.storeDelegate?.alertState.stitchFileError = .unknownError("\(error)")
                    }
                    
                    document.aiManager?.currentTaskTesting = nil
                    document.insertNodeMenuState.show = false
                }
                
                return .success(graphData)
            } catch {
                return .failure(StitchStore.displayError(failure: error,
                                                         document: document))
            }
        }
    }

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
        

        let codeParserResult = SwiftUIViewVisitor.parseSwiftUICode(swiftUICode,
                                                                   varNameIdMap: [:])
        
        logToServerIfRelease("StitchAICodeCreator codeParserResult:\n\(codeParserResult)")
        
        let actionsResult = try codeParserResult.deriveStitchActions()
        
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
        document.aiManager?.currentTaskTesting = nil
        document.insertNodeMenuState.show = false
        
        // Display error
        document.storeDelegate?.alertState.stitchFileError = .unknownError("\(failure)")
        return failure
    }
}
