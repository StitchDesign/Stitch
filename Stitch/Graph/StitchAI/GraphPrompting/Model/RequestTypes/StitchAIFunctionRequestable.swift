//
//  StitchAIFunctionRequestable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/20/25.
//

import SwiftUI

protocol StitchAIFunctionRequestable: StitchAIRequestable where
Self.InitialDecodedResult == [OpenAIToolCallResponse], Self.InitialDecodedResult == Self.FinalDecodedResult, Self.Body == OpenAIRequestBody {
    var type: StitchAIRequestBuilder_V0.StitchAIRequestType { get }
}

extension StitchAIFunctionRequestable {
    var functionName: String { self.body.functionName }
}

extension OpenAIMessage {
    func decodeMessage<ResultType>(document: StitchDocumentViewModel,
                                   aiManager: StitchAIManager,
                                   resultType: ResultType.Type) throws -> ResultType where ResultType: Decodable {
        guard let tool = self.tool_calls?.first?.function,
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

protocol StitchAICodeCreator {
    var id: UUID { get }
    
    static var type: StitchAIRequestBuilder_V0.StitchAIRequestType { get }
    
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager,
                    systemPrompt: String) async throws -> String
}

extension StitchAIFunctionRequestable {    
    /// Starts new chain of function calling. Call this when no existing funciton messages can be used.
    static func createInitialFnMessages(functionType: StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction,
                                        requestType: StitchAIRequestBuilder_V0.StitchAIRequestType,
                                        inputsArguments: any Encodable,
                                        systemPrompt: String) throws -> [OpenAIMessage] {
        let systemPromptMsg = OpenAIMessage(
            role: .system,
            content: systemPrompt
        )
        
        let supplementarySystemPrompt = OpenAIMessage(
            role: .system,
            content: try functionType.getAssistantPrompt(for: requestType)
        )

        // MARK: OpenAI requires a specific ID format that if unmatched will break requests
        let toolId = OpenAISchema.sampleId
        
        let msgFromSourceCodeRequest = OpenAIMessage(
            role: .assistant,
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
            supplementarySystemPrompt,
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
