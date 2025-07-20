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

// Claude-based initial code generation request (non-function based)
struct ClaudeCodeGenRequest: StitchAIRequestable {
    let id: UUID
    let userPrompt: String
    let config: OpenAIRequestConfig
    let body: AICodeGenRequestBody_V0.ClaudeCodeGenRequestBody
    static let willStream: Bool = false
    
    typealias InitialDecodedResult = String
    typealias FinalDecodedResult = String
    typealias TokenDecodedResult = String
    
    init(currentGraphData: CurrentAIGraphData.GraphData, 
         config: OpenAIRequestConfig = .default) throws {
        self.id = .init()
        self.userPrompt = ""  
        self.config = config
        self.body = try AICodeGenRequestBody_V0.ClaudeCodeGenRequestBody(currentGraphData: currentGraphData)
    }
    
    @MainActor
    func willRequest(document: StitchDocumentViewModel,
                     canShareData: Bool,
                     requestTask: Self.RequestTask) {
        // Nothing to do
    }
    
    static func validateResponse(decodedResult: String) throws -> String {
        decodedResult
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: String,
                                   currentAttempt: Int) {
        fatalErrorIfDebug()
    }
    
    static func buildResponse(from streamingChunks: [String]) throws -> String {
        // Unsupported
        fatalError()
    }
    
    func getPayloadData() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self.body)
    }
}

// TODO: move
struct AICodeEditRequest: StitchAIFunctionRequestable {
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AICodeEditBody_V0.AICodeEditRequestBody
    static let willStream: Bool = false
    
    init(id: UUID,
         prompt: String,
         toolMessages: [OpenAIMessage],
         config: OpenAIRequestConfig = .default) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = id
        
        self.userPrompt = prompt
        self.config = config
        
        // Construct http payload
        self.body = try AICodeEditBody_V0.AICodeEditRequestBody(
            userPrompt: prompt,
            toolMessages: toolMessages)
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

struct AICodeGenRequest: StitchAIFunctionRequestable {
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AICodeGenRequestBody
    static let willStream: Bool = false
    
    @MainActor
    init(prompt: String,
         currentGraphData: CurrentAIGraphData.GraphData,
         config: OpenAIRequestConfig = .default) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.config = config
        
        // Construct http payload
        self.body = try AICodeGenRequestBody(currentGraphData: currentGraphData)
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

extension AICodeGenRequest {
    @MainActor
    static func getRequestTask(userPrompt: String,
                               document: StitchDocumentViewModel) throws -> Task<Result<AIGraphData_V0.GraphData, any Error>, Never> {
        let currentGraphData = try CurrentAIGraphData.GraphData(from: document.visibleGraph.createSchema())
        
        let request = try AICodeGenRequest(
            prompt: userPrompt,
            currentGraphData: currentGraphData)
        
        return Task(priority: .high) { [weak document] in
            guard let document = document,
                  let aiManager = document.aiManager else {
                log("AICodeGenRequest: getRequestTask: no document or ai manager", .logToServer)
                
                if let document: StitchDocumentViewModel = document {
                    return .failure(self.displayError(failure: StitchAIManagerError.secretsNotFound,
                                                      document: document))
                } else {
                    return .failure(StitchAIManagerError.secretsNotFound)
                }
            }
            
            do {
                let (graphData, allDiscoveredErrors) = try await Self.processRequest(userPrompt: userPrompt,
                                                              request: request,
                                                              document: document,
                                                              aiManager: aiManager)
                
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
    
    private static func processRequest(userPrompt: String,
                                       request: AICodeGenRequest,
                                       document: StitchDocumentViewModel,
                                       aiManager: StitchAIManager) async throws -> (AIGraphData_V0.GraphData, [SwiftUISyntaxError]) {
        logToServerIfRelease("userPrompt: \(userPrompt)")

        // Use Claude for the initial SwiftUI code generation
        let currentGraphData = try await CurrentAIGraphData.GraphData(from: document.visibleGraph.createSchema())
        let claudeRequest = try ClaudeCodeGenRequest(currentGraphData: currentGraphData)
        
        let initialSwiftUICode = try await claudeRequest.request(document: document, aiManager: aiManager)
        logToServerIfRelease("Initial code from Claude:\n\(initialSwiftUICode)")
        
        // Use the SwiftUI code directly from Claude (it's already source code, not structured data)
        let swiftUISourceCode = initialSwiftUICode
        logToServerIfRelease("Initial SwiftUI code:\n\(swiftUISourceCode)")
        
        // Create a mock structured response for compatibility with existing flow
        let decodedSwiftUICode = StitchAIRequestBuilder_V0.SourceCodeResponse(source_code: swiftUISourceCode)
        
        // Create a mock message for the edit request flow
        let mockToolCall = OpenAIToolCallResponse(
            id: "mock_tool_call", 
            type: "function", 
            function: OpenAIFunctionResponse(
                name: StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunctions.codeBuilder.function.function.name,
                arguments: try decodedSwiftUICode.encodeToPrintableString()
            )
        )
        let msgFromSourceCodeRequest = OpenAIMessage(
            role: .assistant, 
            content: nil, 
            tool_calls: [mockToolCall], 
            tool_call_id: nil, 
            name: nil, 
            refusal: nil, 
            annotations: nil
        )
        
        let newCodeToolMessage = try msgFromSourceCodeRequest.createNewToolMessage()
        
        let editRequest = try AICodeEditRequest(id: request.id,
                                                prompt: request.userPrompt,
                                                toolMessages: [msgFromSourceCodeRequest, newCodeToolMessage])
        
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
        
        guard let parsedVarBody = VarBodyParser.extract(from: swiftUIEditedCode) else {
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
         var newEditToolMessage = try msgFromEditCodeRequest.createNewToolMessage()
         let patchBuilderInputs = AIPatchBuilderRequestBody_V0.AIPatchBuilderFunctionInputs(
             swiftui_source_code: swiftUIEditedCode,
             layer_data: layerDataList
         )
         newEditToolMessage.content = try patchBuilderInputs.encodeToPrintableString()
        
        let patchBuilderRequest = try AIPatchBuilderRequest(
            id: request.id,
            prompt: userPrompt,
            layerDataList: layerDataList,
            toolMessages: [msgFromEditCodeRequest, newEditToolMessage])
        
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
