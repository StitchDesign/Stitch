//
//  AICodeGenRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import Foundation

// TODO: move
protocol StitchAIRequestableFunctionBody: Encodable {
    var tools: [OpenAIFunction] { get }
    var tool_choice: OpenAIFunction { get }
}

extension StitchAIRequestableFunctionBody {
    var functionName: String {
        self.tool_choice.function.name
    }
}

enum AICodeEditBody_V0 {
    // https://platform.openai.com/docs/api-reference/making-requests
    struct AICodeGenRequestBody: StitchAIRequestableFunctionBody {
        static let markdownLocation = "AICodeGenSystemPrompt_V0"
        
        let model: String = "o4-mini-2025-04-16"
        let n: Int = 1
        let temperature: Double = 1.0
        let messages: [OpenAIMessage]
        let tools = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunctions.allFunctions
        let tool_choice = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunctions.codeEditor.function
        let stream: Bool = false
        
        init(userPrompt: String,
             prevMessages: [OpenAIMessage]) throws {
            let systemPrompt = "Modify SwiftUI source code based on the request from a user prompt. Use code returned from the last function caller. Adhere to previously defined rules regarding patch and layer behavior in Stitch."
            
            self.messages = prevMessages + [
                .init(role: .system,
                      content: systemPrompt),
                .init(role: .user,
                      content: userPrompt)
            ]
        }
    }
}

enum AICodeGenRequestBody_V0 {
    // https://platform.openai.com/docs/api-reference/making-requests
    struct AICodeGenRequestBody: StitchAIRequestableFunctionBody {
        static let markdownLocation = "AICodeGenSystemPrompt_V0"
        
        let model: String = "o4-mini-2025-04-16"
        let n: Int = 1
        let temperature: Double = 1.0
        let messages: [OpenAIMessage]
        let tools = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunctions.allFunctions
        let tool_choice = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunctions.codeBuilder.function
        let stream: Bool = false
        
        init(currentGraphData: CurrentAIGraphData.GraphData) throws {
            guard let markdownUrl = Bundle.main.url(forResource: Self.markdownLocation,
                                                    withExtension: "md") else {
                throw StitchAIStreamingError.markdownNotFound
            }
            
            let systemPrompt = try String(contentsOf: markdownUrl,
                                          encoding: .utf8)
            
            let inputsString = try currentGraphData.encodeToPrintableString()
            
            print("AICodeGenRequestBody: incoming graph data:\n\((try? currentGraphData.encodeToPrintableString()) ?? "")")
            
            self.messages = [
                .init(role: .system,
                      content: systemPrompt),
                .init(role: .user,
                      content: inputsString)
            ]
        }
    }
}

final class OpenAIFunctionsHandler {
    // initial messages...
    
    // tool choice...
    
    //
}
