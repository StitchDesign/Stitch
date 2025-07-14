//
//  AICodeGenRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import Foundation

enum AICodeGenRequestBody_V0 {
    // https://platform.openai.com/docs/api-reference/making-requests
    struct AICodeGenRequestBody: Encodable {
        let model: String = "o4-mini-2025-04-16"
        let n: Int = 1
        let temperature: Double = 1.0
        let messages: [StructuredOpenAIMessage]
        let stream: Bool = false
        
        static let markdownLocation = "AICodeGenSystemPrompt_V0"

        
        init(prompt: String, base64ImageDescription: String?) throws {
            var content: [StructuredOpenAIMessage.Content] = [
                .text(prompt)
            ]
            
            
            guard let markdownUrl = Bundle.main.url(forResource: Self.markdownLocation,
                                                           withExtension: "md") else {
                       throw StitchAIStreamingError.markdownNotFound
                   }
            let systemPrompt = try String(contentsOf: markdownUrl,
                                          encoding: .utf8)

            var systemPromptContent: [StructuredOpenAIMessage.Content] = [
                .text(systemPrompt)
            ]
            

            if let base64 = base64ImageDescription {
                let imageUrl = "data:image/jpeg;base64,\(base64)"
                content.append(.image(url: imageUrl, detail: "high"))
            }

            self.messages = [
                StructuredOpenAIMessage(role: "system", content: systemPromptContent),
                StructuredOpenAIMessage(role: "user", content: content)
            ]
        }
    }

    struct StructuredOpenAIMessage: Encodable {
        let role: String
        let content: [Content]

        enum Content: Encodable {
            case text(String)
            case image(url: String, detail: String)

            enum CodingKeys: String, CodingKey {
                case type
                case text
                case imageURL = "image_url"
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)

                switch self {
                case .text(let text):
                    try container.encode("text", forKey: .type)
                    try container.encode(text, forKey: .text)

                case .image(let url, let detail):
                    try container.encode("image_url", forKey: .type)
                    try container.encode(["url": url, "detail": detail], forKey: .imageURL)
                }
            }
        }
    }
    struct AICodeGenRequestInputs: Encodable {
        let user_prompt: String
        let layer_list: SidebarLayerList
    }
}
