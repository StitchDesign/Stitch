//
//  StitchAIFunctionRequestable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/20/25.
//

import SwiftUI

protocol StitchAIFunctionRequestable: StitchAIRequestable where
Self.InitialDecodedResult == [OpenAIToolCallResponse], Self.InitialDecodedResult == Self.FinalDecodedResult, Self.Body: StitchAIRequestableFunctionBody {
    var type: StitchAIRequestBuilder_V0.StitchAIRequestType { get }
}

extension StitchAIFunctionRequestable {
    var functionName: String { self.body.functionName }
}

extension StitchAIFunctionRequestable {
    func decodeMessage<ResultType>(from message: OpenAIMessage,
                                   document: StitchDocumentViewModel,
                                   aiManager: StitchAIManager,
                                   resultType: ResultType.Type) throws -> ResultType where Self.InitialDecodedResult == [OpenAIToolCallResponse], Self.InitialDecodedResult == Self.FinalDecodedResult, ResultType: Decodable, Self.Body: StitchAIRequestableFunctionBody {
//        let toolsResponse = try Self.parseOpenAIResponse(message: message)
        
        guard let tool = message.tool_calls?.first?.function,
//              tool.name == self.body.functionName,
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

// TODO: can we remove this??

protocol StitchAIGraphBuilderRequestable: StitchAIFunctionRequestable {
    
//    func createAssistantPrompt() throws -> String
}

protocol StitchAICodeCreator: StitchAIGraphBuilderRequestable {
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager,
                    systemPrompt: String) async throws -> String
}

extension StitchAIGraphBuilderRequestable {
//    func createToolMessages(functionType: StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction,
//                            requestType: StitchAIRequestBuilder_V0.StitchAIRequestType,
//                            inputsArguments: any Encodable) throws -> [OpenAIMessage] {
////        let assistantPrompt = try self.createAssistantPrompt()
//        
//        try Self.createToolMessages(functionType: functionType,
//                                    requestType: requestType,
//                                    inputsArguments: inputsArguments)
//    }
    
    /// Starts new chain of function calling. Call this when no existing funciton messages can be used.
    static func createInitialFnMessages(functionType: StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction,
                                        requestType: StitchAIRequestBuilder_V0.StitchAIRequestType,
                                        inputsArguments: any Encodable,
                                        systemPrompt: String) throws -> [OpenAIMessage] {
        let systemPromptMsg = OpenAIMessage(role: .system,
                                            content: systemPrompt)

        // MARK: OpenAI requires a specific ID format that if unmatched will break requests
        let toolId = OpenAISchema.sampleId
        
        let msgFromSourceCodeRequest = OpenAIMessage(
            role: .assistant,
            content: try functionType.getAssistantPrompt(for: requestType),
            tool_calls: [
                .init(
                    id: toolId,
                    type: "function",
                    function: .init(name: functionType.rawValue,
                                    arguments: try inputsArguments.encodeToString())
                )
            ],
            annotations: []
        )

        let newCodeToolMessage = try msgFromSourceCodeRequest.createNewToolMessage()
        
        return [
            systemPromptMsg,
            msgFromSourceCodeRequest,
            newCodeToolMessage]
    }
}

extension StitchAIFunctionRequestable {
    @MainActor
    func systemPrompt(graph: GraphState) throws -> String {
        try StitchAIManager
            .stitchAIGraphBuilderSystem(graph: graph,
                                        requestType: self.type)
    }
}

extension StitchAIFunctionRequestable {
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
