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
        var allMessages = [OpenAIMessage(
            role: .system,
            content: systemPrompt
        )]
        
        // Create tool message for code creation
        let codeCreateRequestMessages = try OpenAIFunctionRequest
            .createInitialFnMessages(functionType: .codeBuilder,
                                     requestType: Self.type,
                                     inputsArguments: self.currentGraphData)
        allMessages += codeCreateRequestMessages
        
        // Request for code creation
        let codeCreateFnRequest = OpenAIFunctionRequest(
            id: self.id,
            functionType: .codeBuilder,
            requestType: Self.type,
            messages: allMessages)
        
        // Creates function stub for code create
        let createCodeToolCall = try await codeCreateFnRequest
            .requestMessageForFn(document: document,
                                 aiManager: aiManager)
    
        // Create tool message for code edit
        let codeEditRequestMessages = try OpenAIFunctionRequest
            .createChainedFnMessages(toolResponse: createCodeToolCall,
                                     functionType: .codeEditor,
                                     requestType: Self.type,
                                     inputsArguments: self.userPrompt)
        allMessages += codeEditRequestMessages
        
        let editRequest = OpenAIFunctionRequest(
            id: self.id,
            functionType: .codeEditor,
            requestType: Self.type,
            messages: allMessages)
        
        let editToolCall = try await editRequest
            .requestMessageForFn(document: document,
                                 aiManager: aiManager)
    
        // Debug only--print SwiftUI code result
#if !RELEASE
        if let initialSwiftUICode = try? editToolCall
            .decodeMessage(document: document,
                           aiManager: aiManager,
                           resultType: StitchAIRequestBuilder_V0.SourceCodeResponse.self) {
            log("AICodeGenFromGraphRequest initial code from graph:\n\(initialSwiftUICode.source_code)")
        }
#endif
        
        // Create tool message for code processing
        let codeProcessingRequestMessages = try OpenAIFunctionRequest
            .createChainedFnMessages(toolResponse: editToolCall,
                                     functionType: .processCode,
                                     requestType: Self.type,
                                     inputsArguments: self.userPrompt)
        allMessages += codeProcessingRequestMessages
        
        let processCodeRequest = OpenAIFunctionRequest(
            id: self.id,
            functionType: .processCode,
            requestType: Self.type,
            messages: allMessages)
        
        let processToolCall = try await processCodeRequest
            .requestMessageForFn(document: document,
                                 aiManager: aiManager)
        
        let decodedSwiftUICode = try processToolCall
            .decodeMessage(document: document,
                           aiManager: aiManager,
                           resultType: StitchAIRequestBuilder_V0.SourceCodeResponse.self)
        
        return decodedSwiftUICode.source_code
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
            layer_data_list: layerDataList)
        
        fatalError()
//
//        // Create new tool messages for patch builder
//        let patchBuilderToolMessages = try OpenAIFunctionRequest
//            .createInitialFnMessages(functionType: .patchBuilder,
//                                     requestType: Self.type,
//                                     inputsArguments: patchBuilderInputs,
//                                     systemPrompt: systemPrompt)
//        
//        // Create request object that process patch builder
//        let processPatchBuilderRequest = OpenAIFunctionRequest(
//            id: self.id,
//            functionType: .processPatchData,
//            requestType: Self.type,
//            messages: patchBuilderToolMessages)
//        
//        let processPatchBuilderMsg = try await processPatchBuilderRequest
//            .requestMessageForFn(document: document,
//                                 aiManager: aiManager)
//        
//        let patchBuildResult = try processPatchBuilderMsg
//            .decodeMessage(document: document,
//                           aiManager: aiManager,
//                           resultType: CurrentAIGraphData.PatchData.self)
//
//        logToServerIfRelease("Successful patch builder result: \(try patchBuildResult.encodeToPrintableString())")
//        let graphData = AIGraphData_V0.GraphData(layer_data_list: layerDataList,
//                                                 patch_data: patchBuildResult)
//        return (graphData, allDiscoveredErrors)
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
