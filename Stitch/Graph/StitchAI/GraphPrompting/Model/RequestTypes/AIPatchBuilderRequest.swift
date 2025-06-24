//
//  AIPatchBuilderRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

struct AIPatchBuilderRequest: StitchAIRequestable {
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AIPatchBuilderRequestBody
    static let willStream: Bool = false
    
    @MainActor
    init(prompt: String,
         jsSourceCode: String,
         layerList: SidebarLayerList,
         config: OpenAIRequestConfig = .default) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.config = config
        
        // Construct http payload
        self.body = try AIPatchBuilderRequestBody(userPrompt: prompt,
                                                  jsSourceCode: jsSourceCode,
                                                  layerList: layerList)
    }
    
    @MainActor
    func willRequest(document: StitchDocumentViewModel,
                     canShareData: Bool,
                     requestTask: Self.RequestTask) {
        // Nothing to do
    }
    
    static func validateResponse(decodedResult: CurrentAIPatchBuilderResponseFormat.GraphData) throws -> CurrentAIPatchBuilderResponseFormat.GraphData {
        decodedResult
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: CurrentAIPatchBuilderResponseFormat.GraphData,
                                   currentAttempt: Int) {
        fatalErrorIfDebug()
    }
    
    static func buildResponse(from streamingChunks: [CurrentAIPatchBuilderResponseFormat.GraphData]) throws -> CurrentAIPatchBuilderResponseFormat.GraphData {
        // Unsupported
        fatalError()
    }
}
