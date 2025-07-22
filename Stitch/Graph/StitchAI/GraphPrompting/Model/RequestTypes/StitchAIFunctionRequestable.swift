//
//  StitchAIFunctionRequestable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/20/25.
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

protocol StitchAIGraphBuilderRequestable: StitchAIFunctionRequestable {
    // TODO: Group the entire code gen/edit requests under one handler
    
    static var type: StitchAIRequestBuilder_V0.StitchAIRequestType { get }
        
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager,
                    systemPrompt: String) async throws -> (String, OpenAIMessage)
    
    static func createAssistantPrompt() throws -> OpenAIMessage
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
