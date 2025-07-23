//
//  AICodeGenRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

struct AICodeGenFromGraphRequest: StitchAICodeCreator {
    let type = StitchAIRequestBuilder_V0.StitchAIRequestType.userPrompt
    
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AICodeGenRequestBody_V0.AICodeGenRequestBody
    static let willStream: Bool = false
    
    @MainActor
    init(prompt: String,
         currentGraphData: CurrentAIGraphData.GraphData,
         systemPrompt: String,
         config: OpenAIRequestConfig = .default) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.config = config
        
        // Construct http payload
        self.body = try AICodeGenRequestBody_V0
            .AICodeGenRequestBody(currentGraphData: currentGraphData,
                                  systemPrompt: systemPrompt)
    }
    
    func createAssistantPrompt() throws -> String {
        try StitchAIManager.aiCodeGenSystemPromptGenerator(requestType: self.type)
    }
    
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager,
                    systemPrompt: String) async throws -> String {
        
        fatalError("come back, look at image")
        
        let msgFromSourceCodeRequest = try await self
            .requestForMessage(document: document,
                               aiManager: aiManager)
        
//        let decodedSwiftUICode = try self
//            .decodeMessage(from: msgFromSourceCodeRequest,
//                           document: document,
//                           aiManager: aiManager,
//                           resultType: StitchAIRequestBuilder_V0.SourceCodeResponse.self)
//        logToServerIfRelease("Initial code:\n\(decodedSwiftUICode.source_code)")
        
        let newCodeToolMessage = try msgFromSourceCodeRequest.createNewToolMessage()
        
        let createEditFunctionRequest = AICodeEditRequest(
            id: self.id,
            prompt: self.userPrompt,
            toolMessages: [msgFromSourceCodeRequest, newCodeToolMessage],
            systemPrompt: systemPrompt)
        
        let allPrevMessages = createEditFunctionRequest.body.messages
        
        let editRequest = try AICodeEditRequest(id: self.id,
                                                prevMessages: allPrevMessages)
        
        let msgFromEditCodeRequest = try await editRequest
            .requestForMessage(
                document: document,
                aiManager: aiManager)
        
        // TODO: what happens here??? What does the decoded swift ui code look like
        fatalError()
        
//        let decodedSwiftUIEditedCode = try editRequest
//            .decodeMessage(from: msgFromEditCodeRequest,
//                           document: document,
//                           aiManager: aiManager,
//                           resultType: StitchAIRequestBuilder_V0.SourceCodeResponse.self)
//        let swiftUIEditedCode = decodedSwiftUIEditedCode.source_code
//        
//        logToServerIfRelease("Edited code:\n\(swiftUIEditedCode)")
//        return (swiftUIEditedCode, msgFromEditCodeRequest)
    }
}

struct AICodeGenFromImageRequest: StitchAICodeCreator {
    let type = StitchAIRequestBuilder_V0.StitchAIRequestType.imagePrompt
    
    let id: UUID
    let userPrompt: String
    let base64Image: String
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AICodeGenRequestBody_V0.AICodeGenRequestBody
    static let willStream: Bool = false
    
    init(prompt: String,
         systemPrompt: String,
         base64ImageDescription: String,
         config: OpenAIRequestConfig = .default) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        self.userPrompt = prompt
        self.base64Image = base64ImageDescription
        self.config = config
        
        // Construct http payload
        self.body = AICodeGenRequestBody_V0
            .AICodeGenRequestBody(messages: [],
                                  type: self.type)
//            .AICodeGenRequestBody(userPrompt: prompt,
//                                  systemPrompt: systemPrompt,
//                                  base64ImageDescription: base64ImageDescription)
    }
    
    // Object for creating actual code creation request
