//
//  AICodeGenRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

protocol StitchAIFunctionRequestable: StitchAIRequestable where
Self.InitialDecodedResult == [OpenAIToolCallResponse], Self.InitialDecodedResult == Self.FinalDecodedResult, Self.Body: StitchAIRequestableFunctionBody { }

extension StitchAIFunctionRequestable {
    var functionName: String { self.body.functionName }
}

extension StitchAIFunctionRequestable {
    func decodeMessage<ResultType>(from message: OpenAIMessage,
                                   document: StitchDocumentViewModel,
                                   aiManager: StitchAIManager,
                                   resultType: ResultType.Type) throws -> ResultType where Self.InitialDecodedResult == [OpenAIToolCallResponse], Self.InitialDecodedResult == Self.FinalDecodedResult, ResultType: Decodable, Self.Body: StitchAIRequestableFunctionBody {
        let toolsResponse = try Self.parseOpenAIResponse(message: message)
        
        guard let tool = toolsResponse.first?.function,
              tool.name == self.body.functionName,
              let swiftUISourceCodeData = tool.arguments.data(using: .utf8) else {
            throw StitchAIManagerError.functionDecodingFailed
        }
        
        let decodedResult = try JSONDecoder().decode(
            resultType.self,
            from: swiftUISourceCodeData
        )
        
        return decodedResult
    }
}

// TODO: move
// TODO: actually move
struct AICodeEditRequest: StitchAIFunctionRequestable {
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AICodeEditBody_V0.AICodeEditRequestBody
    static let willStream: Bool = false
    
    init(id: UUID,
         prompt: String,
         toolMessages: [OpenAIMessage],
         systemPrompt: String,
         config: OpenAIRequestConfig = .default) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = id
        
        self.userPrompt = prompt
        self.config = config
        
        // Construct http payload
        self.body = try AICodeEditBody_V0.AICodeEditRequestBody(
            userPrompt: prompt,
            toolMessages: toolMessages,
            systemPrompt: systemPrompt)
    }
    
    @MainActor
    func willRequest(document: StitchDocumentViewModel,
                     canShareData: Bool,
                     requestTask: Self.RequestTask) {
        // Nothing to do
    }
    
    static func validateResponse(decodedResult: [OpenAIToolCallResponse]) throws -> [OpenAIToolCallResponse] {
        decodedResult
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: [OpenAIToolCallResponse],
                                   currentAttempt: Int) {
        fatalErrorIfDebug()
    }
    
    static func buildResponse(from streamingChunks: [[OpenAIToolCallResponse]]) throws -> [OpenAIToolCallResponse] {
        // Unsupported
        fatalError()
    }
}

protocol StitchAIGraphBuilderRequestable: StitchAIFunctionRequestable {
    // TODO: Group the entire code gen/edit requests under one handler
    
    static var type: StitchAIRequestBuilder_V0.StitchAIRequestType { get }
        
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager,
                    systemPrompt: String) async throws -> (String, OpenAIMessage)
}

extension StitchAIGraphBuilderRequestable {
    @MainActor
    static func systemPrompt(graph: GraphState) throws -> String {
        try StitchAIManager
            .stitchAIGraphBuilderSystem(graph: graph,
                                        requestType: Self.type)
    }
}

extension StitchAIGraphBuilderRequestable {
    @MainActor
    func willRequest(document: StitchDocumentViewModel,
                     canShareData: Bool,
                     requestTask: Self.RequestTask) {
        // Nothing to do
    }
    
    static func validateResponse(decodedResult: [OpenAIToolCallResponse]) throws -> [OpenAIToolCallResponse] {
        decodedResult
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: [OpenAIToolCallResponse],
                                   currentAttempt: Int) {
        fatalErrorIfDebug()
    }
    
    static func buildResponse(from streamingChunks: [[OpenAIToolCallResponse]]) throws -> [OpenAIToolCallResponse] {
        // Unsupported
        fatalError()
    }
}

struct AICodeGenFromGraphRequest: StitchAIGraphBuilderRequestable {
    static let type = StitchAIRequestBuilder_V0.StitchAIRequestType.userPrompt
    
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AICodeGenFromGraphRequestBody_V0.AICodeGenFromGraphRequestBody
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
        self.body = try AICodeGenFromGraphRequestBody_V0
            .AICodeGenFromGraphRequestBody(currentGraphData: currentGraphData,
                                           systemPrompt: systemPrompt)
    }
    
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager,
                    systemPrompt: String) async throws -> (String, OpenAIMessage) {
        let msgFromSourceCodeRequest = try await self
            .requestForMessage(document: document,
                               aiManager: aiManager)
        
        let decodedSwiftUICode = try self
            .decodeMessage(from: msgFromSourceCodeRequest,
                           document: document,
                           aiManager: aiManager,
                           resultType: StitchAIRequestBuilder_V0.SourceCodeResponse.self)
        logToServerIfRelease("Initial code:\n\(decodedSwiftUICode.source_code)")
        
        let newCodeToolMessage = try msgFromSourceCodeRequest.createNewToolMessage()
        
        let editRequest = try AICodeEditRequest(id: self.id,
                                                prompt: self.userPrompt,
                                                toolMessages: [msgFromSourceCodeRequest, newCodeToolMessage],
                                                systemPrompt: systemPrompt)
        
        let msgFromEditCodeRequest = try await editRequest
            .requestForMessage(
                document: document,
                aiManager: aiManager)
        
        let decodedSwiftUIEditedCode = try editRequest
            .decodeMessage(from: msgFromEditCodeRequest,
                           document: document,
                           aiManager: aiManager,
                           resultType: StitchAIRequestBuilder_V0.SourceCodeResponse.self)
        let swiftUIEditedCode = decodedSwiftUIEditedCode.source_code
        
        logToServerIfRelease("Edited code:\n\(swiftUIEditedCode)")
        return (swiftUIEditedCode, msgFromEditCodeRequest)
    }
}



