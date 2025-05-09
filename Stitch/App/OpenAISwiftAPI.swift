//
//  OpenAISwiftAPI.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/25.
//

import SwiftUI
import OpenAI

extension StitchAIManager {
        
    
    @MainActor
    func makeOpenAIStreamingRequest(openAIRequest: OpenAIRequest) async throws {

        // System prompt
        guard let systemMessage = ChatQuery.ChatCompletionMessageParam(
            role: .system,
            content: openAIRequest.systemPrompt) else {
            
            log("could not create systemMessage")
            return
        }
        
        // User-provided prompt: "Add 2 and 3 and then divide by 5"
        guard let userMessage = ChatQuery.ChatCompletionMessageParam(
            role: .user,
            content: openAIRequest.prompt) else {
            log("could not create userMessage")
            return
        }
                
        // TODO:
//        let responseFormat: ChatQuery.ResponseFormat = .derived
        
        let query = ChatQuery(
            messages: [systemMessage, userMessage],
            //                              model: .gpt4)
            model: self.secrets.openAIModel,
            responseFormat: nil
        )
        
//        let _query = ChatQuery(
//            messages: [systemMessage, userMessage],
//            model: self.secrets.openAIModel,
//            n: 1,
////            responseFormat: .derivedJsonSchema(
////                name: StitchAIStructuredOutputsSchema.title,
////                type: <#T##any JSONSchemaConvertible.Type#>),
//            
//            responseFormat: .jsonSchema(
//                ChatQuery.ResponseFormat.StructuredOutputConfigurationOptions
//                    .init(name: StitchAIStructuredOutputsSchema.title,
//                          description: <#T##String?#>,
//                          schema: <#T##AnyJSONSchema?#>,
//                          strict: true)
//                
//            )
//            ,
//            
//            temperature: 0.0
//        )

        
        // As we get each new token, eagerly attempt to decode the stream of token strings
        for try await result in self.openAI.chatsStream(query: query) {
            
            log("makeOpenAIStreamingRequest: success: result: \(result)")
            
            log("makeOpenAIStreamingRequest: success: result.choices: \(result.choices.map(\.delta.content))")
                
            result.choices.forEach { choice in
                if let streamedToken = choice.delta.content {
                    DispatchQueue.main.async {
                        dispatch(OpenAIRawTokenReceived(tokenReceived: streamedToken))
                    }
                }
            }
        } // for try await
        
        
//        // Opens the stream and saves it on the AIManager,
//        // so that we can e.g. cancel it from the node menu's onDisappear.
//        self.currentStream = openAI.chatsStream(query: query) { partialResult in
//            
//            switch partialResult {
//            
//            case .success(let result):
//                log("makeOpenAIStreamingRequest: success: result.choices: \(result.choices.map(\.delta.content))")
//                
//                result.choices.forEach { choice in
//                    if let streamedToken = choice.delta.content {
//                        DispatchQueue.main.async {
//                            dispatch(OpenAIRawTokenReceived(tokenReceived: streamedToken))
//                        }
//                    }
//                }
//            
//            case .failure(let error):
//                log("makeOpenAIStreamingRequest: failure: error \(error.localizedDescription)")
//            }
//            
//        } completion: { error in
//            
//            // TODO: throw an error here?
//            log("makeOpenAIStreamingRequest: completion: streaming error \(String(describing: error?.localizedDescription))")
//            
//            
//        }
        
    } // openAI.chatsStream(query: query) { ...
}
