//
//  AICodeGenRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import Foundation

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
