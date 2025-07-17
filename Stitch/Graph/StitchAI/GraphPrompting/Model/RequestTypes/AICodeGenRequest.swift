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
struct AICodeEditRequest: StitchAIFunctionRequestable {
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AICodeEditBody_V0.AICodeGenRequestBody
    static let willStream: Bool = false
    
    init(id: UUID,
         prompt: String,
         swiftUICode: String,
         prevMessages: [OpenAIMessage],
         config: OpenAIRequestConfig = .default) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = id
        
        self.userPrompt = prompt
        self.config = config
        
        // Construct http payload
        self.body = try AICodeEditBody_V0.AICodeGenRequestBody(
            userPrompt: prompt,
            swiftUICode: swiftUICode,
            prevMessages: prevMessages)
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
        let msgFromSourceCodeRequest = try await request
            .requestForMessage(document: document,
                               aiManager: aiManager)
        
        let decodedSwiftUISourceCode = try request
            .decodeMessage(from: msgFromSourceCodeRequest,
                           document: document,
                           aiManager: aiManager,
                           resultType: StitchAIRequestBuilder_V0.SourceCodeResponse.self)
        
        let originSwiftUISourceCode = decodedSwiftUISourceCode.source_code
            
        logToServerIfRelease("SUCCESS userPrompt: \(userPrompt)")
        logToServerIfRelease("SUCCESS Code Gen:\n\(originSwiftUISourceCode)")
        
        let editRequest = try AICodeEditRequest(id: request.id,
                                                prompt: request.userPrompt,
                                                swiftUICode: originSwiftUISourceCode,
                                                prevMessages: request.body.messages + [msgFromSourceCodeRequest])
        
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
        
        guard let parsedVarBody = VarBodyParser.extract(from: swiftUIEditedCode) else {
            logToServerIfRelease("SwiftUISyntaxError.couldNotParseVarBody.localizedDescription: \(SwiftUISyntaxError.couldNotParseVarBody.localizedDescription)")
            throw SwiftUISyntaxError.couldNotParseVarBody
        }
        
        logToServerIfRelease("SUCCESS parsedVarBody:\n\(parsedVarBody)")
        
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
        
        let patchBuilderRequest = try await AIPatchBuilderRequest(
            prompt: userPrompt,
            swiftUISourceCode: swiftUIEditedCode,
            layerDataList: layerDataList)
        
        let patchBuildResult = try await patchBuilderRequest
            .request(document: document,
                     aiManager: aiManager)
            
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
