//
//  AICodeGenRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import Foundation

enum AICodeGenRequestBody_V0 {
    // https://platform.openai.com/docs/api-reference/making-requests
    struct AICodeGenRequestBody : Encodable {
        static let markdownLocation = "AICodeGenSystemPrompt_V0"
        
        let model: String = "o4-mini-2025-04-16"
        let n: Int = 1
        let temperature: Double = 1.0
        let messages: [OpenAIMessage]
        let stream: Bool = false
        
//        init(prompt: String) throws {
        init(prompt: String,
             base64ImageDescription: String?) throws {
            log("AICodeGenRequestBody: init: base64ImageDescription.isDefined: \(base64ImageDescription.isDefined)")
            
            guard let markdownUrl = Bundle.main.url(forResource: Self.markdownLocation,
                                                    withExtension: "md") else {
                throw StitchAIStreamingError.markdownNotFound
            }
            
//            let systemPrompt = try String(contentsOf: markdownUrl,
//                                          encoding: .utf8)
            
            var promptWithImage: [[String: Any]] = [
                ["type": "input_text", "text": "DESCRIBE THIS IMAGE"]
            ]
            
            if let base64ImageDescription = base64ImageDescription {
                promptWithImage.append([
                    "type": "input_image",
                    "image_url": "data:image/jpeg;base64,\(base64ImageDescription)"
                ])
                log("AICodeGenRequestBody: init: added base64 image")
            }
            
            self.messages = [
                .init(role: .system,
                      content: "Describe this screenshot of my design"),
                .init(role: .user,
                      content: prompt)
            ]
        }
    }
    
    struct AICodeGenRequestInputs: Encodable {
        let user_prompt: String
        let layer_list: SidebarLayerList
    }
}
