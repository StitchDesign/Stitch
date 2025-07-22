//
//  AICodeGenRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import Foundation

enum AICodeGenRequestBody_V0 {
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
    // Creates function of code gen from graph data
    init(currentGraphData: CurrentAIGraphData.GraphData,
         systemPrompt: String) throws {
        self.tools = StitchAIRequestBuilder_V0.StitchAIRequestType.userPrompt.allOpenAIFunctions
        self.tool_choice = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction.codeBuilder.function
        
        let inputsString = try currentGraphData.encodeToPrintableString()
        
        print("AICodeGenRequestBody: incoming graph data:\n\((try? currentGraphData.encodeToPrintableString()) ?? "")")
        
        self.messages = [
            .init(role: .system,
                  content: systemPrompt),
            .init(role: .user,
                  content: inputsString)
        ]
    }
       
    // Creates function of code gen from graph data from image gen
    init(userPrompt: String,
         systemPrompt: String,
         base64ImageDescription: String) throws {
        
        // TODO: REMOVE THIS!!
        
        self.tools = StitchAIRequestBuilder_V0.StitchAIRequestType.imagePrompt.allOpenAIFunctions
        self.tool_choice = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction.codeBuilderFromImage.function
        
        let base64Message = OpenAIUserImageContent(base64Image: base64ImageDescription)
        let base64MessageString = try base64Message.encodeToPrintableString()

        self.messages = [
            OpenAIMessage(role: .system,
                          content: systemPrompt),
            OpenAIMessage(role:. user,
                          content: userPrompt),
            OpenAIMessage(role: .user,
                          content: base64MessageString)
        ]
    }
    
    // Creates code
    init(messages: [OpenAIMessage],
         type: StitchAIRequestBuilder_V0.StitchAIRequestType) {
        self.messages = messages
        self.tools = type.allOpenAIFunctions
        self.tool_choice = .init(type: .none)
    }
}

struct AICodeGenFromImageInputs: Codable {
    let user_prompt: String
    let image_data: OpenAIUserImageContent
}

struct OpenAIUserImageContent: Codable {
    var type = "image_url"
    var image_url: OpenAIImageUrl
    var detail = "high"
    
    init(base64Image: String) {
        self.image_url = .init(base64Image: base64Image)
    }
}

struct OpenAIImageUrl {
    let base64Image: String
}

extension OpenAIImageUrl: Codable {
    enum CodingKeys: String, CodingKey {
        case url
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let urlString = "data:image/jpeg;base64,\(base64Image)"
        try container.encode(urlString, forKey: .url)
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedString = try container.decode(String.self, forKey: .url)
        self.base64Image = String(decodedString.dropFirst("data:image/jpeg;base64,".count))
    }
}