// TODO: MOVE


struct AICodeGenFromImageRequest: StitchAIGraphBuilderRequestable {
    static let type = StitchAIRequestBuilder_V0.StitchAIRequestType.imagePrompt
    
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AICodeGenFromImageRequestBody_V0.AICodeGenFromImageRequestBody
    static let willStream: Bool = false
    
    init(prompt: String,
         currentGraphData: CurrentAIGraphData.GraphData,
         systemPrompt: String,
         config: OpenAIRequestConfig = .default) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.config = config
        
        // Construct http payload
        self.body = try AICodeGenFromImageRequestBody_V0
            .AICodeGenFromImageRequestBody(currentGraphData: currentGraphData,
                                           systemPrompt: systemPrompt)
    }
    
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager,
                    systemPrompt: String) async throws -> (String, OpenAIMessage) {
        let msgFromSourceCodeRequest = try await self
            .requestForMessage(document: document,
                               aiManager: aiManager)
        
        let decodedSwiftUICode = try self
            .decodeMessage(from: msgFromSourceCodeRequest,
                           document: document,
                           aiManager: aiManager,
                           resultType: StitchAIRequestBuilder_V0.SourceCodeResponse.self)
        logToServerIfRelease("Initial code:\n\(decodedSwiftUICode.source_code)")
        
        let newCodeToolMessage = try msgFromSourceCodeRequest.createNewToolMessage()
        
        return (decodedSwiftUICode.source_code, msgFromSourceCodeRequest)
    }
}

extension StitchAIGraphBuilderRequestable {
    @MainActor
    func getRequestTask(userPrompt: String,
                        document: StitchDocumentViewModel) throws -> Task<Result<AIGraphData_V0.GraphData, any Error>, Never> {
        let currentGraphData = try CurrentAIGraphData.GraphData(from: document.visibleGraph.createSchema())
        let systemPrompt = try StitchAIManager.stitchAIGraphBuilderSystem(graph: document.visibleGraph,
                                                                          requestType: Self.type)
        let request = self
//        try AICodeGenRequest(
//            prompt: userPrompt,
//            currentGraphData: currentGraphData)
        
        return Task(priority: .high) { [weak document] in
            guard let document = document,
                  let aiManager = document.aiManager else {
                log("AICodeGenRequest: getRequestTask: no document or ai manager", .logToServer)
                
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
                        try graphData.applyAIGraph(to: document)
                        
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
        logToServerIfRelease("userPrompt: \(userPrompt)")

        let (swiftUICode, msgFromCode) = try await self
            .createCode(document: document,
                        aiManager: aiManager,
                        systemPrompt: systemPrompt)
        
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
         var newEditToolMessage = try msgFromCode.createNewToolMessage()
         let patchBuilderInputs = AIPatchBuilderRequestBody_V0.AIPatchBuilderFunctionInputs(
             swiftui_source_code: swiftUICode,
             layer_data: layerDataList
         )
         newEditToolMessage.content = try patchBuilderInputs.encodeToPrintableString()
        
        let patchBuilderRequest = try AIPatchBuilderRequest(
            id: self.id,
            userPrompt: userPrompt,
            layerDataList: layerDataList,
            toolMessages: [msgFromCode, newEditToolMessage],
            requestType: Self.type,
            systemPrompt: systemPrompt)
        
        let patchBuildMessage = try await patchBuilderRequest
            .requestForMessage(document: document,
                               aiManager: aiManager)
        
        let patchBuildResult = try patchBuilderRequest
            .decodeMessage(from: patchBuildMessage,
                           document: document,
                           aiManager: aiManager,
                           resultType: CurrentAIGraphData.PatchData.self)
            
        logToServerIfRelease("Successful patch builder result: \(try patchBuildResult.encodeToPrintableString())")
        let graphData = AIGraphData_V0.GraphData(layer_data_list: layerDataList,
                                                 patch_data: patchBuildResult)
        return (graphData, allDiscoveredErrors)
    }
    
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
