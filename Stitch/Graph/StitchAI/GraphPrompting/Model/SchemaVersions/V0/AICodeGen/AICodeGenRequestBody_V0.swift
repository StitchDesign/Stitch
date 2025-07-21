//
//  AICodeGenRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import Foundation

enum AICodeGenRequestBody_V0 {

    //    static let systemMarkdownLocation = "AIGraphBuilderSystemPrompt_V0"
    
    //    static func getSystemPrompt() throws -> String {
    //        guard let systemMarkdownUrl = Bundle.main.url(forResource: Self.systemMarkdownLocation,
    //                                                      withExtension: "md") else {
    //            throw StitchAIStreamingError.markdownNotFound
    //        }
    //
    //        let systemPrompt = try String(contentsOf: systemMarkdownUrl,
    //                                      encoding: .utf8)
    //        return systemPrompt
    //    }
    
    struct AICodeGenRequestBody: StitchAIRequestableFunctionBody {
        let model: String = "o4-mini-2025-04-16"
        let n: Int = 1
        let temperature: Double = 1.0
        let messages: [OpenAIMessage]
        let tools: [OpenAIFunction]
        let tool_choice: OpenAIFunction
        let stream: Bool = false
    }
}

extension AICodeGenRequestBody_V0.AICodeGenRequestBody {
    
    // TODO: "throws" = "can fail at runtime"; but actually the app should not  run if we can't create a system prompt
    init(currentGraphData: CurrentAIGraphData.GraphData,
         systemPrompt: String) throws {
        self.tools = StitchAIRequestBuilder_V0.StitchAIRequestType.userPrompt.allOpenAIFunctions
        self.tool_choice = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction.codeBuilder.function
        
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
         systemPrompt: String) throws {
        self.tools = StitchAIRequestBuilder_V0.StitchAIRequestType.imagePrompt.allOpenAIFunctions
        self.tool_choice = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction.codeBuilderFromImage.function
        
        let codeGenAssistantPrompt = try StitchAIManager.aiCodeGenSystemPromptGenerator(requestType: .imagePrompt)
        
        self.messages = [
            .init(role: .system,
                  content: systemPrompt),
            .init(role: .system,
                  content: codeGenAssistantPrompt),
            .init(role: .user,
                  content: userPrompt)
        ]
    }
    
    
    // For images
    init(userPrompt: String,
         systemPrompt: String,
         base64ImageDescription: String) {
        
        self.tools = StitchAIRequestBuilder_V0.StitchAIRequestType.imagePrompt.allOpenAIFunctions
        self.tool_choice = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction.codeBuilderFromImage.function
        
        let codeGenAssistantPrompt = try! StitchAIManager.aiCodeGenSystemPromptGenerator(requestType: .userPrompt)
        
        var content: [OpenAIMessageContent] = [
            .text(userPrompt)
        ]
        
        let imageUrl = "data:image/jpeg;base64,\(base64ImageDescription)"
        content.append(.image(url: imageUrl, detail: "high"))
        
        let encodedContent = try! content.encodeToPrintableString()
        // log("encodedContent: \(encodedContent)")

        self.messages = [
            OpenAIMessage(role: .system,
                          content: systemPrompt),
            OpenAIMessage(role: .system,
                          content: codeGenAssistantPrompt),
            OpenAIMessage(role: .user,
                          content: encodedContent)
        ]
    }

}

enum OpenAIMessageContent: Encodable {
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