//    init(id: UUID,
//         userPrompt: String,
//         base64Image: String,
//         messages: [OpenAIMessage]) {
//        self.id = id
//        self.userPrompt = userPrompt
//        self.base64Image = base64Image
//        self.config = .default
//        self.body = .init(messages: messages,
//                          type: self.type)
//    }
    
    func createAssistantPrompt() throws -> String {
        try StitchAIManager.aiCodeGenSystemPromptGenerator(requestType: self.type)
    }
    
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager,
                    systemPrompt: String) async throws -> String {
        let imageRequestInputs = AICodeGenFromImageInputs(
            user_prompt: self.userPrompt,
            image_data: .init(base64Image: self.base64Image)
        )
        
        let toolMessages = try self.createToolMessages(inputsArguments: imageRequestInputs)
        
        let createCodeRequest = AIProcessCodeGenRequest(
            id: self.id,
            type: self.type,
            messages: [
                .init(role: .system, content: systemPrompt)
                ] + toolMessages
        )
        
        let msgFromCodeCreation = try await createCodeRequest
            .requestForMessage(document: document,
                               aiManager: aiManager)

        let decodedSwiftUICode = try self
            .decodeMessage(from: msgFromCodeCreation,
                           document: document,
                           aiManager: aiManager,
                           resultType: StitchAIRequestBuilder_V0.SourceCodeResponse.self)
        logToServerIfRelease("Initial code:\n\(decodedSwiftUICode.source_code)")
        
//        guard let codeCreationContent = msgFromCodeCreation.content else {
//            throw StitchAIManagerError.functionDecodingFailed
//        }
//        
//        let decodedSwiftUICode = try JSONDecoder().decode(StitchAIRequestBuilder_V0.SourceCodeResponse.self,
//                                                          from: try codeCreationContent.encodeToData())
//
        return decodedSwiftUICode.source_code
    }
}

struct AIProcessCodeGenRequest: StitchAIFunctionRequestable {
    let id: UUID
    let type: StitchAIRequestBuilder_V0.StitchAIRequestType
    let config: OpenAIRequestConfig = .default
    let body: AICodeGenRequestBody_V0.AICodeGenRequestBody
    static let willStream: Bool = false
    
    // Object for creating actual code creation request
    init(id: UUID,
         type: StitchAIRequestBuilder_V0.StitchAIRequestType,
         messages: [OpenAIMessage]) {
        self.id = id
        self.type = type
        self.body = .init(messages: messages,
                          type: type,
                          functionType: .processCode)
    }
}

extension StitchAICodeCreator {
    @MainActor
    func getRequestTask(userPrompt: String,
                        document: StitchDocumentViewModel) throws -> Task<Result<AIGraphData_V0.GraphData, any Error>, Never> {
        let systemPrompt = try StitchAIManager.stitchAIGraphBuilderSystem(graph: document.visibleGraph,
                                                                          requestType: self.type)
        let request = self
        
        return Task(priority: .high) { [weak document] in
            guard let document = document,
                  let aiManager = document.aiManager else {
                log("getRequestTask: AICodeGenRequest: getRequestTask: no document or ai manager", .logToServer)
                
                if let document: StitchDocumentViewModel = document {
                    return .failure(Self.displayError(failure: StitchAIManagerError.secretsNotFound,
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
                                                   requestType: self.type)
                        
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
                return .failure(Self.displayError(failure: error,
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
        
        log("SUCCESS: swiftUICode: \(swiftUICode)")
        
        // TODO: look here, make sure extraction is good
        
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
        
        // Update tool message with layer data
//        var newEditToolMessage = try msgFromCode.createNewToolMessage()
        //         let patchBuilderInputs = AIPatchBuilderRequestBody_V0.AIPatchBuilderFunctionInputs(
        //             swiftui_source_code: swiftUICode,
        //             layer_data: layerDataList
        //         )
        //         newEditToolMessage.content = try patchBuilderInputs.encodeToPrintableString()
        
        let patchBuilderRequest = try AIPatchBuilderRequest(
            id: self.id,
            swiftUICode: swiftUICode,
            layerDataList: layerDataList,
            requestType: self.type,
            systemPrompt: systemPrompt)
        
        let patchBuildMessage = try await patchBuilderRequest
            .requestForMessage(document: document,
                               aiManager: aiManager)
        
        let patchBuildResult = try patchBuilderRequest
            .decodeMessage(from: patchBuildMessage,
                           document: document,
                           aiManager: aiManager,
                           resultType: CurrentAIGraphData.PatchData.self)
//        guard let patchBuildContent = patchBuildMessage.content else {
//            throw StitchAIManagerError.functionDecodingFailed
//        }
//        
//        let patchBuildResult = try JSONDecoder().decode(CurrentAIGraphData.PatchData.self,
//                                                        from: patchBuildContent.encodeToData())
//        
        logToServerIfRelease("Successful patch builder result: \(try patchBuildResult.encodeToPrintableString())")
        let graphData = AIGraphData_V0.GraphData(layer_data_list: layerDataList,
                                                 patch_data: patchBuildResult)
        return (graphData, allDiscoveredErrors)
    }
}

extension StitchAIGraphBuilderRequestable {
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
