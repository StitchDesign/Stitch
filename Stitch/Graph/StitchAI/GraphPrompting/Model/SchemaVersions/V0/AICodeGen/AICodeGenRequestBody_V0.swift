//
//  AICodeGenRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import Foundation

enum AICodeGenRequestBody_V0 {
    struct AICodeGenRequestBody: Encodable {
        let model: String = "o4-mini-2025-04-16"
        let n: Int = 1
        let temperature: Double = 1.0
        let messages: [OpenAIMessage]
        let stream: Bool = false
    }
}

extension AICodeGenRequestBody_V0.AICodeGenRequestBody {
    
    // TODO: "throws" = "can fail at runtime"; but actually the app should not  run if we can't create a system prompt
    init(currentGraphData: CurrentAIGraphData.GraphData,
         systemPrompt: String) throws {
        let codeGenAssistantPrompt = try StitchAIManager.aiCodeGenSystemPromptGenerator(requestType: .userPrompt)
        
        let inputsString = try currentGraphData.encodeToPrintableString()
        
        print("AICodeGenRequestBody: incoming graph data:\n\((try? currentGraphData.encodeToPrintableString()) ?? "")")
        
        self.messages = [
            .init(role: .system,
                  content: systemPrompt),
            .init(role: .system,
                  content: codeGenAssistantPrompt),
            .init(role: .user,
                  content: inputsString)
        ]
    }
       
    init(userPrompt: String,
         systemPrompt: String,
         base64ImageDescription: String) throws {
        
        let codeGenAssistantPrompt = try StitchAIManager.aiCodeGenSystemPromptGenerator(requestType: .imagePrompt)
        
        let base64Message = OpenAIUserImageContent(base64Image: base64ImageDescription)
        let base64MessageString = try base64Message.encodeToPrintableString()

        self.messages = [
            OpenAIMessage(role: .system,
                          content: systemPrompt),
            OpenAIMessage(role: .system,
                          content: codeGenAssistantPrompt),
            OpenAIMessage(role:. user,
                          content: userPrompt),
            OpenAIMessage(role: .user,
                          content: base64MessageString)
        ]
    }
}

struct OpenAIUserImageContent: Encodable {
    let type = "image_url"
    let image_url: OpenAIImageUrl
    let detail = "high"
    
    init(base64Image: String) {
        self.image_url = .init(base64Image: base64Image)
    }
}

struct OpenAIImageUrl: Encodable {
    let base64Image: String
    
    enum CodingKeys: String, CodingKey {
        case url
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let urlString = "data:image/jpeg;base64,\(base64Image)"
        try container.encode(urlString, forKey: .url)
    }
}
