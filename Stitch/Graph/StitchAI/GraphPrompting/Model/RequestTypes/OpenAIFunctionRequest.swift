//
//  OpenAIFunctionRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/23/25.
//

import SwiftUI

struct OpenAIFunctionRequest: StitchAIFunctionRequestable {
    let id: UUID
    let type: StitchAIRequestBuilder_V0.StitchAIRequestType
    let config: OpenAIRequestConfig = .default
    let body: OpenAIRequestBody
    static let willStream: Bool = false
    
    // Object for creating actual code creation request
    init(id: UUID,
         functionType: StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction,
         requestType: StitchAIRequestBuilder_V0.StitchAIRequestType,
         messages: [OpenAIMessage]) {
        self.id = id
        self.type = requestType
        self.body = .init(messages: messages,
                          type: requestType,
                          functionType: functionType)
    }
}
