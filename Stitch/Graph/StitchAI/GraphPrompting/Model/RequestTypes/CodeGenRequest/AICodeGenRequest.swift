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
    let currentGraphData: CurrentAIGraphData.CodeCreatorParams
    
    @MainActor
    init(prompt: String,
         currentGraphData: CurrentAIGraphData.CodeCreatorParams) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.currentGraphData = currentGraphData
    }
    
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager,
                    systemPrompt: String) async throws -> String {
        // Request for code creation
        let codeCreateRequest = try OpenAIChatCompletionRequest(
            id: self.id,
            requestType: Self.type,
            systemPrompt: systemPrompt,
            assistantPrompt: try StitchAIManager.aiCodeGenSystemPromptGenerator(requestType: Self.type),
            inputs: self.currentGraphData)
        
        let codeResult = try await codeCreateRequest
            .request(document: document,
                     aiManager: aiManager)
        
        log("AICodeGenFromGraphRequest.createCode initial result:\n\(codeResult)")
        
        // Request for code edit
        let codeEditRequest = try OpenAIChatCompletionRequest(
            id: self.id,
            requestType: Self.type,
            systemPrompt: systemPrompt,
            assistantPrompt: try StitchAIManager.aiCodeEditSystemPromptGenerator(requestType: Self.type),
            inputs: self.userPrompt)
        
        let codeEditResult = try await codeEditRequest
            .request(document: document,
                     aiManager: aiManager)
        
        return codeEditResult
    }
}

struct AICodeGenFromImageRequest: StitchAICodeCreator {
    static let type = StitchAIRequestBuilder_V0.StitchAIRequestType.imagePrompt
    
    let id: UUID
    let userPrompt: String
    let base64Image: String
    
    init(prompt: String,
         base64ImageDescription: String) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        self.userPrompt = prompt
        self.base64Image = base64ImageDescription
    }
    
    func createAssistantPrompt() throws -> String {
        try StitchAIManager.aiCodeGenSystemPromptGenerator(requestType: Self.type)
    }
    
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager,
                    systemPrompt: String) async throws -> String {
        fatalError()
//
//        let imageRequestInputs = AICodeGenFromImageInputs(
//            user_prompt: self.userPrompt,
//            image_data: .init(base64Image: self.base64Image)
//        )
//        
//        let toolMessages = try OpenAIFunctionRequest.createInitialFnMessages(
//            functionType: .codeBuilderFromImage,
//            requestType: Self.type,
//            inputsArguments: imageRequestInputs,
//            systemPrompt: systemPrompt)
//        
//        let createCodeRequest = OpenAIFunctionRequest(
//            id: self.id,
//            functionType: .processCode,
//            requestType: Self.type,
//            messages: toolMessages)
//        
//        let msgFromCodeCreation = try await createCodeRequest
//            .requestMessageForFn(document: document, aiManager: aiManager)
//
//        let decodedSwiftUICode = try msgFromCodeCreation
//            .decodeMessage(document: document,
//                           aiManager: aiManager,
//                           resultType: StitchAIRequestBuilder_V0.SourceCodeResponse.self)
//
//        return decodedSwiftUICode.source_code
    }
}

extension StitchAICodeCreator {
    @MainActor
    func getRequestTask(userPrompt: String,
                        document: StitchDocumentViewModel) throws -> Task<Result<AIGraphData_V0.GraphData, any Error>, Never> {
        let systemPrompt = try StitchAIManager.stitchAIGraphBuilderSystem(graph: document.visibleGraph,
                                                                          requestType: Self.type)
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
                let (graphData, allDiscoveredErrors) = try await request
                    .processRequest(userPrompt: userPrompt,
                                    document: document,
                                    aiManager: aiManager,
                                    systemPrompt: systemPrompt)
                
                logToServerIfRelease("SUCCESS Patch Builder:\n\((try? graphData.encodeToPrintableString()) ?? "")")
                
                DispatchQueue.main.async { [weak document] in
                    guard let document = document else { return }
                    
                    do {
                        try graphData.applyAIGraph(to: document,
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
                                systemPrompt: String) async throws -> (AIGraphData_V0.GraphData, [SwiftUISyntaxError]) {
        log("SUCCESS: userPrompt: \(userPrompt)")
        
        let swiftUICode = try await self
            .createCode(document: document,
                        aiManager: aiManager,
                        systemPrompt: systemPrompt)

        logToServerIfRelease("StitchAICodeCreator swiftUICode:\n\(swiftUICode)")
        
        guard let parsedVarBody = VarBodyParser.extract(from: swiftUICode) else {
            logToServerIfRelease("SwiftUISyntaxError.couldNotParseVarBody.localizedDescription: \(SwiftUISyntaxError.couldNotParseVarBody.localizedDescription)")
            throw SwiftUISyntaxError.couldNotParseVarBody
        }
        
        logToServerIfRelease("parsedVarBody:\n\(parsedVarBody)")
        
        let codeParserResult = SwiftUIViewVisitor.parseSwiftUICode(parsedVarBody)
        var allDiscoveredErrors = codeParserResult.caughtErrors
        
        guard let viewNode = codeParserResult.rootView else {
            logToServerIfRelease("SwiftUISyntaxError.viewNodeNotFound.localizedDescription: \(SwiftUISyntaxError.viewNodeNotFound.localizedDescription)")
            throw SwiftUISyntaxError.viewNodeNotFound
        }
        
        let actionsResult = try viewNode.deriveStitchActions()
        
        print("Derived Stitch layer data:\n\((try? actionsResult.encodeToPrintableString()) ?? "")")
        
        let layerDataList = actionsResult.actions
        allDiscoveredErrors += actionsResult.caughtErrors
        
        let patchBuilderInputs = AIPatchBuilderFunctionInputs(
            swiftui_source_code: swiftUICode,
            layer_data_list: try layerDataList.encodeToString())
        
        let patchBuilderRequest = try OpenAIChatCompletionStructuredOutputsRequest(
            id: self.id,
            requestType: Self.type,
            systemPrompt: systemPrompt,
            assistantPrompt: try StitchAIManager.aiPatchBuilderSystemPromptGenerator(),
            responseFormat: AIPatchBuilderResponseFormat_V0.AIPatchBuilderResponseFormat(),
            inputs: patchBuilderInputs)
        
        let patchBuilderResult = try await patchBuilderRequest
            .request(document: document,
                     aiManager: aiManager)
        
        logToServerIfRelease("Successful patch builder result: \(try patchBuilderResult.encodeToPrintableString())")
        
        let graphData = AIGraphData_V0.GraphData(layer_data_list: layerDataList,
                                                 patch_data: patchBuilderResult)
        return (graphData, allDiscoveredErrors)
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
