//
//  AIPatchServiceRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import Foundation

enum AIPatchServiceRequestBody_V0 {
    // https://platform.openai.com/docs/api-reference/making-requests
    struct AIPatchServiceRequestBody : Encodable {
        static let markdownLocation = "AIPatchServiceSystemPrompt_V0"
        
        let model: String = "gpt-4o-2024-08-06"
        let n: Int = 1
        let temperature: Double = 0.0
        let messages: [OpenAIMessage]
        let stream: Bool = false
        
        init(prompt: String,
             layerList: SidebarLayerList) throws {
            guard let markdownUrl = Bundle.main.url(forResource: Self.markdownLocation,
                                                    withExtension: "md") else {
                throw StitchAIStreamingError.markdownNotFound
            }
            
            let systemPrompt = try String(contentsOf: markdownUrl,
                                          encoding: .utf8)
            
            let inputs = AIPatchServiceRequestBody_V0
                .AIPatchServiceRequestInputs(user_prompt: prompt,
                                             layer_list: layerList)
            let userInputsString = try inputs.encodeToPrintableString()
            
            self.messages = [
                .init(role: .system,
                      content: systemPrompt),
                .init(role: .user,
                      content: userInputsString)
            ]
        }
    }
    
    struct AIPatchServiceRequestInputs: Encodable {
        let user_prompt: String
        let layer_list: SidebarLayerList
    }
}
