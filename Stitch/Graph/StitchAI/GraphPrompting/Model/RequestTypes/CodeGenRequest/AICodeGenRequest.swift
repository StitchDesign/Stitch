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
    let currentGraphData: CurrentAIGraphData.GraphData
    
    @MainActor
    init(prompt: String,
         currentGraphData: CurrentAIGraphData.GraphData) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.currentGraphData = currentGraphData
    }
    
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager,
                    systemPrompt: String) async throws -> String {
        // Create tool messages for code creation
        let editRequestMessages = try OpenAIFunctionRequest
            .createInitialFnMessages(functionType: .codeBuilder,
                                     requestType: Self.type,
                                     inputsArguments: self.currentGraphData,
                                     systemPrompt: systemPrompt)
        
        // Create tool messages for create edit function, processing the code creation step
        let editCodeFnRequest = OpenAIFunctionRequest(
            id: self.id,
            functionType: .codeEditor,
            requestType: Self.type,
            messages: editRequestMessages + [
                // Add user prompt
                .init(role: .user,
                      content: self.userPrompt)
            ])
        
        // Creates code and then creates tool call for edit request
        let editRequestToolCalls = try await editCodeFnRequest
            .requestMessagesForNextFn(returnedFnType: .codeEditor,
                                      requestType: Self.type,
                                      document: document,
                                      aiManager: aiManager)

        let processCodeFnRequest = OpenAIFunctionRequest(
            id: self.id,
            functionType: .processCode,
            requestType: Self.type,
            messages: [
                .init(role: .system,
                      content: systemPrompt)
            ] +
            // Can safely ignore first code creation tools since edit request contains most recent code
            editRequestToolCalls
        )
        
        let processCodeToolCall = try await processCodeFnRequest
            .requestMessageForFn(document: document,
                                 aiManager: aiManager)
        
        let decodedSwiftUICode = try OpenAIFunctionRequest
            .decodeMessage(from: processCodeToolCall,
                           document: document,
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
        let imageRequestInputs = AICodeGenFromImageInputs(
            user_prompt: self.userPrompt,
            image_data: .init(base64Image: self.base64Image)
        )
        
        let toolMessages = try OpenAIFunctionRequest.createInitialFnMessages(
            functionType: .codeBuilderFromImage,
            requestType: Self.type,
            inputsArguments: imageRequestInputs,
            systemPrompt: systemPrompt)
        
        let createCodeRequest = OpenAIFunctionRequest(
            id: self.id,
            functionType: .processCode,
            requestType: Self.type,
            messages: toolMessages)
        
        let msgFromCodeCreation = try await createCodeRequest
            .requestMessageForFn(document: document, aiManager: aiManager)

        let decodedSwiftUICode = try OpenAIFunctionRequest
            .decodeMessage(from: msgFromCodeCreation,
                           document: document,
                           aiManager: aiManager,
                           resultType: StitchAIRequestBuilder_V0.SourceCodeResponse.self)

        return decodedSwiftUICode.source_code
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
        
        logToServerIfRelease("SUCCESS: swiftUICode: \(swiftUICode)")
        
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
        
        let patchBuilderInputs = AIPatchBuilderFunctionInputs(
            swiftui_source_code: swiftUICode,
            layer_data_list: layerDataList)
        
        // Create new tool messages for patch builder
        let patchBuilderToolMessages = try OpenAIFunctionRequest
            .createInitialFnMessages(functionType: .patchBuilder,
                                     requestType: Self.type,
                                     inputsArguments: patchBuilderInputs,
                                     systemPrompt: systemPrompt)
        
        // Create request object that process patch builder
        let processPatchBuilderRequest = OpenAIFunctionRequest(
            id: self.id,
            functionType: .processPatchData,
            requestType: Self.type,
            messages: patchBuilderToolMessages)
        
        let processPatchBuilderMsg = try await processPatchBuilderRequest
            .requestMessageForFn(document: document,
                                 aiManager: aiManager)
        
        let patchBuildResult = try OpenAIFunctionRequest
            .decodeMessage(from: processPatchBuilderMsg,
                           document: document,
                           aiManager: aiManager,
                           resultType: CurrentAIGraphData.PatchData.self)

        logToServerIfRelease("Successful patch builder result: \(try patchBuildResult.encodeToPrintableString())")
        let graphData = AIGraphData_V0.GraphData(layer_data_list: layerDataList,
                                                 patch_data: patchBuildResult)
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
